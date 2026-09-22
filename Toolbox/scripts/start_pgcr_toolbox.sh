#!/bin/sh
# Start PGCR sidecar. Stops upstream MMI Mirror session first, but does not modify it.

export PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/armle/bin:/mnt/app/armle/usr/bin:$PATH

RUNTIME="/mnt/app/root/pgcr"
START_SCRIPT="$RUNTIME/scripts/start_pgcr_mirror.sh"
PIDFILE="/tmp/pgcr-mirror-wrapper.pid"

[ -x "$RUNTIME/pgcr-mirror-display" ] || {
    echo "ERROR: PGCR runtime not installed."
    exit 1
}
[ -f "$START_SCRIPT" ] || {
    echo "ERROR: PGCR launcher missing."
    exit 1
}

if command -v pidin >/dev/null 2>&1; then
    if pidin ar 2>/dev/null | grep '[m]mi-mirror-display' >/dev/null 2>&1; then
        if [ -f /eso/hmi/engdefs/scripts/mqb/stop_mmi_mirror_toolbox.sh ]; then
            echo "Stopping upstream MMI Mirror session first..."
            /bin/sh /eso/hmi/engdefs/scripts/mqb/stop_mmi_mirror_toolbox.sh || exit 1
        else
            echo "ERROR: upstream stop helper missing."
            exit 1
        fi
    fi

    if pidin ar 2>/dev/null | grep '[p]gcr-mirror-display' >/dev/null 2>&1; then
        echo "PGCR Mirror already running."
        exit 0
    fi
fi

rm -f "$PIDFILE" 2>/dev/null || true

if command -v nohup >/dev/null 2>&1; then
    nohup /bin/sh "$START_SCRIPT" >/dev/null 2>&1 &
else
    /bin/sh "$START_SCRIPT" >/dev/null 2>&1 &
fi

PID=$!
echo "$PID" > "$PIDFILE" 2>/dev/null || true
sleep 1

if kill -0 "$PID" 2>/dev/null; then
    echo "PGCR Mirror v0.3 started. Wrapper PID: $PID"
    echo "Log: /tmp/pgcr-mirror.log"
    exit 0
fi

rm -f "$PIDFILE" 2>/dev/null || true
echo "ERROR: PGCR Mirror exited during startup."
exit 1
