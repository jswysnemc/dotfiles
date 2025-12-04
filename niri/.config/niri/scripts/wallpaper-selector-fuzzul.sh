#!/bin/bash

# ================= 配置区域 =================
WALLPAPER_DIRS=(
    "$HOME/Pictures/Wallpapers"
    "$HOME/Downloads/Wallpapers"
    "$HOME/Pictures/wallpapers/"
)
CACHE_DIR="$HOME/.cache/rofi-wallpaper-thumbs"
LINK_PATH="$HOME/.cache/current_wallpaper"

# Fuzzel 配置文件路径 (如果不需要特定配置，可留空或注释)
# FUZZEL_CONF="$HOME/.config/fuzzel/fuzzel.ini"
FUZZEL_CONF=""

EXTS="jpg|jpeg|png|gif|webp|mp4|mkv"
# ===========================================

mkdir -p "$CACHE_DIR"

# 全局数组
WALLPAPER_LIST=()
MISSING_THUMBS=()

# ---------------------------------------------------------
# 核心优化：后台生成缩略图守护进程
# ---------------------------------------------------------
generate_thumbs_background() {
    local missing_files=("${@}")

    if [[ ${#missing_files[@]} -eq 0 ]]; then return; fi

    for file in "${missing_files[@]}"; do
        # 1. 替换 / 为 _ (极速)
        local flat_path="${file//\//_}"
        flat_path="${flat_path#_}"

        # 2. 路径长度检查
        if [[ ${#flat_path} -gt 240 ]]; then
            local hash=$(echo -n "$file" | md5sum | cut -d" " -f1)
            local thumb="$CACHE_DIR/${hash}.jpg"
        else
            local thumb="$CACHE_DIR/${flat_path}.jpg"
        fi

        # 生成逻辑
        if [[ ! -s "$thumb" ]]; then
            if file --mime-type -b "$file" | grep -q "video"; then
                ffmpeg -y -i "$file" -ss 00:00:00 -vframes 1 -vf "scale=300:-1" -q:v 2 "$thumb" > /dev/null 2>&1
            else
                magick "$file" -thumbnail 300x300^ -gravity center -extent 300x300 "$thumb" > /dev/null 2>&1
            fi
        fi
    done
}

# ---------------------------------------------------------
# 主逻辑
# ---------------------------------------------------------

# 临时文件
MENU_INPUT_CACHE=$(mktemp)

# 1. 快速查找所有文件
all_files=$(find "${WALLPAPER_DIRS[@]}" -type f 2>/dev/null | grep -E "\.(${EXTS})$" | sort)

# 2. 极速构建列表
while IFS= read -r file; do
    if [[ -z "$file" ]]; then continue; fi

    # 加入索引数组
    WALLPAPER_LIST+=("$file")

    filename="${file##*/}"

    # 计算缩略图路径
    flat_path="${file//\//_}"
    flat_path="${flat_path#_}"

    if [[ ${#flat_path} -gt 240 ]]; then
        hash=$(echo -n "$file" | md5sum | cut -d" " -f1)
        thumb="$CACHE_DIR/${hash}.jpg"
    else
        thumb="$CACHE_DIR/${flat_path}.jpg"
    fi

    # Fuzzel 兼容 Rofi 的图标语法: Text\0icon\x1fPath
    if [[ -f "$thumb" ]]; then
        echo -en "${filename}\0icon\x1f${thumb}\n" >> "$MENU_INPUT_CACHE"
    else
        MISSING_THUMBS+=("$file")
        echo -en "${filename}\n" >> "$MENU_INPUT_CACHE"
    fi

done <<< "$all_files"

# 3. 后台生成缺失缩略图
if [[ ${#MISSING_THUMBS[@]} -gt 0 ]]; then
    (generate_thumbs_background "${MISSING_THUMBS[@]}" &) > /dev/null 2>&1
fi

# 4. 启动 Fuzzel
# 构造参数
FUZZEL_ARGS=(--dmenu --index -p "🖼️ Wallpapers: ")
if [[ -n "$FUZZEL_CONF" ]]; then
    FUZZEL_ARGS+=(--config "$FUZZEL_CONF")
fi

# 注意：Fuzzel 默认支持从 stdin 读取 \0icon\x1f 格式
SELECTED_INDEX=$(cat "$MENU_INPUT_CACHE" | fuzzel "${FUZZEL_ARGS[@]}")

# 清理
rm -f "$MENU_INPUT_CACHE"

# 5. 处理选择结果
if [[ -n "$SELECTED_INDEX" ]]; then
    # 确保返回的是数字索引
    if ! [[ "$SELECTED_INDEX" =~ ^[0-9]+$ ]]; then exit 1; fi

    SELECTED="${WALLPAPER_LIST[$SELECTED_INDEX]}"

    if [[ ! -f "$SELECTED" ]]; then exit 1; fi

    # 设置壁纸
    EXT="${SELECTED##*.}"
    rm -f "$LINK_PATH" "$LINK_PATH"*
    ln -sf "$SELECTED" "${LINK_PATH}.${EXT}"
    ln -sf "$SELECTED" "${LINK_PATH}"

    if ! pgrep -x "swww-daemon" > /dev/null; then
        swww init; sleep 0.5
    fi

    swww img "$SELECTED" --transition-type grow --transition-pos 0.5,0.5 --transition-step 90 --transition-fps 60

    # 如果你使用了 matugen，取消下面的注释
    if command -v matugen &> /dev/null; then
        matugen image ~/.cache/current_wallpaper
    fi

    # 获取图标用于通知
    flat_path="${SELECTED//\//_}"
    flat_path="${flat_path#_}"
    if [[ ${#flat_path} -gt 240 ]]; then
        hash=$(echo -n "$SELECTED" | md5sum | cut -d" " -f1)
        thumb="$CACHE_DIR/${hash}.jpg"
    else
        thumb="$CACHE_DIR/${flat_path}.jpg"
    fi

    if [[ -f "$thumb" ]]; then
        notify-send "Wallpaper Changed" "$(basename "$SELECTED")" -i "$thumb"
    else
        notify-send "Wallpaper Changed" "$(basename "$SELECTED")"
    fi
fi
