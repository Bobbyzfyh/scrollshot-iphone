#include "../Core/SSMatcher.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { W = 64, H = 1600, SOURCE_H = 6000 };
static uint8_t source[W * SOURCE_H];
static uint8_t other[W * SOURCE_H];
static uint8_t sample[W * H];
static uint8_t screens[6 * W * 1900];
static void fixture(uint8_t *p, int height, unsigned seed) {
    for (int i = 0; i < W * height; i++) { seed = seed * 1664525u + 1013904223u; p[i] = 35 + seed % 195; }
}
static void chat(void) {
    memset(source, 248, sizeof(source));
    for (int k = 0; k < 36; k++) {
        int y = 70 + k * 145, x = k % 2 ? 20 : 4;
        for (int dy = 0; dy < 65; dy++) for (int dx = 0; dx < 38; dx++) source[(y + dy) * W + x + dx] = 238;
        for (int line = 0; line < 3; line++) for (int dx = 0; dx < 18 + (k * 7 + line * 3) % 16; dx++)
            for (int t = 0; t < 3; t++) source[(y + 12 + line * 15 + t) * W + x + 4 + dx] = 150 + (k * 13 + dx * 5) % 45;
    }
}
int main(void) {
    int tests = 0;
    fixture(source, SOURCE_H, 42);
    int shifts[] = {1, 13, 109, 373, 789, 1191};
    for (size_t i = 0; i < sizeof(shifts) / sizeof(shifts[0]); i++) {
        SSMatch m = ss_match(source, source + shifts[i] * W, W, H);
        assert(m.valid && m.overlap == H - shifts[i]); tests++;
    }
    memcpy(sample, source + 627 * W, sizeof(sample));
    for (size_t i = 0; i < sizeof(sample); i++) sample[i] = (uint8_t)(sample[i] + (int)(i % 5) - 2);
    SSMatch m = ss_match(source, sample, W, H);
    assert(m.valid && m.overlap == H - 627); tests++;
    m = ss_match(source, source, W, H); assert(m.valid && m.duplicate); tests++;
    memset(sample, 255, sizeof(sample)); m = ss_match(sample, sample, W, H); assert(m.duplicate); tests++;
    fixture(other, SOURCE_H, 987); assert(!ss_match(source, other, W, H).valid); tests++;
    assert(!ss_match(source + 800 * W, source, W, H).valid); tests++;
    for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
        source[y * W + x] = ((y % 40) * 5 + x * 3) % 256;
        sample[y * W + x] = (((y + 17) % 40) * 5 + x * 3) % 256;
    }
    assert(!ss_match(source, sample, W, H).valid); tests++;
    chat();
    int chat_shifts[] = {6, 19, 53, 81, 179, 431, 713};
    for (size_t i = 0; i < sizeof(chat_shifts) / sizeof(chat_shifts[0]); i++) {
        m = ss_match(source, source + chat_shifts[i] * W, W, H);
        assert(m.valid && m.overlap == H - chat_shifts[i]); tests++;
    }
    /* Exact reconstructed rows: no text cut off or repeated at any join. */
    fixture(source, SOURCE_H, 42);
    int positions[] = {0, 713, 1800, 2800}, cursor = H;
    memcpy(other, source, (size_t)W * H);
    for (int i = 1; i < 4; i++) {
        m = ss_match(source + positions[i - 1] * W, source + positions[i] * W, W, H);
        assert(m.valid);
        int added = H - m.overlap;
        memcpy(other + cursor * W, source + (positions[i] + m.overlap) * W, (size_t)added * W);
        cursor += added;
    }
    assert(cursor == 4400 && memcmp(source, other, (size_t)cursor * W) == 0); tests++;
    /* Fixed top/bottom UI must be excluded before matching. */
    for (int i = 0; i < 6; i++) {
        uint8_t *screen = screens + i * W * 1900;
        memset(screen, 40, W * 1900);
        memcpy(screen + 120 * W, source + i * 173 * W, W * H);
    }
    SSInsets crop = ss_detect_insets(screens, 6, W, 1900);
    assert(crop.valid && crop.top == 120 && crop.bottom == 180); tests++;
    m = ss_match(screens + crop.top * W, screens + W * 1900 + crop.top * W, W, H);
    assert(m.valid && m.overlap == H - 173); tests++;
    memset(screens, 255, sizeof(screens)); assert(!ss_detect_insets(screens, 6, W, 1900).valid); tests++;
    /* Invalid geometry / null inputs cannot read beyond an image. */
    assert(!ss_match(NULL, sample, W, H).valid);
    assert(!ss_match(source, sample, 7, H).valid);
    assert(!ss_match(source, sample, W, 8193).valid);
    assert(!ss_detect_insets(screens, 99, W, H).valid); tests++;
    SSCaptureGate gate; ss_gate_reset(&gate);
    assert(!ss_gate_accept(&gate, 10));
    ss_gate_background(&gate, 1, 10);
    assert(!ss_gate_accept(&gate, 11.19));
    assert(ss_gate_accept(&gate, 11.21));
    assert(!ss_gate_accept(&gate, 11.25));
    assert(ss_gate_accept(&gate, 11.42));
    ss_gate_background(&gate, 0, 12); assert(!ss_gate_accept(&gate, 20));
    ss_gate_background(&gate, 1, 21); assert(!ss_gate_accept(&gate, 21.2));
    assert(ss_gate_accept(&gate, 22.21));
    assert(!ss_gate_accept(&gate, NAN)); tests++;
    assert(ss_archive_can_add(0, 0, 100));
    assert(!ss_archive_can_add(96u * 1024 * 1024, 1, 1));
    assert(!ss_archive_can_add(0, 320, 1));
    assert(!ss_archive_can_add(1, -1, 1));
    assert(!ss_archive_can_add(1, 1, (size_t)-1)); tests++;
    printf("PASS: %d native core cases (alignment, chat, cropping, capture gate, bounds)\n", tests);
    return 0;
}
