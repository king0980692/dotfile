#!/bin/bash
CACHE="/tmp/tmux_external_ip"
MAX_AGE=300 # 5 minutes

if [ -f "$CACHE" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$CACHE") ))
    if [ "$age" -lt "$MAX_AGE" ]; then
        cat "$CACHE"
        exit 0
    fi
fi

ip=$(curl -s --max-time 2 ifconfig.me)
if [ -n "$ip" ]; then
    echo "$ip" > "$CACHE"
    echo "$ip"
elif [ -f "$CACHE" ]; then
    cat "$CACHE"
fi
