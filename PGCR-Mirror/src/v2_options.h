#ifndef V2_OPTIONS_H
#define V2_OPTIONS_H

#include "base_video_layout_controller.h"
#include "mmi_capture_source.h"
#include "mhi2q_backend.h"

enum RunMode {
    RUN_MODE_NONE = 0,
    RUN_MODE_MMI,
    RUN_MODE_TEST
};

struct Options {
    RunMode mode;
    bool verbose;
    bool fullscreen;
    int test_seconds;
    int fps;
    int capture_wait_ms;
    int failure_threshold;
    int capture_recover_ms;
    int hmi_poll_ms;

    BaseVideoLayoutProfiles profiles;

    /* PGCR source viewport for Classic + Full only.
     * cover=false preserves upstream FIT behavior.
     * cover=true fills destination by cropping source without distortion. */
    bool classic_full_cover;
    float classic_full_zoom;
    float classic_full_pan_x;
    float classic_full_pan_y;
    float crop_left;
    float crop_right;
    float crop_top;
    float crop_bottom;

    MmiCaptureConfig capture;
    Mhi2qBackendConfig backend;
};

void v2_defaults(Options *o);
bool v2_parse_options(int argc, char **argv, Options *o);
void v2_usage(const char *argv0);

#endif
