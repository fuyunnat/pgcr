#!/bin/sh
# Remove PGCR sidecar runtime only.

export PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/armle/bin:/mnt/app/armle/usr/bin:$PATH

if [ -f /eso/hmi/engdefs/scripts/mqb/stop_pgcr_toolbox.sh ]; then
    /bin/sh /eso/hmi/engdefs/scripts/mqb/stop_pgcr_toolbox.sh >/dev/null 2>&1 || true
fi

mount -uw /mnt/app || { echo "ERROR: could not mount /mnt/app read-write"; exit 1; }
rm -rf /mnt/app/root/pgcr || {
    mount -ur /mnt/app 2>/dev/null || true
    echo "ERROR: could not remove PGCR runtime"
    exit 1
}
sync 2>/dev/null || true
mount -ur /mnt/app 2>/dev/null || true

echo "PGCR sidecar removed."
echo "Upstream MMI Mirror installation was not changed."
exit 0
