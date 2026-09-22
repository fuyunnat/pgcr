#!/bin/sh
# Stop PGCR sidecar only. Upstream MMI Mirror installation remains untouched.

export PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/armle/bin:/mnt/app/armle/usr/bin:$PATH

PIDFILE="/tmp/pgcr-mirror-wrapper.pid"
ACTIVE="/tmp/mmi-mirror-active"
READY="/tmp/mmi-mirror-basevideo.ready"

if command -v slay >/dev/null 2>&1; then
    slay -f -v pgcr-mirror-display 2>/dev/null || true
fi

if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE" 2>/dev/null || echo "")
    case "$PID" in
        ''|*[!0-9]*) ;;
        *) kill -TERM "$PID" 2>/dev/null || true ;;
    esac
    rm -f "$PIDFILE" 2>/dev/null || true
fi

rm -f "$ACTIVE" "$READY" 2>/dev/null || true
sync 2>/dev/null || true

echo "PGCR Mirror stop completed."
exit 0
