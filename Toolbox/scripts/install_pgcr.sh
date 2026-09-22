#!/bin/sh
# Install/update PGCR sidecar runtime without touching upstream MMI Mirror payload.

export PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/armle/bin:/mnt/app/armle/usr/bin:$PATH

if [ "$_" = "/bin/on" ]; then BASE="$0"; else BASE="$_"; fi
SCRIPTDIR=$( cd -P -- "$(dirname -- "$(command -v -- "$BASE")")" && pwd -P )

. "${SCRIPTDIR}/util_info.sh"
. "${SCRIPTDIR}/util_mountsd.sh"

[ -n "${VOLUME:-}" ] || { echo "No SD-card found"; exit 1; }

SOURCE="${VOLUME}/Toolbox/apps/pgcr"
TARGET="/mnt/app/root/pgcr"
STAGE="${TARGET}.new"
ROLLBACK="${TARGET}.rollback"

BIN_SRC="${SOURCE}/pgcr-mirror-display"
START_SRC="${SOURCE}/scripts/start_pgcr_mirror.sh"
LOG_SRC="${SOURCE}/scripts/bounded_log.sh"
CFG_SRC="${SOURCE}/config.local"

[ -d /mnt/app/root/mmi-mirror ] || {
    echo "ERROR: upstream MMI Mirror V2.2 runtime is not installed."
    echo "PGCR v0.2 uses the existing Java ctx80 controller and must be installed after upstream V2.2."
    exit 1
}

[ -s "$BIN_SRC" ] || {
    echo "ERROR: missing compiled PGCR binary:"
    echo "$BIN_SRC"
    exit 1
}
[ -f "$START_SRC" ] || { echo "ERROR: missing PGCR runtime launcher"; exit 1; }
[ -f "$LOG_SRC" ] || { echo "ERROR: missing PGCR bounded log helper"; exit 1; }
[ -f "$CFG_SRC" ] || { echo "ERROR: missing PGCR config.local"; exit 1; }

if [ -f "${SCRIPTDIR}/stop_pgcr_toolbox.sh" ]; then
    /bin/sh "${SCRIPTDIR}/stop_pgcr_toolbox.sh" >/dev/null 2>&1 || true
fi

mount -uw /mnt/app || { echo "ERROR: could not mount /mnt/app read-write"; exit 1; }

rm -rf "$STAGE" 2>/dev/null || true
mkdir -p "$STAGE/scripts" || exit 1

cp "$BIN_SRC" "$STAGE/pgcr-mirror-display" || exit 1
chmod 755 "$STAGE/pgcr-mirror-display" || exit 1
cp "$START_SRC" "$STAGE/scripts/start_pgcr_mirror.sh" || exit 1
chmod 755 "$STAGE/scripts/start_pgcr_mirror.sh" || exit 1
cp "$LOG_SRC" "$STAGE/scripts/bounded_log.sh" || exit 1
chmod 755 "$STAGE/scripts/bounded_log.sh" || exit 1

if [ -f "$TARGET/config.local" ]; then
    cp "$TARGET/config.local" "$STAGE/config.local" || exit 1
    echo "Preserved existing PGCR config.local"
else
    cp "$CFG_SRC" "$STAGE/config.local" || exit 1
    echo "Installed default PGCR config.local"
fi
chmod 644 "$STAGE/config.local" 2>/dev/null || true

"$STAGE/pgcr-mirror-display" --help >/tmp/pgcr-install-selftest.log 2>&1 || {
    echo "ERROR: PGCR binary loader self-test failed:"
    cat /tmp/pgcr-install-selftest.log 2>/dev/null || true
    rm -rf "$STAGE"
    mount -ur /mnt/app 2>/dev/null || true
    exit 1
}
rm -f /tmp/pgcr-install-selftest.log 2>/dev/null || true

rm -rf "$ROLLBACK" 2>/dev/null || true
if [ -d "$TARGET" ]; then
    mv "$TARGET" "$ROLLBACK" || exit 1
fi

if ! mv "$STAGE" "$TARGET"; then
    [ -d "$ROLLBACK" ] && mv "$ROLLBACK" "$TARGET" 2>/dev/null || true
    mount -ur /mnt/app 2>/dev/null || true
    exit 1
fi

rm -rf "$ROLLBACK" 2>/dev/null || true
sync 2>/dev/null || true
mount -ur /mnt/app 2>/dev/null || true

echo "PGCR Mirror v0.2 installed."
echo "Upstream MMI Mirror files were not modified."
echo "Use Green Menu -> PGCR Display Lab -> Start PGCR WideMap."
exit 0
