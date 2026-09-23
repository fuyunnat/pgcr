#!/bin/sh
RUNTIME="/mnt/app/root/mmi-mirror"
CFG="${RUNTIME}/config.local"

echo "===== PGCR geometry status ====="
if [ ! -f "${CFG}" ]; then
    echo "MMI Mirror config.local not found."
    exit 1
fi

grep '^MMI_CLASSIC_FULL_' "${CFG}" 2>/dev/null || true
grep '^MMI_CLASSIC_SMALL_' "${CFG}" 2>/dev/null || true
grep '^MMI_SPORT_FULL_' "${CFG}" 2>/dev/null || true
grep '^MMI_SPORT_SMALL_' "${CFG}" 2>/dev/null || true

if [ -f "${RUNTIME}/config.local.pgcr-original" ]; then
    echo "PGCR original backup: PRESENT"
else
    echo "PGCR original backup: not created yet"
fi

echo "=============================="
exit 0
