#!/bin/sh
BASE=/tmp/pgcr-v04-baseline.txt
CAR=/tmp/pgcr-v04-carplay.txt
[ -f "$BASE" ] || { echo "ERROR: run Probe BASELINE first."; exit 1; }
[ -f "$CAR" ] || { echo "ERROR: run Probe CARPLAY second."; exit 1; }

OUT=/tmp/pgcr-v04-compare.txt
{
 echo "===== PGCR v0.4 CarPlay differential ====="
 echo
 echo "---- Screen/window lines only in CARPLAY snapshot ----"
 grep '^WINDOW ' "$CAR" | while IFS= read -r line; do
   key=$(echo "$line" | sed 's/ handle=0x[0-9A-Fa-f]*$//')
   grep -F "$key" "$BASE" >/dev/null 2>&1 || echo "$line"
 done
 echo
 echo "---- Relevant process lines only in CARPLAY snapshot ----"
 grep -i -E 'carplay|apple|airplay|projection|phone|iphone' "$CAR" || true
 echo
 echo "---- Displays ----"
 grep -E '^DISPLAY |^display_count=|^window_count=' "$CAR" || true
} > "$OUT"

if [ -f /eso/hmi/engdefs/scripts/mqb/util_mountsd.sh ]; then
 . /eso/hmi/engdefs/scripts/mqb/util_mountsd.sh >/dev/null 2>&1 || true
 if [ -n "${VOLUME:-}" ] && [ -d "$VOLUME" ]; then
   mkdir -p "$VOLUME/PGCR-Probe" 2>/dev/null || true
   cp "$OUT" "$VOLUME/PGCR-Probe/compare.txt" 2>/dev/null || true
   sync 2>/dev/null || true
 fi
fi

cat "$OUT"
exit 0
