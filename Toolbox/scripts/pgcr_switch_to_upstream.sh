#!/bin/sh
# Stop PGCR and return to the original upstream MMI Mirror session.

if [ -f /eso/hmi/engdefs/scripts/mqb/stop_pgcr_toolbox.sh ]; then
    /bin/sh /eso/hmi/engdefs/scripts/mqb/stop_pgcr_toolbox.sh || exit 1
fi

if [ ! -f /eso/hmi/engdefs/scripts/mqb/start_mmi_mirror_toolbox.sh ]; then
    echo "ERROR: upstream MMI Mirror start helper not found."
    exit 1
fi

/bin/sh /eso/hmi/engdefs/scripts/mqb/start_mmi_mirror_toolbox.sh
