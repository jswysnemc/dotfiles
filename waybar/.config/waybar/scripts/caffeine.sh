#!/usr/bin/env bash

# ============================================================================
# Caffeine 模块 - 可靠的屏幕常亮控制
# ============================================================================
# 使用 systemd-inhibit 来阻止空闲休眠，状态持久化到文件
# 解决 waybar 内置 idle_inhibitor 重启后丢失状态的问题
# ============================================================================

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/caffeine-state"
PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/caffeine-inhibitor.pid"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/caffeine.lock"

# 图标定义 (Nerd Font)
ICON_ACTIVATED="󰅶"   # 咖啡杯满 - 常亮模式
ICON_DEACTIVATED="󰾪" # 咖啡杯空 - 省电模式

# 获取当前状态
get_state() {
    if [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE" 2>/dev/null)" == "on" ]]; then
        echo "on"
    else
        echo "off"
    fi
}

# 检查 inhibitor 进程是否存活
is_inhibitor_running() {
    [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null
}

# 启动 inhibitor
start_inhibitor() {
    # 已经在运行就不重复启动
    if is_inhibitor_running; then
        return 0
    fi
    
    # 使用 systemd-inhibit 阻止 idle 和 sleep
    # 这个进程会一直运行直到被 kill
    (
        systemd-inhibit --what=idle:sleep \
            --who="Caffeine" \
            --why="用户请求保持屏幕常亮" \
            --mode=block \
            sleep infinity &
        echo $! > "$PID_FILE"
        wait
    ) &
    
    # 等待进程启动
    sleep 0.2
}

# 停止 inhibitor
stop_inhibitor() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ -n "$pid" ]]; then
            # 杀死 sleep infinity 进程及其父进程 systemd-inhibit
            pkill -P "$pid" 2>/dev/null
            kill "$pid" 2>/dev/null
        fi
        rm -f "$PID_FILE"
    fi
    
    # 额外清理：确保没有残留的 caffeine inhibitor
    pkill -f "systemd-inhibit.*Caffeine" 2>/dev/null || true
}

# 切换状态
toggle() {
    if [[ "$(get_state)" == "on" ]]; then
        stop_inhibitor
        echo "off" > "$STATE_FILE"
    else
        echo "on" > "$STATE_FILE"
        start_inhibitor
    fi
    
    # 输出新状态供 waybar 更新
    output
}

# 确保状态与进程同步 (用于启动时恢复)
sync_state() {
    local state=$(get_state)
    
    if [[ "$state" == "on" ]]; then
        if ! is_inhibitor_running; then
            start_inhibitor
        fi
    else
        stop_inhibitor
    fi
}

# 输出 JSON 供 waybar 使用
output() {
    local state=$(get_state)
    local icon text tooltip class
    
    if [[ "$state" == "on" ]]; then
        icon="$ICON_ACTIVATED"
        text="$icon"
        tooltip="咖啡模式：屏幕常亮\n点击关闭"
        class="activated"
    else
        icon="$ICON_DEACTIVATED"
        text="$icon"
        tooltip="省电模式：自动息屏\n点击开启咖啡模式"
        class="deactivated"
    fi
    
    # 输出 waybar JSON 格式
    printf '{"text": "%s", "tooltip": "%s", "class": "%s"}\n' "$text" "$tooltip" "$class"
}

# 主逻辑
case "${1:-status}" in
    toggle)
        toggle
        ;;
    on)
        echo "on" > "$STATE_FILE"
        start_inhibitor
        output
        ;;
    off)
        stop_inhibitor
        echo "off" > "$STATE_FILE"
        output
        ;;
    status|waybar)
        # 每次查询状态时同步一下，确保进程存活
        sync_state
        output
        ;;
    is-active)
        # 返回退出码：0=激活, 1=未激活
        [[ "$(get_state)" == "on" ]]
        ;;
    *)
        echo "Usage: $0 {toggle|on|off|status|waybar|is-active}"
        exit 1
        ;;
esac
