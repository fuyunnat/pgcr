#!/bin/sh
# Set PGCR sidecar viewport preset.
# Usage: pgcr_set_viewport.sh MODE ZOOM PAN_X PAN_Y
# MODE: fit|cover

export PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/armle/bin:/mnt/app/armle/usr/bin:$PATH

MODE="$1"
ZOOM="$2"
PANX="$3"
PANY="$4"

case "$MODE" in
    fit|cover) ;;
    *) echo "ERROR: MODE must be fit or cover"; exit 1 ;;
esac

case "$ZOOM" in
    1.00|1.10|1.20|1.35) ;;
    *) echo "ERROR: unsupported zoom preset: $ZOOM"; exit 1 ;;
esac

case "$PANX" in
    -0.25|0|0.00|0.25) ;;
    *) echo "ERROR: unsupported pan-x preset: $PANX"; exit 1 ;;
esac

case "$PANY" in
    -0.25|0|0.00|0.25) ;;
    *) echo "ERROR: unsupported pan-y preset: $PANY"; exit 1 ;;
esac

RUNTIME="/mnt/app/root/pgcr"
CFG="$RUNTIME/config.local"
WAS_RUNNING=0

[ -f "$CFG" ] || {
    echo "ERROR: PGCR runtime/config not installed."
    exit 1
}

is_running() {
    if command -v pidin >/dev/null 2>&1; then
        pidin ar 2>/dev/null | grep '[p]gcr-mirror-display' >/dev/null 2>&1
        return $?
    fi
    [ -f /tmp/pgcr-mirror-wrapper.pid ]
}

set_key() {
    KEY="$1"
    VALUE="$2"
    FILE="$3"

    if grep "^$KEY=" "$FILE" >/dev/null 2>&1; then
        sed -i "s|^$KEY=.*|$KEY=$VALUE|" "$FILE" || return 1
    else
        echo "$KEY=$VALUE" >> "$FILE" || return 1
    fi
}

if is_running; then
    WAS_RUNNING=1
    /bin/sh /eso/hmi/engdefs/scripts/mqb/stop_pgcr_toolbox.sh || exit 1
fi

mount -uw /mnt/app || {
    echo "ERROR: could not mount /mnt/app read-write"
    exit 1
}

set_key PGCR_CLASSIC_FULL_MODE "$MODE" "$CFG" || exit 1
set_key PGCR_CLASSIC_FULL_ZOOM "$ZOOM" "$CFG" || exit 1
set_key PGCR_CLASSIC_FULL_PAN_X "$PANX" "$CFG" || exit 1
set_key PGCR_CLASSIC_FULL_PAN_Y "$PANY" "$CFG" || exit 1

sync 2>/dev/null || true
mount -ur /mnt/app 2>/dev/null || true

echo "PGCR viewport updated:"
echo "  mode=$MODE"
echo "  zoom=$ZOOM"
echo "  pan=($PANX,$PANY)"

if [ "$WAS_RUNNING" -eq 1 ]; then
    /bin/sh /eso/hmi/engdefs/scripts/mqb/start_pgcr_toolbox.sh || exit 1
fi

exit 0
