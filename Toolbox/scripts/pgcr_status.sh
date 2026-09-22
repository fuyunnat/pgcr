#!/bin/sh
CFG="/mnt/app/root/pgcr/config.local"

echo "===== PGCR Display Lab status ====="

if [ ! -f "$CFG" ]; then
    echo "PGCR runtime: NOT INSTALLED"
    exit 1
fi

grep '^PGCR_CLASSIC_FULL_MODE=' "$CFG" 2>/dev/null || true
grep '^PGCR_CLASSIC_FULL_ZOOM=' "$CFG" 2>/dev/null || true
grep '^PGCR_CLASSIC_FULL_PAN_X=' "$CFG" 2>/dev/null || true
grep '^PGCR_CLASSIC_FULL_PAN_Y=' "$CFG" 2>/dev/null || true

if command -v pidin >/dev/null 2>&1 && pidin ar 2>/dev/null | grep '[p]gcr-mirror-display' >/dev/null 2>&1; then
    echo "PGCR process: RUNNING"
else
    echo "PGCR process: STOPPED"
fi

echo "Log: /tmp/pgcr-mirror.log"
echo "==================================="
exit 0
