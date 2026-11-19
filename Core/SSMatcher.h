#ifndef SS_MATCHER_H
#define SS_MATCHER_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int valid;
    int overlap;
    int duplicate;
    double error;
    double confidence;
} SSMatch;

typedef struct { int valid; int top; int bottom; } SSInsets;

/* Rows are top-to-bottom. The Swift adapter preserves vertical pixel resolution. */
SSMatch ss_match(const uint8_t *a, const uint8_t *b, int width, int height);
/* Contiguous count × height × width grayscale samples of uncropped screens. */
SSInsets ss_detect_insets(const uint8_t *samples, int count, int width, int height);

typedef struct {
    int background;
    double not_before;
    double last_sample;
} SSCaptureGate;
void ss_gate_reset(SSCaptureGate *gate);
void ss_gate_background(SSCaptureGate *gate, int background, double now);
int ss_gate_accept(SSCaptureGate *gate, double now);
int ss_archive_can_add(size_t bytes, int count, size_t next_bytes);

#ifdef __cplusplus
}
#endif
#endif
