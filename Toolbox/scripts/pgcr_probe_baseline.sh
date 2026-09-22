#!/bin/sh
echo "BASELINE: disconnect/exit CarPlay before this snapshot."
exec /bin/sh /eso/hmi/engdefs/scripts/mqb/pgcr_probe_run.sh baseline
