#!/bin/bash
# Waybar media status module - outputs JSON for waybar

# Safe UTF-8 truncate - won't break multi-byte characters
utf8_truncate() {
    local str="$1"
    local max_chars="$2"
    # Use awk to handle UTF-8 properly
    echo -n "$str" | awk -v max="$max_chars" '{print substr($0, 1, max)}'
}

# JSON escape function - escape special characters
json_escape() {
    local str="$1"
    # Remove any invalid UTF-8 sequences first
    str=$(echo -n "$str" | iconv -f UTF-8 -t UTF-8 -c 2>/dev/null)
    # Escape backslash first, then other special chars
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/}"
    str="${str//$'\t'/\\t}"
    # Remove any other control characters
    str=$(echo -n "$str" | tr -d '\000-\037')
    echo -n "$str"
}

get_status() {
    # Find the active player (prefer playing, then paused)
    local player=""
    local status=""

    # Check all players for one that's playing
    for p in $(playerctl -l 2>/dev/null); do
        local s=$(playerctl -p "$p" status 2>/dev/null)
        if [[ "$s" == "Playing" ]]; then
            player="$p"
            status="Playing"
            break
        elif [[ "$s" == "Paused" && -z "$player" ]]; then
            player="$p"
            status="Paused"
        fi
    done

    # If no playing/paused player found, use default
    if [[ -z "$player" ]]; then
        status=$(playerctl status 2>/dev/null)
        player=$(playerctl metadata --format '{{playerName}}' 2>/dev/null)
    fi

    # Get metadata and truncate safely (UTF-8 aware)
    local title=$(playerctl -p "$player" metadata title 2>/dev/null)
    local artist=$(playerctl -p "$player" metadata artist 2>/dev/null)
    title=$(utf8_truncate "$title" 30)
    artist=$(utf8_truncate "$artist" 20)

    local icon=$'\uf04b'  # play icon
    local class="stopped"
    local tooltip="没有正在播放的媒体"

    if [[ -z "$status" || "$status" == "No players found" ]]; then
        printf '{"text": "%s", "alt": "stopped", "tooltip": "%s", "class": "stopped"}\n' "$icon" "$tooltip"
        return
    fi

    case "$status" in
        Playing)
            icon=$'\uf04c'  # pause icon
            class="playing"
            ;;
        Paused)
            icon=$'\uf04b'  # play icon
            class="paused"
            ;;
        *)
            icon=$'\uf04b'  # play icon
            class="stopped"
            ;;
    esac

    if [[ -n "$title" ]]; then
        # Escape special characters for JSON
        title=$(json_escape "$title")
        artist=$(json_escape "$artist")
        player=$(json_escape "$player")

        tooltip="$title"
        if [[ -n "$artist" ]]; then
            tooltip="$tooltip - $artist"
        fi
        if [[ -n "$player" ]]; then
            tooltip="$tooltip\\n$player"
        fi
    else
        tooltip="$status"
    fi

    printf '{"text": "%s", "alt": "%s", "tooltip": "%s", "class": "%s"}\n' \
        "$icon" "$class" "$tooltip" "$class"
}

# Continuous output mode for waybar
# Use multiple playerctl --follow listeners for instant updates

cleanup() {
    # Kill all background jobs
    jobs -p | xargs -r kill 2>/dev/null
    exit 0
}
trap cleanup EXIT INT TERM

# Output initial status
get_status

# Track last output to avoid duplicates
LAST_OUTPUT=""
output_if_changed() {
    local output
    output=$(get_status)
    if [[ "$output" != "$LAST_OUTPUT" ]]; then
        echo "$output"
        LAST_OUTPUT="$output"
    fi
}

# Watch for status changes (play/pause/stop)
(
    playerctl --follow status 2>/dev/null | while read -r _; do
        output_if_changed
    done
) &

# Watch for metadata changes (track change, seek, etc.)
(
    playerctl --follow metadata 2>/dev/null | while read -r _; do
        output_if_changed
    done
) &

# Watch for player add/remove
(
    while true; do
        playerctl --follow metadata --format '{{playerName}}' 2>/dev/null | while read -r _; do
            output_if_changed
        done
        sleep 1
    done
) &

# Fallback polling every 2 seconds for players that don't emit signals properly
(
    while true; do
        sleep 2
        output_if_changed
    done
) &

# Keep script running
wait
