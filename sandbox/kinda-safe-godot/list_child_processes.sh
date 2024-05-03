#!/bin/bash

extract_child_pid() {
    echo "$(ps --ppid $1)" | grep -oE '^[[:space:]]*[0-9]+' | awk '{print $1}'
}

pid=$1
while [[ -n "$pid" ]]; do
    pid=$(extract_child_pid "$pid")
    if [[ -n "$pid" ]]; then
        echo "$pid"
    fi
done
