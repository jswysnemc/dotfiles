#!/usr/bin/env bash

# ============================================================================
# Swayidle 配置 - 带预警的锁屏
# ============================================================================
# 时间线：
#   WARN_TIMEOUT  -> 显示预警 UI
#   LOCK_TIMEOUT  -> 真正锁屏
#   DPMS_TIMEOUT  -> 关闭显示器
# ============================================================================

# 配置时间 (秒) - 正式使用
# WARN_TIMEOUT=45      # 多久后显示预警
# WARN_DURATION=30     # 预警倒计时时长
# LOCK_TIMEOUT=75      # 多久后真正锁屏
# DPMS_TIMEOUT=120     # 多久后关闭显示器

# 测试用短时间
WARN_TIMEOUT=5
WARN_DURATION=5
LOCK_TIMEOUT=10
DPMS_TIMEOUT=20

# 命令 - 使用内联方式，避免函数导出问题
# 注意：WARN_KILL 不能用 pkill -f，因为会匹配到 swayidle 自己的命令行参数
WARN_CMD="pgrep -x quickshell -a | grep -q 'idle-warning' || IDLE_WARN_TIMEOUT=${WARN_DURATION} quickshell -p ~/.config/quickshell/idle-warning &"
WARN_KILL="pgrep -x quickshell -a | grep 'idle-warning' | awk '{print \$1}' | xargs -r kill 2>/dev/null; true"
LOCK_CMD="pgrep -x quickshell -a | grep -q 'lockscreen' || qs-lock"

# 关键：移除 -w 选项
# -w 会让 swayidle 等待命令完成，但我们的 warning 是后台运行的
# 这会导致 swayidle 认为命令还在执行，不会触发后续的 timeout

exec swayidle \
    timeout $WARN_TIMEOUT  "$WARN_CMD" \
        resume             "$WARN_KILL" \
    timeout $LOCK_TIMEOUT  "$LOCK_CMD" \
    timeout $DPMS_TIMEOUT  'niri msg action power-off-monitors' \
        resume             'niri msg action power-on-monitors' \
    lock                   "$LOCK_CMD"
