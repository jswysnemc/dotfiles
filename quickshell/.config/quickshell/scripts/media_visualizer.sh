#!/bin/bash
# Waybar media visualizer - optimized cava integration
# Uses pactl subscribe for event-driven detection (zero CPU when idle)

# Configuration
CHARS="▁▂▃▄▅▆▇█"
BARS=12
CAVA_CONFIG="/tmp/waybar_cava_config_$$"

# Derived values
CHAR_MAX=$((${#CHARS} - 1))
IDLE_CHAR="${CHARS:0:1}"
IDLE_OUTPUT=$(printf "%0.s$IDLE_CHAR" $(seq 1 $BARS))

# Generate cava config
setup_config() {
    cat > "$CAVA_CONFIG" <<EOF
[general]
bars = $BARS
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
ascii_max_range = $CHAR_MAX
EOF
}

cleanup() {
    trap - EXIT INT TERM HUP QUIT PIPE
    pkill -P $$ 2>/dev/null
    echo '{"text": "", "class": "stopped"}'
    rm -f "$CAVA_CONFIG"
    exit 0
}

trap cleanup EXIT INT TERM HUP QUIT PIPE

# Check for active (non-paused) audio streams via PulseAudio
is_audio_active() {
    pactl list sink-inputs 2>/dev/null | grep -q "Corked: no"
}

# Safe output for waybar JSON
safe_echo() {
    echo "$1" 2>/dev/null || cleanup
}

# Build sed substitution for numeric to bar character mapping
build_sed_dict() {
    local dict="s/;//g;"
    for ((i = 0; i <= CHAR_MAX; i++)); do
        dict="${dict}s/$i/${CHARS:$i:1}/g;"
    done
    echo "$dict"
}

setup_config
SED_DICT=$(build_sed_dict)

# Initial state
safe_echo '{"text": "", "class": "stopped"}'

while true; do
    if is_audio_active; then
        # Start cava if not already running
        if ! pgrep -P $$ -x cava >/dev/null; then
            cava -p "$CAVA_CONFIG" 2>/dev/null | sed -u "$SED_DICT" | while IFS= read -r line; do
                safe_echo "{\"text\": \"$line\", \"class\": \"playing\"}"
            done &
        fi
        # Reduce check frequency while playing
        sleep 1
    else
        # Stop cava if running
        if pgrep -P $$ -x cava >/dev/null; then
            pkill -P $$ -x cava 2>/dev/null
            wait 2>/dev/null
            safe_echo '{"text": "", "class": "stopped"}'
        fi
        # Wait for audio events passively (no CPU usage)
        timeout 5s pactl subscribe 2>/dev/null | grep --line-buffered "sink-input" | head -n 1 >/dev/null
    fi
done
