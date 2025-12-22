#!/bin/bash

# ============================================================
# Proxies Control Script - 支持 Mihomo / Sing-box 双内核
# ============================================================

# 配置
API_URL="http://127.0.0.1:9090"
SECRET="123456"
STATE_FILE="/tmp/proxy-kernel-state"

# 默认内核
DEFAULT_KERNEL="sing-box"

# NerdFont 图标 + 简短文字
ICON_MIHOMO="󰓾 Mi"
ICON_SINGBOX="󰒍 Sb"
ICON_RULE="󰀻 规则"
ICON_GLOBAL="󰕒 全局"
ICON_DIRECT="󰅏 直连"
ICON_STOPPED="󰅙 停止"
ICON_SWITCH="󰓡"
ICON_POWER_ON="󰐥"
ICON_POWER_OFF="󰅙"

# 构建 Header
if [ -n "$SECRET" ]; then
    HEADER="Authorization: Bearer $SECRET"
else
    HEADER=""
fi

# 获取当前活动的内核
get_active_kernel() {
    if systemctl is-active --quiet mihomo-kernel.service; then
        echo "mihomo"
    elif systemctl is-active --quiet sing-box-kernel.service; then
        echo "sing-box"
    else
        echo "none"
    fi
}

# 获取当前模式
get_mode() {
    local mode
    mode=$(curl -s --connect-timeout 2 -H "$HEADER" "${API_URL}/configs" 2>/dev/null | jq -r '.mode // empty')
    if [ -z "$mode" ]; then
        echo "disconnected"
    else
        echo "$mode"
    fi
}

# 设置模式
set_mode() {
    local new_mode="$1"
    curl -s -X PATCH -H "$HEADER" -H "Content-Type: application/json" \
        -d "{\"mode\": \"$new_mode\"}" "${API_URL}/configs" > /dev/null 2>&1
}

# 刷新 Waybar
refresh_waybar() {
    pkill -RTMIN+8 waybar
}

# 处理命令
case "$1" in
    "status")
        # 主状态显示模块 - 显示内核 + 模式
        KERNEL=$(get_active_kernel)
        MODE=$(get_mode)
        
        if [ "$KERNEL" == "none" ]; then
            TEXT="󰅙 离线"
            CLASS="stopped"
            TOOLTIP="代理内核未运行"
        elif [ "$MODE" == "disconnected" ]; then
            if [ "$KERNEL" == "mihomo" ]; then
                TEXT="Mi 󰅙"
            else
                TEXT="Sb 󰅙"
            fi
            CLASS="disconnected"
            TOOLTIP="$KERNEL 运行中，但 API 无响应"
        else
            # 内核简称
            if [ "$KERNEL" == "mihomo" ]; then
                KERNEL_TEXT="Mi"
            else
                KERNEL_TEXT="Sb"
            fi
            
            # 根据模式选择显示 (支持大小写)
            MODE_LOWER=$(echo "$MODE" | tr '[:upper:]' '[:lower:]')
            case "$MODE_LOWER" in
                "rule")
                    MODE_ICON="󰀻"
                    MODE_TEXT="规则"
                    ;;
                "global")
                    MODE_ICON="󰕒"
                    MODE_TEXT="全局"
                    ;;
                "direct")
                    MODE_ICON="󰅏"
                    MODE_TEXT="直连"
                    ;;
                *)
                    MODE_ICON="?"
                    MODE_TEXT="未知"
                    ;;
            esac
            
            TEXT="$KERNEL_TEXT $MODE_ICON $MODE_TEXT"
            CLASS="$MODE_LOWER"
            TOOLTIP="内核: $KERNEL | 模式: $MODE_TEXT | 左键切换 | 右键面板"
        fi
        
        echo "{\"text\": \"$TEXT\", \"class\": \"$CLASS\", \"tooltip\": \"$TOOLTIP\"}"
        ;;
        
    "kernel-status")
        # 内核切换按钮状态
        KERNEL=$(get_active_kernel)
        if [ "$KERNEL" == "mihomo" ]; then
            TEXT="$ICON_MIHOMO"
            TOOLTIP="当前: Mihomo (点击切换到 Sing-box)"
            CLASS="mihomo"
        elif [ "$KERNEL" == "sing-box" ]; then
            TEXT="$ICON_SINGBOX"
            TOOLTIP="当前: Sing-box (点击切换到 Mihomo)"
            CLASS="singbox"
        else
            TEXT="󰓡 切换"
            TOOLTIP="内核未运行 (点击启动 $DEFAULT_KERNEL)"
            CLASS="stopped"
        fi
        echo "{\"text\": \"$TEXT\", \"class\": \"$CLASS\", \"tooltip\": \"$TOOLTIP\"}"
        ;;
        
    "switch-kernel")
        # 切换内核
        KERNEL=$(get_active_kernel)
        if [ "$KERNEL" == "mihomo" ]; then
            systemctl --user stop mihomo-kernel.service 2>/dev/null || sudo systemctl stop mihomo-kernel.service
            sleep 0.5
            systemctl --user start sing-box-kernel.service 2>/dev/null || sudo systemctl start sing-box-kernel.service
        else
            systemctl --user stop sing-box-kernel.service 2>/dev/null || sudo systemctl stop sing-box-kernel.service
            sleep 0.5
            systemctl --user start mihomo-kernel.service 2>/dev/null || sudo systemctl start mihomo-kernel.service
        fi
        sleep 1
        refresh_waybar
        ;;
        
    "power-status")
        # 电源按钮状态
        KERNEL=$(get_active_kernel)
        if [ "$KERNEL" == "none" ]; then
            TEXT="$ICON_POWER_OFF 启动"
            TOOLTIP="代理已停止 (点击启动)"
            CLASS="stopped"
        else
            TEXT="$ICON_POWER_ON 停止"
            TOOLTIP="代理运行中 (点击停止)"
            CLASS="running"
        fi
        echo "{\"text\": \"$TEXT\", \"class\": \"$CLASS\", \"tooltip\": \"$TOOLTIP\"}"
        ;;
        
    "toggle-power")
        # 开关内核
        KERNEL=$(get_active_kernel)
        if [ "$KERNEL" == "none" ]; then
            # 启动默认内核
            if [ "$DEFAULT_KERNEL" == "sing-box" ]; then
                systemctl --user start sing-box-kernel.service 2>/dev/null || sudo systemctl start sing-box-kernel.service
            else
                systemctl --user start mihomo-kernel.service 2>/dev/null || sudo systemctl start mihomo-kernel.service
            fi
        else
            # 停止当前内核
            if [ "$KERNEL" == "mihomo" ]; then
                systemctl --user stop mihomo-kernel.service 2>/dev/null || sudo systemctl stop mihomo-kernel.service
            else
                systemctl --user stop sing-box-kernel.service 2>/dev/null || sudo systemctl stop sing-box-kernel.service
            fi
        fi
        sleep 1
        refresh_waybar
        ;;
        
    "mode-rule-status")
        MODE=$(get_mode)
        if [ "$MODE" == "rule" ]; then
            CLASS="active"
        else
            CLASS="inactive"
        fi
        echo "{\"text\": \"$ICON_RULE\", \"class\": \"$CLASS\", \"tooltip\": \"规则模式：智能分流\"}"
        ;;
        
    "mode-global-status")
        MODE=$(get_mode)
        if [ "$MODE" == "global" ]; then
            CLASS="active"
        else
            CLASS="inactive"
        fi
        echo "{\"text\": \"$ICON_GLOBAL\", \"class\": \"$CLASS\", \"tooltip\": \"全局模式：所有流量走代理\"}"
        ;;
        
    "mode-direct-status")
        MODE=$(get_mode)
        if [ "$MODE" == "direct" ]; then
            CLASS="active"
        else
            CLASS="inactive"
        fi
        echo "{\"text\": \"$ICON_DIRECT\", \"class\": \"$CLASS\", \"tooltip\": \"直连模式：不走代理\"}"
        ;;
        
    "set-rule")
        set_mode "rule"
        refresh_waybar
        ;;
        
    "set-global")
        set_mode "global"
        refresh_waybar
        ;;
        
    "set-direct")
        set_mode "direct"
        refresh_waybar
        ;;
        
    "toggle-mode")
        # 循环切换模式: rule -> global -> direct -> rule
        MODE=$(get_mode)
        case "$MODE" in
            "rule") NEW_MODE="global" ;;
            "global") NEW_MODE="direct" ;;
            "direct") NEW_MODE="rule" ;;
            *) NEW_MODE="rule" ;;
        esac
        set_mode "$NEW_MODE"
        refresh_waybar
        ;;
        
    *)
        # 默认：输出主状态
        exec "$0" status
        ;;
esac
