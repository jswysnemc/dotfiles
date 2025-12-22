#!/bin/bash
# 媒体状态输出给 waybar - 使用 waybar 原生滚动

while true; do
    players=$(playerctl --list-all 2>/dev/null)
    
    if [ -z "$players" ]; then
        echo '{"text": "", "class": "empty"}'
    else
        status=$(playerctl status 2>/dev/null || echo "Stopped")
        title=$(playerctl metadata title 2>/dev/null)
        
        # 过滤常见后缀
        title=$(echo "$title" | sed -E 's/ - 哔哩哔哩.*//; s/_哔哩哔哩.*//; s/ - bilibili.*//i; s/ - YouTube.*//i')
        
        # 选择图标和状态
        if [ "$status" = "Playing" ]; then
            icon="󰐊"
            class="playing"
        elif [ "$status" = "Paused" ]; then
            icon="󰏤"
            class="paused"
        else
            icon="󰓛"
            class="stopped"
        fi
        
        # 构建输出
        [ -z "$title" ] && title="媒体"
        display=$(echo "$icon $title" | sed 's/"/\\"/g')
        tooltip=$(echo "$title" | sed 's/"/\\"/g')
        
        echo "{\"text\": \"$display\", \"tooltip\": \"$tooltip\", \"class\": \"$class\"}"
    fi
    
    sleep 1
done
