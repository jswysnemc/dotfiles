#!/usr/bin/env bash
# 输出 Waybar 计时器状态。

set -u

cd "$HOME/.config/quickshell" 2>/dev/null || {
    printf '{"text":"","tooltip":"","class":"inactive"}\n'
    exit 0
}

python3 calendar/timer_state.py waybar 2>/dev/null || {
    printf '{"text":"","tooltip":"","class":"inactive"}\n'
}
