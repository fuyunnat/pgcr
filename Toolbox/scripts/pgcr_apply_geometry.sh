#!/bin/sh
# PGCR geometry preset helper for MMI Mirror V2.2.
# Changes ONLY MMI_CLASSIC_FULL_SCALE in the installed runtime config.local.
# Core binary/JAR/context routing are never modified.

export PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/armle/bin:/mnt/app/armle/usr/bin:$PATH

SCALE="${1:-}"
case "${SCALE}" in
    0.63|0.75|0.80|0.85|0.90|0.95|1.00) ;;
    *)
        echo "ERROR: unsupported PGCR scale '${SCALE}'"
        exit 1
        ;;
esac

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

set_key() {
    KEY="$1"
    VAL="$2"
    FILE="$3"

    if grep "^${KEY}=" "${FILE}" >/dev/null 2>&1; then
        sed -i "s|^${KEY}=.*|${KEY}=${VAL}|" "${FILE}" || return 1
    else
        echo "${KEY}=${VAL}" >> "${FILE}" || return 1
    fi
    return 0
}

[ -d "${RUNTIME}" ] || {
    echo "ERROR: MMI Mirror runtime not installed: ${RUNTIME}"
    exit 1
}
[ -f "${CFG}" ] || {
    echo "ERROR: runtime config missing: ${CFG}"
    echo "Reinstall V2.2 once before using PGCR presets."
    exit 1
}

if is_running; then
    WAS_RUNNING=1
    echo "PGCR: stopping active Mirror session before geometry update..."
    /bin/sh "${STOP}" || {
        echo "ERROR: could not stop MMI Mirror"
        exit 1
    }
fi

mount -uw /mnt/app || {
    echo "ERROR: could not mount /mnt/app read-write"
    [ "${WAS_RUNNING}" -eq 1 ] && /bin/sh "${START}" >/dev/null 2>&1 || true
    exit 1
}

if [ ! -f "${ORIGINAL}" ]; then
    cp "${CFG}" "${ORIGINAL}" || {
        mount -ur /mnt/app 2>/dev/null || true
        echo "ERROR: could not create PGCR original-config backup"
        [ "${WAS_RUNNING}" -eq 1 ] && /bin/sh "${START}" >/dev/null 2>&1 || true
        exit 1
    }
    chmod 644 "${ORIGINAL}" 2>/dev/null || true
    echo "PGCR: preserved original config as config.local.pgcr-original"
fi

set_key "MMI_CLASSIC_FULL_SCALE" "${SCALE}" "${CFG}" || {
    mount -ur /mnt/app 2>/dev/null || true
    echo "ERROR: failed to update Classic FULL scale"
    [ "${WAS_RUNNING}" -eq 1 ] && /bin/sh "${START}" >/dev/null 2>&1 || true
    exit 1
}

sync 2>/dev/null || true
mount -ur /mnt/app 2>/dev/null || {
    echo "WARNING: geometry changed, but /mnt/app could not be remounted read-only"
}

echo "PGCR Classic FULL scale set to ${SCALE}"
grep '^MMI_CLASSIC_FULL_' "${CFG}" 2>/dev/null || true
echo "Other Classic/Sport profiles were left unchanged."

if [ "${WAS_RUNNING}" -eq 1 ]; then
    echo "PGCR: restarting Mirror with the new geometry..."
    /bin/sh "${START}" || {
        echo "ERROR: scale saved, but Mirror restart failed"
        exit 1
    }
fi

echo "Done. Test while parked and use 63% or Restore if clipping is excessive."
exit 0
