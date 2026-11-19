#include "SSMatcher.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

/* Native port of the first version's content-aware matcher. No I/O or networking. */
typedef struct { int overlap; double error, texture; int support; } Score;
static int imin(int a, int b) { return a < b ? a : b; }
static int imax(int a, int b) { return a > b ? a : b; }
static int double_cmp(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x > y) - (x < y);
}
static int int_cmp(const void *a, const void *b) { return *(const int *)a - *(const int *)b; }
static int score_cmp(const void *a, const void *b) {
    const Score *x = a, *y = b;
    return (x->error > y->error) - (x->error < y->error);
}
static int dimensions(int w, int h) { return w >= 8 && w <= 128 && h >= 16 && h <= 8192; }

static void blur(const uint8_t *in, uint8_t *out, int w, int h, int radius) {
    if (radius == 1) { memcpy(out, in, (size_t)w * h); return; }
    for (int x = 0; x < w; x++) {
        int total = 0, lo = 0, hi = -1;
        for (int y = 0; y < h; y++) {
            while (hi < imin(h - 1, y + radius)) { hi++; total += in[hi * w + x]; }
            while (lo < imax(0, y - radius)) { total -= in[lo * w + x]; lo++; }
            out[y * w + x] = (uint8_t)floor((double)total / (hi - lo + 1) + .5);
        }
    }
}

static int anchors(const uint8_t *data, int w, int h, int budget, int *rows, double *scratch) {
    double *energy = scratch, *sorted = scratch + h;
    memset(energy, 0, (size_t)h * sizeof(double));
    for (int y = 1; y < h - 1; y++) {
        double value = 0;
        for (int x = 2; x < w - 2; x += 2) {
            int i = y * w + x;
            value += abs(data[i] - data[i - 2]) + abs(data[i] - data[i - w]) * 1.25;
        }
        energy[y] = value / (w / 2.0 - 2);
    }
    memcpy(sorted, energy, (size_t)h * sizeof(double));
    qsort(sorted, (size_t)h, sizeof(double), double_cmp);
    double median = sorted[h / 2], noise = median < 8 ? fmax(.25, median * 1.7) : .25;
    int count = 0, step = imax(1, h / budget);
    for (int start = 2; start < h - 2; start += step) {
        int end = imin(h - 2, start + step), first = start, second = -1;
        for (int y = start + 1; y < end; y++) if (energy[y] > energy[first]) first = y;
        if (energy[first] < noise) continue;
        rows[count++] = first;
        for (int y = start; y < end; y++) {
            if (abs(y - first) >= 2 && (second < 0 || energy[y] > energy[second])) second = y;
        }
        if (second >= 0 && energy[second] > noise) rows[count++] = second;
    }
    qsort(rows, (size_t)count, sizeof(int), int_cmp);
    return count;
}

static Score score(int overlap, const uint8_t *a, const uint8_t *b, int w, int h,
                   const int *rows, int row_count, double *errors) {
    int n = 0, count = 0;
    double sum = 0, square = 0;
    for (int r = 0; r < row_count; r++) {
        int y = rows[r];
        if (y >= overlap - 2) break;
        int ai = (h - overlap + y) * w, bi = y * w;
        double error = 0, weight = 0;
        for (int x = 2; x < w - 2; x += 2) {
            int q = b[bi + x], p = a[ai + x];
            double point_weight = 1 + fmin(3, abs(q - b[bi + x - 1]) / 12.0);
            int gradient = abs((p - a[ai + x - w]) - (q - b[bi + x - w]));
            error += (abs(p - q) + gradient * .6) * point_weight;
            weight += point_weight;
            sum += q; square += q * q; count++;
        }
        errors[n++] = error / weight;
    }
    Score out = {overlap, 255, 0, n};
    if (n < 6) return out;
    qsort(errors, (size_t)n, sizeof(double), double_cmp);
    int keep = imax(6, (int)ceil(n * .9));
    double total = 0;
    for (int i = 0; i < keep; i++) total += errors[i];
    out.error = total / keep;
    out.texture = sqrt(fmax(0, square / count - (sum / count) * (sum / count)));
    return out;
}

SSMatch ss_match(const uint8_t *a, const uint8_t *b, int w, int h) {
    SSMatch result = {0, 0, 0, 0, 0};
    if (!a || !b || !dimensions(w, h)) return result;
    size_t pixels = (size_t)w * h;
    double sum = 0; size_t changed = 0;
    for (size_t i = 0; i < pixels; i++) {
        int delta = abs(a[i] - b[i]); sum += delta; if (delta > 6) changed++;
    }
    if (sum / pixels < .7 && (double)changed / pixels < .003) {
        result.valid = 1; result.overlap = h; result.duplicate = 1;
        result.error = sum / pixels; result.confidence = 1;
        return result;
    }
    int stride = imax(1, h / 220), minimum = imax(16, (int)ceil(h * .22));
    uint8_t *coarse_a = malloc(pixels), *coarse_b = malloc(pixels);
    int *coarse_rows = malloc((size_t)h * 2 * sizeof(int));
    int *fine_rows = malloc((size_t)h * 2 * sizeof(int));
    double *scratch = malloc((size_t)h * 2 * sizeof(double));
    double *errors = malloc((size_t)h * 2 * sizeof(double));
    Score *coarse = malloc((size_t)(h + 1) * sizeof(Score));
    Score *fine = malloc((size_t)(h + 1) * sizeof(Score));
    uint8_t *visited = calloc((size_t)h + 1, 1);
    if (!coarse_a || !coarse_b || !coarse_rows || !fine_rows || !scratch || !errors || !coarse || !fine || !visited) goto cleanup;
    blur(a, coarse_a, w, h, stride); blur(b, coarse_b, w, h, stride);
    int cr = anchors(coarse_b, w, h, 120, coarse_rows, scratch);
    int fr = anchors(b, w, h, 240, fine_rows, scratch);
    int cn = 0, fn = 0;
    for (int n = h; n >= minimum; n -= stride) coarse[cn++] = score(n, coarse_a, coarse_b, w, h, coarse_rows, cr, errors);
    qsort(coarse, (size_t)cn, sizeof(Score), score_cmp);
    for (int i = 0; i < imin(8, cn); i++) {
        for (int n = imax(minimum, coarse[i].overlap - stride); n <= imin(h, coarse[i].overlap + stride); n++) {
            if (visited[n]) continue;
            visited[n] = 1;
            fine[fn++] = score(n, a, b, w, h, fine_rows, fr, errors);
        }
    }
    qsort(fine, (size_t)fn, sizeof(Score), score_cmp);
    if (!fn || fine[0].error > 10 || fine[0].texture < 2) goto cleanup;
    for (int i = 1; i < fn; i++) {
        if (abs(fine[i].overlap - fine[0].overlap) > imax(6, stride * 2)) {
            if (fine[i].error < fine[0].error * 1.12 + .25) goto cleanup;
            break;
        }
    }
    result.valid = 1; result.overlap = fine[0].overlap;
    result.duplicate = result.overlap == h;
    result.error = fine[0].error; result.confidence = fmax(0, 1 - result.error / 15);
cleanup:
    free(coarse_a); free(coarse_b); free(coarse_rows); free(fine_rows);
    free(scratch); free(errors); free(coarse); free(fine); free(visited);
    return result;
}

SSInsets ss_detect_insets(const uint8_t *samples, int count, int w, int h) {
    SSInsets out = {0, 0, 0};
    if (!samples || count < 3 || count > 12 || !dimensions(w, h)) return out;
    double *motion = calloc((size_t)h, sizeof(double)), *changed = calloc((size_t)h, sizeof(double));
    double *sorted = malloc((size_t)h * sizeof(double));
    uint8_t *moving = calloc((size_t)h, 1);
    if (!motion || !changed || !sorted || !moving) goto cleanup;
    int left = imax(1, (int)ceil(w * .05)), right = (int)floor(w * .95);
    size_t pixels = (size_t)w * h;
    for (int y = 0; y < h; y++) {
        for (int a = 0; a < count - 1; a++) for (int b = a + 1; b < count; b++) {
            int total = 0, significant = 0, n = right - left;
            for (int x = left; x < right; x++) {
                int d = abs(samples[(size_t)a * pixels + y * w + x] - samples[(size_t)b * pixels + y * w + x]);
                total += d; if (d > 12) significant++;
            }
            motion[y] = fmax(motion[y], (double)total / n);
            changed[y] = fmax(changed[y], (double)significant / n);
        }
    }
    memcpy(sorted, motion, (size_t)h * sizeof(double));
    qsort(sorted, (size_t)h, sizeof(double), double_cmp);
    double threshold = fmax(2.5, sorted[(int)floor(h * .75)] * .12);
    int moving_count = 0;
    for (int y = 0; y < h; y++) { moving[y] = motion[y] > threshold && changed[y] >= .04; moving_count += moving[y]; }
    if (moving_count < h * .08) goto cleanup;
    int window = imax(8, (int)floor(h * .012 + .5)), required = (int)ceil(window * .3);
    int first = -1, last = -1, total = 0;
    for (int y = 0; y < h; y++) {
        total += moving[y]; if (y >= window) total -= moving[y - window];
        if (y >= window - 1 && total >= required) {
            int start = y - window + 1;
            if (first < 0) { first = start; while (first < y && !moving[first]) first++; }
            last = y; while (last > start && !moving[last]) last--;
        }
    }
    if (first < 0 || last - first < h * .35) goto cleanup;
    out.top = imax(0, first); out.bottom = imax(0, h - 1 - last);
    if (out.top + out.bottom <= h * .65) out.valid = 1;
cleanup:
    free(motion); free(changed); free(sorted); free(moving);
    return out;
}

void ss_gate_reset(SSCaptureGate *gate) {
    if (!gate) return;
    gate->background = 0; gate->not_before = 0; gate->last_sample = -1;
}
void ss_gate_background(SSCaptureGate *gate, int background, double now) {
    if (!gate || !isfinite(now)) return;
    gate->background = background != 0;
    gate->not_before = now + 1.2; /* Avoid home screen / app-switch animation. */
    gate->last_sample = -1;
}
int ss_gate_accept(SSCaptureGate *gate, double now) {
    if (!gate || !isfinite(now) || !gate->background || now < gate->not_before) return 0;
    if (gate->last_sample >= 0 && now - gate->last_sample < .20) return 0;
    gate->last_sample = now;
    return 1;
}
int ss_archive_can_add(size_t bytes, int count, size_t next_bytes) {
    const size_t maximum = 96u * 1024u * 1024u;
    return count >= 0 && count < 320 && bytes <= maximum && next_bytes <= maximum - bytes;
}
