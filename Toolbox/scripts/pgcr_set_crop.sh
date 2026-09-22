#!/bin/sh
# PGCR v0.3 asymmetric crop preset setter.
# Usage: pgcr_set_crop.sh LEFT RIGHT TOP BOTTOM ZOOM PAN_X PAN_Y

export PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/armle/bin:/mnt/app/armle/usr/bin:$PATH

LEFT="$1"
RIGHT="$2"
TOP="$3"
BOTTOM="$4"
ZOOM="$5"
PANX="$6"
PANY="$7"

valid_crop() {
    case "$1" in
        0|0.00|0.02|0.03|0.04|0.06|0.08|0.10|0.12|0.15) return 0 ;;
        *) return 1 ;;
    esac
}

valid_crop "$LEFT" || { echo "ERROR: unsupported left crop: $LEFT"; exit 1; }
valid_crop "$RIGHT" || { echo "ERROR: unsupported right crop: $RIGHT"; exit 1; }
valid_crop "$TOP" || { echo "ERROR: unsupported top crop: $TOP"; exit 1; }
valid_crop "$BOTTOM" || { echo "ERROR: unsupported bottom crop: $BOTTOM"; exit 1; }

case "$ZOOM" in
    1.00|1.05|1.10) ;;
    *) echo "ERROR: unsupported zoom: $ZOOM"; exit 1 ;;
esac

case "$PANX" in
    -0.25|-0.10|0|0.00|0.10|0.25) ;;
    *) echo "ERROR: unsupported pan-x: $PANX"; exit 1 ;;
esac

case "$PANY" in
    -0.25|-0.10|0|0.00|0.10|0.25) ;;
    *) echo "ERROR: unsupported pan-y: $PANY"; exit 1 ;;
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

set_key PGCR_CLASSIC_FULL_MODE "cover" "$CFG" || exit 1
set_key PGCR_CLASSIC_FULL_ZOOM "$ZOOM" "$CFG" || exit 1
set_key PGCR_CLASSIC_FULL_PAN_X "$PANX" "$CFG" || exit 1
set_key PGCR_CLASSIC_FULL_PAN_Y "$PANY" "$CFG" || exit 1
set_key PGCR_CROP_LEFT "$LEFT" "$CFG" || exit 1
set_key PGCR_CROP_RIGHT "$RIGHT" "$CFG" || exit 1
set_key PGCR_CROP_TOP "$TOP" "$CFG" || exit 1
set_key PGCR_CROP_BOTTOM "$BOTTOM" "$CFG" || exit 1

sync 2>/dev/null || true
mount -ur /mnt/app 2>/dev/null || true

echo "PGCR v0.3 crop preset applied:"
echo "  crop L/R/T/B=($LEFT,$RIGHT,$TOP,$BOTTOM)"
echo "  zoom=$ZOOM pan=($PANX,$PANY)"
echo "  aspect is preserved; COVER may add crop on one axis."

if [ "$WAS_RUNNING" -eq 1 ]; then
    /bin/sh /eso/hmi/engdefs/scripts/mqb/start_pgcr_toolbox.sh || exit 1
fi
exit 0
