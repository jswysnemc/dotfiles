#!/bin/bash
# Waybar media visualizer - real audio visualization using cava
# Uses unique config per process to avoid conflicts

# Use PID to create unique config file
CAVA_CONFIG="/tmp/waybar_cava_config_$$"

# Clean up old orphan cava processes on startup
cleanup_orphans() {
    # Kill any cava processes with old waybar configs (parent no longer exists)
    for cfg in /tmp/waybar_cava_config_*; do
        [[ -f "$cfg" ]] || continue
        local pid="${cfg##*_}"
        # Check if the parent script is still running
        if ! kill -0 "$pid" 2>/dev/null; then
            pkill -f "cava -p $cfg" 2>/dev/null
            rm -f "$cfg"
        fi
    done
}

# Create cava config for raw output
setup_config() {
    cat > "$CAVA_CONFIG" << EOF
[general]
bars = 12
framerate = 60
sensitivity = 120
noise_reduction = 0.5

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF
}

cleanup() {
    # Kill cava processes using our specific config
    pkill -f "cava -p $CAVA_CONFIG" 2>/dev/null
    rm -f "$CAVA_CONFIG"
    exit 0
}

# Handle all termination signals
trap cleanup EXIT INT TERM HUP QUIT PIPE

is_playing() {
    for p in $(playerctl -l 2>/dev/null); do
        local s=$(playerctl -p "$p" status 2>/dev/null)
        if [[ "$s" == "Playing" ]]; then
            return 0
        fi
    done
    return 1
}

get_bar() {
    local val=$1
    case $val in
        0) echo "▁" ;;
        1) echo "▂" ;;
        2) echo "▃" ;;
        3) echo "▄" ;;
        4) echo "▅" ;;
        5) echo "▆" ;;
        6) echo "▇" ;;
        7) echo "█" ;;
        *) echo "▁" ;;
    esac
}

# Safe echo that handles broken pipe
safe_echo() {
    echo "$1" 2>/dev/null || cleanup
}

# Clean up orphans from previous runs
cleanup_orphans

setup_config

# Main loop
while true; do
    if is_playing; then
        # Start cava with process substitution and read from fd 3
        while IFS=';' read -ra vals <&3; do
            if ! is_playing; then
                safe_echo '{"text": "", "class": "stopped"}'
                break
            fi

            output=""
            for i in 0 1 2 3 4 5 6 7 8 9 10 11; do
                v=${vals[$i]:-0}
                output+=$(get_bar $v)
            done

            safe_echo "{\"text\": \"$output\", \"class\": \"playing\"}"
        done 3< <(cava -p "$CAVA_CONFIG" 2>/dev/null)
    else
        safe_echo '{"text": "", "class": "stopped"}'
        sleep 0.5
    fi
done
