#!/bin/bash
# Waybar media visualizer - real audio visualization using cava
# Uses unique config per process to avoid conflicts

# Use PID to create unique config file
CAVA_CONFIG="/tmp/waybar_cava_config_$$"
CAVA_PID=""

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
    [[ -n "$CAVA_PID" ]] && kill "$CAVA_PID" 2>/dev/null
    # Kill cava processes using our specific config
    pkill -f "cava -p $CAVA_CONFIG" 2>/dev/null
    rm -f "$CAVA_CONFIG"
    exit 0
}

trap cleanup EXIT INT TERM

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

setup_config

# Main loop
while true; do
    if is_playing; then
        # Start cava in background and capture PID
        cava -p "$CAVA_CONFIG" 2>/dev/null | while IFS=';' read -ra vals; do
            if ! is_playing; then
                echo '{"text": "", "class": "stopped"}'
                pkill -f "cava -p $CAVA_CONFIG" 2>/dev/null
                break
            fi

            output=""
            for i in 0 1 2 3 4 5 6 7 8 9 10 11; do
                v=${vals[$i]:-0}
                output+=$(get_bar $v)
            done

            echo "{\"text\": \"$output\", \"class\": \"playing\"}"
        done

        # Ensure cava is killed after pipe breaks
        pkill -f "cava -p $CAVA_CONFIG" 2>/dev/null
    else
        echo '{"text": "", "class": "stopped"}'
        sleep 0.5
    fi
done
