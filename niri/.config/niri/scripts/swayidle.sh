#!/usr/bin/env bash

# ============================================================================
# Swayidle 配置 - 带预警的锁屏
# ============================================================================
# 时间线：
#   45秒  -> 显示预警 UI (30秒倒计时)
#   75秒  -> 如果没取消，真正锁屏
#   120秒 -> 关闭显示器
# ============================================================================

# 配置时间 (秒) - 正式使用
# WARN_TIMEOUT=45      # 多久后显示预警
# WARN_DURATION=30     # 预警倒计时时长
# LOCK_TIMEOUT=75      # 多久后真正锁屏 (应该 = WARN_TIMEOUT + WARN_DURATION)
# DPMS_TIMEOUT=120     # 多久后关闭显示器

# 测试用短时间
WARN_TIMEOUT=5       # 5秒后显示预警
WARN_DURATION=5      # 预警倒计时5秒
LOCK_TIMEOUT=10      # 10秒后真正锁屏
DPMS_TIMEOUT=20      # 20秒后关闭显示器

# 命令定义
# 使用 QuickShell 锁屏 (ext-session-lock-v1 协议)
# 注意：使用 pgrep -x 精确匹配进程名，避免匹配到路径中包含 quickshell 的其他进程
LOCK_CMD="pgrep -x quickshell -a | grep -q 'lockscreen' || qs-lock"
WARN_CMD="pgrep -x quickshell -a | grep -q 'idle-warning' || IDLE_WARN_TIMEOUT=$WARN_DURATION quickshell -p ~/.config/quickshell/idle-warning"
WARN_KILL="pkill -f 'quickshell -p.*idle-warning' 2>/dev/null; true"

# 启动 swayidle
# 注意：使用 ext-session-lock-v1 协议后，不需要 resume 时触发认证
# 锁屏界面会一直显示直到用户主动认证成功
swayidle -w \
    timeout $WARN_TIMEOUT  "$WARN_CMD" \
        resume             "$WARN_KILL" \
    timeout $LOCK_TIMEOUT  "$LOCK_CMD" \
    timeout $DPMS_TIMEOUT  'niri msg action power-off-monitors' \
        resume             'niri msg action power-on-monitors' \
    lock                   "$LOCK_CMD"
    # timeout 300  'systemctl suspend'
    # before-sleep 'loginctl lock-session'
