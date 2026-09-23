#!/bin/sh
# Restore the exact runtime config captured before the first PGCR preset.

export PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/armle/bin:/mnt/app/armle/usr/bin:$PATH

RUNTIME="/mnt/app/root/mmi-mirror"
CFG="${RUNTIME}/config.local"
ORIGINAL="${RUNTIME}/config.local.pgcr-original"
STOP="/eso/hmi/engdefs/scripts/mqb/stop_mmi_mirror_toolbox.sh"
START="/eso/hmi/engdefs/scripts/mqb/start_mmi_mirror_toolbox.sh"
WAS_RUNNING=0

is_running() {
    if command -v pidin >/dev/null 2>&1; then
        pidin ar 2>/dev/null | grep '[m]mi-mirror-display' >/dev/null 2>&1
        return $?
    fi
    [ -f /tmp/mmi-mirror-stage1.pid ]
}

[ -f "${ORIGINAL}" ] || {
    echo "No PGCR original backup exists yet."
    echo "Use 'Classic FULL 63%' for the published V2.2 baseline."
    exit 1
}

if is_running; then
    WAS_RUNNING=1
    /bin/sh "${STOP}" || exit 1
fi

mount -uw /mnt/app || {
    echo "ERROR: could not mount /mnt/app read-write"
    [ "${WAS_RUNNING}" -eq 1 ] && /bin/sh "${START}" >/dev/null 2>&1 || true
    exit 1
}

cp "${ORIGINAL}" "${CFG}" || {
    mount -ur /mnt/app 2>/dev/null || true
    echo "ERROR: restore copy failed"
    [ "${WAS_RUNNING}" -eq 1 ] && /bin/sh "${START}" >/dev/null 2>&1 || true
    exit 1
}
chmod 644 "${CFG}" 2>/dev/null || true
sync 2>/dev/null || true
mount -ur /mnt/app 2>/dev/null || true

echo "PGCR original geometry restored."
grep '^MMI_.*_SCALE=' "${CFG}" 2>/dev/null || true

if [ "${WAS_RUNNING}" -eq 1 ]; then
    /bin/sh "${START}" || exit 1
fi
exit 0
