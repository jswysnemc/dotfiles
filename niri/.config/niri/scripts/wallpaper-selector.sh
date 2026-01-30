#!/bin/bash

# ================= 配置区域 =================
WALLPAPER_DIRS=(
    "$HOME/Pictures/Wallpapers"
    "$HOME/Downloads/Wallpapers"
    "$HOME/Pictures/wallpapers/"
)
CACHE_DIR="$HOME/.cache/rofi-wallpaper-thumbs"
LINK_PATH="$HOME/.cache/current_wallpaper"
ROFI_THEME="$HOME/.config/rofi/wallpaper.rasi"
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
        local flat_path="${file//\//_}"
        flat_path="${flat_path#_}"

        if [[ ${#flat_path} -gt 240 ]]; then
            local hash=$(echo -n "$file" | md5sum | cut -d" " -f1)
            local thumb="$CACHE_DIR/${hash}.jpg"
        else
            local thumb="$CACHE_DIR/${flat_path}.jpg"
        fi

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

ROFI_INPUT_CACHE=$(mktemp)

# 1. 快速查找所有文件
all_files=$(find "${WALLPAPER_DIRS[@]}" -type f 2>/dev/null | grep -E "\.(${EXTS})$" | sort)

# 2. 极速构建列表
while IFS= read -r file; do
    if [[ -z "$file" ]]; then continue; fi

    WALLPAPER_LIST+=("$file")
    filename="${file##*/}"

    flat_path="${file//\//_}"
    flat_path="${flat_path#_}"

    if [[ ${#flat_path} -gt 240 ]]; then
        hash=$(echo -n "$file" | md5sum | cut -d" " -f1)
        thumb="$CACHE_DIR/${hash}.jpg"
    else
        thumb="$CACHE_DIR/${flat_path}.jpg"
    fi

    if [[ -f "$thumb" ]]; then
        echo -en "${filename}\0icon\x1f${thumb}\n" >> "$ROFI_INPUT_CACHE"
    else
        MISSING_THUMBS+=("$file")
        echo -en "${filename}\n" >> "$ROFI_INPUT_CACHE"
    fi

done <<< "$all_files"

# 3. 后台生成缺失缩略图
if [[ ${#MISSING_THUMBS[@]} -gt 0 ]]; then
    (generate_thumbs_background "${MISSING_THUMBS[@]}" &) > /dev/null 2>&1
fi

# 4. 启动 Rofi
SELECTED_INDEX=$(cat "$ROFI_INPUT_CACHE" | rofi -dmenu -i -show-icons -p "Wallpapers" -theme "${ROFI_THEME}" -format i)

rm -f "$ROFI_INPUT_CACHE"

# 5. 处理选择结果
if [[ -n "$SELECTED_INDEX" ]]; then
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

    # 使用 theme-gen 生成主题
    if command -v theme-gen &> /dev/null; then
        theme-gen
    else
        matugen image ~/.cache/current_wallpaper
    fi

    # 通知
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
