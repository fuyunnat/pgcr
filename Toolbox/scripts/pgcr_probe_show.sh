#!/bin/sh
F=/tmp/pgcr-v04-compare.txt
[ -f "$F" ] || F=/tmp/pgcr-v04-carplay.txt
[ -f "$F" ] || { echo "No v0.4 probe result yet."; exit 1; }
cat "$F"
