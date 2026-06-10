#!/bin/bash
# Custom clock with lunar calendar for waybar
# Supports cycling through 3 display formats on click

cd ~/.config/quickshell 2>/dev/null

source "./scripts/lib/i18n.sh"

# 读取日历功能语言包中的字面量
i18n() {
    qs_i18n_literal "calendar" "$1"
}

STATE_FILE="/tmp/waybar_clock_state"

# Get or initialize state (0, 1, 2)
state=0
[[ -f "$STATE_FILE" ]] && state=$(cat "$STATE_FILE")

# Get current time/date
time_hm=$(date +"%H:%M")
time_hms=$(date +"%H:%M:%S")
date_md=$(date +"%-m/%-d %a")
date_ymd=$(date +"%y-%-m-%-d %A")

# Get lunar info (cache for 1 hour)
LUNAR_CACHE="/tmp/waybar_lunar_cache"
CACHE_AGE=3600
if [[ -f "$LUNAR_CACHE" ]] && [[ $(($(date +%s) - $(stat -c %Y "$LUNAR_CACHE"))) -lt $CACHE_AGE ]]; then
    lunar_info=$(cat "$LUNAR_CACHE")
else
    lunar_info=$(uv run python calendar/lunar_calendar.py today 2>/dev/null)
    echo "$lunar_info" > "$LUNAR_CACHE"
fi

lunar=$(echo "$lunar_info" | jq -r '.lunar // ""')
festival=$(echo "$lunar_info" | jq -r '.festival // ""')
weekday=$(echo "$lunar_info" | jq -r '.weekday // ""')

# Build display based on state
case $state in
    0) display="󰥔 $time_hm $date_md" ;;
    1) display="󰥔 $time_hms" ;;
    2) display="󰃭 $date_ymd" ;;
esac

# Build tooltip
if [[ "$(qs_i18n_language)" == "zh_CN" ]]; then
    tooltip_date=$(date +"%Y年%m月%d日 %A")
else
    tooltip_date=$(date +"%Y-%m-%d %A")
fi
tooltip_time="$(i18n "时间: ")$time_hms"
tooltip_lunar="$(i18n "农历: ")$lunar"
if [[ -n "$festival" ]]; then
    tooltip="$tooltip_date\n$tooltip_time"
    if [[ -n "$lunar" ]]; then
        tooltip="$tooltip\n$tooltip_lunar"
    fi
    tooltip="$tooltip\n$(i18n "节日: ")$festival"
else
    tooltip="$tooltip_date\n$tooltip_time"
    if [[ -n "$lunar" ]]; then
        tooltip="$tooltip\n$tooltip_lunar"
    fi
fi

# Output JSON
echo "{\"text\": \"$display\", \"tooltip\": \"$tooltip\", \"class\": \"clock\"}"
