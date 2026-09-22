#!/bin/sh
# PGCR v0.4 read-only CarPlay source probe helper.
# Usage: pgcr_probe_run.sh baseline|carplay

MODE="$1"
case "$MODE" in baseline|carplay) ;; *) echo "ERROR: baseline|carplay"; exit 1;; esac

export PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/armle/bin:/mnt/app/armle/usr/bin:$PATH
BIN="/mnt/app/root/pgcr/pgcr-screen-probe"
OUT="/tmp/pgcr-v04-$MODE.txt"

[ -x "$BIN" ] || { echo "ERROR: PGCR v0.4 probe binary not installed."; exit 1; }

{
  echo "===== PGCR v0.4 $MODE probe ====="
  date 2>/dev/null || true
  echo
  echo "===== QNX SCREEN WINDOWS ====="
  "$BIN" 2>&1
  echo
  echo "===== RELEVANT PROCESSES ====="
  pidin ar 2>&1 | grep -i -E 'carplay|apple|airplay|projection|phone|iphone|lsd|hmi|mmx|mirror|maneuver|render' || true
  echo
  echo "===== ALL PROCESSES ====="
  pidin ar 2>&1 || true
  echo
  echo "===== DISPLAY MANAGER GS ====="
  /eso/bin/apps/dmdt gs 2>&1 || true
  echo
  echo "===== DISPLAY MANAGER GC ====="
  /eso/bin/apps/dmdt gc 2>&1 || true
} > "$OUT"

chmod 644 "$OUT" 2>/dev/null || true

# Copy to SD when present, but probe still succeeds without SD.
if [ -f /eso/hmi/engdefs/scripts/mqb/util_mountsd.sh ]; then
  . /eso/hmi/engdefs/scripts/mqb/util_mountsd.sh >/dev/null 2>&1 || true
  if [ -n "${VOLUME:-}" ] && [ -d "$VOLUME" ]; then
    mkdir -p "$VOLUME/PGCR-Probe" 2>/dev/null || true
    cp "$OUT" "$VOLUME/PGCR-Probe/$MODE.txt" 2>/dev/null || true
    sync 2>/dev/null || true
  fi
fi

echo "PGCR v0.4 $MODE probe complete."
echo "Saved: $OUT"
[ -n "${VOLUME:-}" ] && echo "SD copy: $VOLUME/PGCR-Probe/$MODE.txt"
echo
echo "Summary:"
grep -E '^context_type=|^display_count=|^DISPLAY |^window_count=' "$OUT" 2>/dev/null || true
echo
echo "Potential CarPlay/phone processes:"
grep -i -E 'carplay|apple|airplay|projection|phone|iphone' "$OUT" 2>/dev/null | head -20 || true
exit 0
