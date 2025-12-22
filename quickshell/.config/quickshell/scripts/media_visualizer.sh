#!/bin/bash
# 音律条动画 - cava 实时音频

bar="▁▂▃▄▅▆▇█"
dict="s/;//g;"

# 创建 sed 替换字典
i=0
while [ $i -lt ${#bar} ]; do
    dict="${dict}s/$i/${bar:$i:1}/g;"
    i=$((i + 1))
done

# 使用 cava 配置文件
config="$HOME/.config/cava/waybar_cava.conf"

# 读取 cava 输出，使用 sed -u 避免缓冲
cava -p "$config" 2>/dev/null | while read -r line; do
    status=$(playerctl status 2>/dev/null)
    if [ "$status" = "Playing" ]; then
        output=$(echo "$line" | sed -u "$dict")
        echo "{\"text\": \"$output\", \"class\": \"playing\"}"
    else
        echo '{"text": "", "class": "hidden"}'
    fi
done
