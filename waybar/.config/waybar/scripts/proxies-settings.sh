#!/bin/bash

# 配置部分
API_URL="http://127.0.0.1:9090"
SECRET="123456" # 如果 config.yaml 里设置了 secret，请填在这里，例如 "123456"

# 构建 Header
if [ -n "$SECRET" ]; then
    HEADER="Authorization: Bearer $SECRET"
else
    HEADER=""
fi

# 获取当前模式函数
get_mode() {
    curl -s -H "$HEADER" "${API_URL}/configs" | jq -r '.mode'
}

# 切换模式逻辑
if [ "$1" == "toggle" ]; then
    CURRENT_MODE=$(get_mode)

    # 切换逻辑: Rule -> Global -> Direct -> Rule
    case "$CURRENT_MODE" in
        "rule") NEW_MODE="global" ;;
        "global") NEW_MODE="direct" ;;
        "direct") NEW_MODE="rule" ;;
        *) NEW_MODE="rule" ;;
    esac

    # 发送 PATCH 请求修改模式
    curl -s -X PATCH -H "$HEADER" -d "{\"mode\": \"$NEW_MODE\"}" "${API_URL}/configs" > /dev/null

    # 发送信号更新 Waybar (信号值 8，可自定义)
    pkill -RTMIN+8 waybar
    exit 0
fi

# --- 下面是 Waybar 显示逻辑 ---

MODE=$(get_mode)

# 定义图标和文字
if [ "$MODE" == "rule" ]; then
    TEXT=" Rule"
    CLASS="rule"
    TOOLTIP="规则模式：智能分流"
elif [ "$MODE" == "global" ]; then
    TEXT="✈ Global"
    CLASS="global"
    TOOLTIP="全局代理：所有流量走节点"
elif [ "$MODE" == "direct" ]; then
    TEXT=" Direct"
    CLASS="direct"
    TOOLTIP="直连模式：不走代理"
else
    TEXT="Disconnected"
    CLASS="disconnected"
    TOOLTIP="无法连接到 Mihomo"
fi

# 输出 JSON 给 Waybar
echo "{\"text\": \"$TEXT\", \"class\": \"$CLASS\", \"tooltip\": \"$TOOLTIP\"}"
