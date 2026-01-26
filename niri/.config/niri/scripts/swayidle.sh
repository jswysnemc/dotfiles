#!/usr/bin/env bash

# 1. 锁屏命令 (保持不变)
lock_cmd="pidof hyprlock || (hyprlock &)"

# 2. 定义触发认证的命令 (新增)
#    逻辑：唤醒后等待 0.5 秒(给屏幕点亮和焦点切换的时间)，然后模拟按下回车
auth_trigger="sleep 0.5 && wtype -k Return"

# 3. 启动 swayidle
#    注意查看下方 resume 的变化
swayidle -w \
    timeout 60   "$lock_cmd" \
        resume       "$auth_trigger" \
    timeout 120 'niri msg action power-off-monitors' \
        resume       'niri msg action power-on-monitors; '"$auth_trigger" \
    lock         "$lock_cmd"
    # timeout 300  'systemctl suspend'
    # before-sleep 'loginctl lock-session'
