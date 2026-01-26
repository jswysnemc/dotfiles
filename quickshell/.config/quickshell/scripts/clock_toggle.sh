#!/bin/bash
# Toggle clock display state
STATE_FILE="/tmp/waybar_clock_state"
state=0
[[ -f "$STATE_FILE" ]] && state=$(cat "$STATE_FILE")
state=$(( (state + 1) % 3 ))
echo $state > "$STATE_FILE"
