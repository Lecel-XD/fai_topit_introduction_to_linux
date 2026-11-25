#!/bin/bash

root="$HOME/script32.log"

while true; do
    echo "$(date '+%d.%m.%Y %H:%M:%S') PID=$$ PPID=$PPID" >> "$root"
    sleep 2
done