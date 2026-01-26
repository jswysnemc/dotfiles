#!/bin/bash
# Get today's lunar info for waybar clock tooltip
cd ~/.config/quickshell
result=$(uv run python calendar/lunar_calendar.py today 2>/dev/null)
lunar=$(echo "$result" | jq -r '.lunar // ""')
festival=$(echo "$result" | jq -r '.festival // ""')

if [[ -n "$festival" ]]; then
    echo "$lunar ($festival)"
else
    echo "$lunar"
fi
