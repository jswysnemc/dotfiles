#!/bin/bash

set -u

# 启动 awww 守护进程 (如果还没运行)
if ! pgrep -x "awww-daemon" > /dev/null; then
    awww-daemon >/dev/null 2>&1 &
fi

# 等待一下确保 daemon 启动完毕
sleep 0.5

DEFAULT_WALLPAPER="$HOME/.cache/current_wallpaper"

get_outputs() {
    awww query 2>/dev/null | awk -F': ' '/^: / && NF >= 3 { print $2 }'
}

set_wallpaper() {
    local output="$1"
    local wallpaper="$2"

    if [[ ! -e "$wallpaper" ]]; then
        wallpaper="$DEFAULT_WALLPAPER"
    fi

    if [[ ! -e "$wallpaper" ]]; then
        return
    fi

    awww img "$wallpaper" \
        --outputs "$output" \
        --transition-type grow \
        --transition-pos 0.854,0.977 \
        --transition-step 90 \
        --transition-fps 60
}

outputs=()
for _ in {1..10}; do
    mapfile -t outputs < <(get_outputs)
    if [[ ${#outputs[@]} -gt 0 ]]; then
        break
    fi
    sleep 0.2
done

for output in "${outputs[@]}"; do
    set_wallpaper "$output" "$HOME/.cache/current_wallpaper_${output}"
done
