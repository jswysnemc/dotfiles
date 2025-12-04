#!/bin/bash

# 检查是否安装了 fuzzel
if ! command -v fuzzel &> /dev/null; then
    notify-send "错误" "未找到 fuzzel，请先安装。"
    exit 1
fi

# --- 修复核心：正确提取接口名称 ---
# niri msg outputs 的典型输出行: Output "eDP-1" (BOE 0x0C8E Unknown)
# 我们需要提取引号 "" 中间的内容
get_outputs() {
    niri msg outputs | grep "^Output" | awk -F '"' '{print $2}'
}

# 获取指定输出设备支持的模式 (Modes)
get_modes() {
    local output_name="$1"
    niri msg outputs | \
    awk -v name="$output_name" '
        # 匹配 Output "eDP-1" 这样的行
        $0 ~ "Output \"" name "\"" { flag=1; next }
        # 遇到下一个 Output 行时停止
        $0 ~ "^Output " { flag=0 }
        # 开启模式抓取
        flag && /Available modes:/ { modes_flag=1; next }
        # 抓取模式行 (例如 1920x1080@60.000)
        flag && modes_flag && /^[ \t]*[0-9]+x[0-9]+/ {
            gsub(/^[ \t]+/, "", $0);
            print $1
        }
    '
}

# --- 第 1 步：选择显示器 ---
# 使用 fuzzel 选择显示器
# --lines 0 自动调整高度
# --width 调整宽度以适应内容
selected_output=$(get_outputs | fuzzel --dmenu --prompt "  选择显示器 > " --lines 5 --width 40)

# 如果用户取消或未选择，退出
if [ -z "$selected_output" ]; then
    exit 0
fi

# --- 第 2 步：选择分辨率和刷新率 ---
# 获取该显示器的模式列表
modes_list=$(get_modes "$selected_output")

# 如果没有找到模式，尝试调试或提示
if [ -z "$modes_list" ]; then
    # 备用方案：如果还没找到，可能是 grep 逻辑漏掉了，提示用户
    notify-send "Niri Display" "无法获取 $selected_output 的模式列表。\n请检查 niri msg outputs 输出格式。"
    exit 1
fi

# 在 Fuzzel 中显示模式列表
selected_mode=$(echo "$modes_list" | fuzzel --dmenu --prompt "  分辨率/刷新率 > " --lines 10 --width 40)

# 如果用户取消，退出
if [ -z "$selected_mode" ]; then
    exit 0
fi

# --- 第 3 步：应用更改 ---
# 提取纯净的模式字符串
clean_mode=$(echo "$selected_mode" | awk '{print $1}')

# 执行 niri 命令
if niri msg output "$selected_output" mode "$clean_mode"; then
    notify-send "Niri Display" "成功设置 $selected_output 为 $clean_mode"
else
    notify-send -u critical "Niri Display" "设置失败！\n请检查该模式是否受支持。"
fi