#!/bin/sh
# PGCR Mirror v0.3 runtime launcher.
# Separate binary/runtime; shared only with the installed V2.2 Java controller
# through the existing active/ready/HMI-state seams.

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || fail "Could not resolve script directory"
[ -n "$SCRIPT_DIR" ] || fail "Could not resolve script directory"
ROOT_DIR=$(dirname "$SCRIPT_DIR") || fail "Could not resolve runtime directory"

BIN="${PGCR_BIN:-$ROOT_DIR/pgcr-mirror-display}"
LOG="${PGCR_LOG:-/tmp/pgcr-mirror.log}"
LOG_MAX_BYTES="${PGCR_LOG_MAX_BYTES:-524288}"
LOG_SINK="$SCRIPT_DIR/bounded_log.sh"

ACTIVE_MARKER="/tmp/mmi-mirror-active"
READY_MARKER="/tmp/mmi-mirror-basevideo.ready"

[ -x "$BIN" ] || fail "PGCR executable not found: $BIN"
[ -f "$LOG_SINK" ] || fail "PGCR log sink not found: $LOG_SINK"

if [ -f "$ROOT_DIR/config.local" ]; then
    . "$ROOT_DIR/config.local" || fail "Could not load $ROOT_DIR/config.local"
fi

export IPL_CONFIG_DIR="${IPL_CONFIG_DIR:-/etc/eso/production}"
export LD_LIBRARY_PATH="/mnt/app/eso/lib:/eso/lib:/mnt/app/root/lib-target:/mnt/app/usr/lib:/mnt/app/armle/lib:/mnt/app/armle/lib/dll:/mnt/app/armle/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

PGCR_CAPTURE_FPS="${PGCR_CAPTURE_FPS:-30}"
PGCR_CAPTURE_RECOVER_MS="${PGCR_CAPTURE_RECOVER_MS:-3000}"
PGCR_HMI_POLL_MS="${PGCR_HMI_POLL_MS:-100}"

PGCR_CLASSIC_FULL_MODE="${PGCR_CLASSIC_FULL_MODE:-cover}"
PGCR_CLASSIC_FULL_ZOOM="${PGCR_CLASSIC_FULL_ZOOM:-1.00}"
PGCR_CLASSIC_FULL_PAN_X="${PGCR_CLASSIC_FULL_PAN_X:-0.00}"
PGCR_CLASSIC_FULL_PAN_Y="${PGCR_CLASSIC_FULL_PAN_Y:-0.00}"
PGCR_CROP_LEFT="${PGCR_CROP_LEFT:-0.00}"
PGCR_CROP_RIGHT="${PGCR_CROP_RIGHT:-0.00}"
PGCR_CROP_TOP="${PGCR_CROP_TOP:-0.00}"
PGCR_CROP_BOTTOM="${PGCR_CROP_BOTTOM:-0.00}"

PGCR_CLASSIC_FULL_SCALE="${PGCR_CLASSIC_FULL_SCALE:-0.63}"
PGCR_CLASSIC_FULL_OFFSET_X="${PGCR_CLASSIC_FULL_OFFSET_X:-0}"
PGCR_CLASSIC_FULL_OFFSET_Y="${PGCR_CLASSIC_FULL_OFFSET_Y:-8}"

PGCR_CLASSIC_SMALL_SCALE="${PGCR_CLASSIC_SMALL_SCALE:-0.63}"
PGCR_CLASSIC_SMALL_OFFSET_X="${PGCR_CLASSIC_SMALL_OFFSET_X:-0}"
PGCR_CLASSIC_SMALL_OFFSET_Y="${PGCR_CLASSIC_SMALL_OFFSET_Y:-8}"

PGCR_SPORT_FULL_SCALE="${PGCR_SPORT_FULL_SCALE:-0.63}"
PGCR_SPORT_FULL_OFFSET_X="${PGCR_SPORT_FULL_OFFSET_X:-0}"
PGCR_SPORT_FULL_OFFSET_Y="${PGCR_SPORT_FULL_OFFSET_Y:-8}"

PGCR_SPORT_SMALL_SCALE="${PGCR_SPORT_SMALL_SCALE:-0.63}"
PGCR_SPORT_SMALL_OFFSET_X="${PGCR_SPORT_SMALL_OFFSET_X:-0}"
PGCR_SPORT_SMALL_OFFSET_Y="${PGCR_SPORT_SMALL_OFFSET_Y:-8}"

COVER_ARG=""
case "$PGCR_CLASSIC_FULL_MODE" in
    cover) COVER_ARG="--classic-full-cover" ;;
    fit|"") COVER_ARG="" ;;
    *) fail "Unsupported PGCR_CLASSIC_FULL_MODE: $PGCR_CLASSIC_FULL_MODE" ;;
esac

rm -f "$READY_MARKER" 2>/dev/null || true
echo "$$" > "$ACTIVE_MARKER" 2>/dev/null || true
trap 'rm -f "$ACTIVE_MARKER" "$READY_MARKER" 2>/dev/null || true' 0 1 2 15

{
    echo ""
    echo "===== $(date) PGCR MIRROR v0.3 ====="
    echo "capture=1024x480/BGRA fps=$PGCR_CAPTURE_FPS recover_ms=$PGCR_CAPTURE_RECOVER_MS"
    echo "displayable=3 output=1440x455 context_owner=existing-java80"
    echo "full_mode=$PGCR_CLASSIC_FULL_MODE crop=($PGCR_CROP_LEFT,$PGCR_CROP_RIGHT,$PGCR_CROP_TOP,$PGCR_CROP_BOTTOM) zoom=$PGCR_CLASSIC_FULL_ZOOM pan=($PGCR_CLASSIC_FULL_PAN_X,$PGCR_CLASSIC_FULL_PAN_Y)"
    echo "log=$LOG"

    "$BIN"         --mmi         --capture-recover-ms "$PGCR_CAPTURE_RECOVER_MS"         --fps "$PGCR_CAPTURE_FPS"         --hmi-poll-ms "$PGCR_HMI_POLL_MS"         --classic-full-scale "$PGCR_CLASSIC_FULL_SCALE"         --classic-full-offset-x "$PGCR_CLASSIC_FULL_OFFSET_X"         --classic-full-offset-y "$PGCR_CLASSIC_FULL_OFFSET_Y"         --classic-small-scale "$PGCR_CLASSIC_SMALL_SCALE"         --classic-small-offset-x "$PGCR_CLASSIC_SMALL_OFFSET_X"         --classic-small-offset-y "$PGCR_CLASSIC_SMALL_OFFSET_Y"         --sport-full-scale "$PGCR_SPORT_FULL_SCALE"         --sport-full-offset-x "$PGCR_SPORT_FULL_OFFSET_X"         --sport-full-offset-y "$PGCR_SPORT_FULL_OFFSET_Y"         --sport-small-scale "$PGCR_SPORT_SMALL_SCALE"         --sport-small-offset-x "$PGCR_SPORT_SMALL_OFFSET_X"         --sport-small-offset-y "$PGCR_SPORT_SMALL_OFFSET_Y"         $COVER_ARG         --crop-left "$PGCR_CROP_LEFT"         --crop-right "$PGCR_CROP_RIGHT"         --crop-top "$PGCR_CROP_TOP"         --crop-bottom "$PGCR_CROP_BOTTOM"         --classic-full-zoom "$PGCR_CLASSIC_FULL_ZOOM"         --classic-full-pan-x "$PGCR_CLASSIC_FULL_PAN_X"         --classic-full-pan-y "$PGCR_CLASSIC_FULL_PAN_Y"         --verbose         "$@"
} 2>&1 | /bin/sh "$LOG_SINK" "$LOG" "$LOG_MAX_BYTES"

STATUS=$?
rm -f "$ACTIVE_MARKER" "$READY_MARKER" 2>/dev/null || true
trap - 0 1 2 15
exit "$STATUS"
