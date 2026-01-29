#!/usr/bin/env bash

# ============================================================================
# Swayidle 配置 - 统一锁屏
# ============================================================================
# 时间线：
#   IDLE_TIMEOUT    -> 启动锁屏（带 grace period）
#   DPMS_TIMEOUT    -> 关闭显示器
#   SUSPEND_TIMEOUT -> 休眠
# ============================================================================
# 锁屏组件内部处理：
#   - Grace Period: 用户可以通过移动鼠标/按键取消锁屏
#   - Locked Phase: 需要密码或 PAM 认证才能解锁
# ============================================================================

# 配置时间 (秒) - 正式使用
IDLE_TIMEOUT=45       # 多久后启动锁屏
GRACE_DURATION=30     # Grace period 时长（在锁屏组件内部）
DPMS_TIMEOUT=120      # 多久后关闭显示器
SUSPEND_TIMEOUT=300   # 多久后休眠 (10分钟)

# 测试用短时间
# IDLE_TIMEOUT=5
# GRACE_DURATION=5
# DPMS_TIMEOUT=15
# SUSPEND_TIMEOUT=30

# 锁屏命令 - 使用环境变量传递 grace period 时长
LOCK_CMD="pgrep -x quickshell -a | grep -q 'lockscreen' || LOCK_GRACE_TIMEOUT=${GRACE_DURATION} qs-lock"

exec swayidle \
    timeout $IDLE_TIMEOUT    "$LOCK_CMD" \
    timeout $DPMS_TIMEOUT    'niri msg action power-off-monitors' \
        resume               'niri msg action power-on-monitors' \
    timeout $SUSPEND_TIMEOUT 'systemctl suspend' \
    lock                     "$LOCK_CMD"
