#!/bin/sh
# PGCR v0.5 - direct stock smartphone displayable 59 -> cockpit route probe.
# Temporary diagnostic only. Auto-restores Audi stock context 74.

export PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/armle/bin:/mnt/app/armle/usr/bin:$PATH
export IPL_CONFIG_DIR=/etc/eso/production

DMDT=/eso/bin/apps/dmdt
LOG=/tmp/pgcr-direct59.log
RESTORE=/tmp/pgcr-direct59-restore.sh
CTX=90
SRC=59

: > "$LOG"
echo "===== PGCR v0.5 DIRECT SOURCE 59 TEST =====" | tee -a "$LOG"
echo "Target: stock DISPLAYABLE_EXTERNAL_SMARTPHONE (59)" | tee -a "$LOG"
echo "Temporary context: $CTX" | tee -a "$LOG"

[ -x "$DMDT" ] || { echo "ERROR: dmdt missing" | tee -a "$LOG"; exit 1; }

# Require an active CarPlay receiver generation. smartphone_integrator itself is
# boot-resident, but dio_manager appears when the CarPlay session is actually up.
if ! pidin ar 2>/dev/null | grep -q '/mnt/app/eso/bin/apps/dio_manager'; then
    echo "ERROR: active CarPlay dio_manager not found." | tee -a "$LOG"
    echo "Connect CarPlay and keep Amap visible, then run this test again." | tee -a "$LOG"
    exit 1
fi

# Do not race PGCR/MMI-Mirror's ctx80 owner.
if [ -x /eso/hmi/engdefs/scripts/mqb/stop_pgcr_toolbox.sh ]; then
    /bin/sh /eso/hmi/engdefs/scripts/mqb/stop_pgcr_toolbox.sh >/dev/null 2>&1 || true
fi
if [ -x /eso/hmi/engdefs/scripts/mqb/stop_mmi_mirror_toolbox.sh ]; then
    /bin/sh /eso/hmi/engdefs/scripts/mqb/stop_mmi_mirror_toolbox.sh >/dev/null 2>&1 || true
fi
sleep 1

echo "Defining diagnostic context $CTX -> displayable $SRC ..." | tee -a "$LOG"
"$DMDT" dc "$CTX" "$SRC" >>"$LOG" 2>&1
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "ERROR: dmdt dc $CTX $SRC failed rc=$RC" | tee -a "$LOG"
    exit 1
fi

# Fail closed if the context did not appear in DisplayManager's table.
if ! "$DMDT" gc 2>/dev/null | awk -v c="$CTX" '
    $1 == c { inctx=1; next }
    inctx && $1 ~ /^59$/ { found=1; exit }
    inctx && $1 ~ /^[-0-9]+$/ { exit }
    END { exit found ? 0 : 1 }
'; then
    echo "ERROR: context $CTX/source $SRC verification failed." | tee -a "$LOG"
    "$DMDT" dc "$CTX" 33 >/dev/null 2>&1 || true
    exit 1
fi

# Detached watchdog restores stock even after the GEM command returns.
cat > "$RESTORE" <<'EOF'
#!/bin/sh
export IPL_CONFIG_DIR=/etc/eso/production
D=/eso/bin/apps/dmdt
sleep 18
$D sc 1 72 >/tmp/pgcr-direct59-restore.log 2>&1
sleep 1
$D sc 1 74 >>/tmp/pgcr-direct59-restore.log 2>&1
$D dc 90 33 >>/tmp/pgcr-direct59-restore.log 2>&1
sync >/dev/null 2>&1
EOF
chmod 755 "$RESTORE"
if command -v on >/dev/null 2>&1; then
    on -d /bin/sh "$RESTORE" >/dev/null 2>&1
else
    /bin/sh "$RESTORE" >/dev/null 2>&1 &
fi

# Force a real context transition so the native pre-context hook selects the
# first displayable for the MOST encoder.
"$DMDT" sc 1 72 >>"$LOG" 2>&1
sleep 1
"$DMDT" sc 1 "$CTX" >>"$LOG" 2>&1
RC=$?

if [ "$RC" -ne 0 ]; then
    echo "ERROR: context switch failed rc=$RC; restoring stock now." | tee -a "$LOG"
    "$DMDT" sc 1 72 >>"$LOG" 2>&1 || true
    sleep 1
    "$DMDT" sc 1 74 >>"$LOG" 2>&1 || true
    "$DMDT" dc "$CTX" 33 >>"$LOG" 2>&1 || true
    exit 1
fi

echo
echo "DIRECT59 TEST ACTIVE."
echo "Back out of GEM NOW and open CarPlay/Amap."
echo "Watch the Virtual Cockpit for about 15 seconds."
echo "It will AUTO-RESTORE to Audi context 74."
echo
echo "If CarPlay appears in the cockpit, take a photo."
echo "If black/unchanged, wait for auto-restore and report that result."
exit 0
