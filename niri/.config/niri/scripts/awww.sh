#!/bin/bash

set -u

# 启动 awww 守护进程 (如果还没运行)
if ! pgrep -x "awww-daemon" > /dev/null; then
    awww-daemon >/dev/null 2>&1 &
fi

# 等待一下确保 daemon 启动完毕
sleep 0.5

DEFAULT_WALLPAPER="$HOME/.cache/current_wallpaper"

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

if awww query | grep -q ": eDP-1:"; then
    set_wallpaper "eDP-1" "$HOME/.cache/current_wallpaper_eDP-1"
fi

if awww query | grep -q ": HDMI-A-1:"; then
    set_wallpaper "HDMI-A-1" "$HOME/.cache/current_wallpaper_HDMI-A-1"
fi
