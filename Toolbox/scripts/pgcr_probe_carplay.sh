#!/bin/sh
echo "CARPLAY: keep CarPlay connected and Amap visible before this snapshot."
exec /bin/sh /eso/hmi/engdefs/scripts/mqb/pgcr_probe_run.sh carplay
