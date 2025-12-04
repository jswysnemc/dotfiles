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

    # 如果没有缺失，直接退出
    if [[ ${#missing_files[@]} -eq 0 ]]; then return; fi

    # 通知用户（可选，以免用户以为坏了）
    # notify-send "Wallpaper Selector" "Generating ${#missing_files[@]} new thumbnails in background..."

    for file in "${missing_files[@]}"; do
        # 重新计算缩略图路径 (算法与下面保持一致)
        # 1. 替换 / 为 _ (极速)
        local flat_path="${file//\//_}"
        # 移除开头的 _ (如果有)
        flat_path="${flat_path#_}"

        # 2. 如果路径太长超过240字符（Linux文件名限制），回退到 md5 (慢但安全)
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
ROFI_INPUT_CACHE=$(mktemp)

# 1. 快速查找所有文件
# 使用 find 一次性获取列表
all_files=$(find "${WALLPAPER_DIRS[@]}" -type f 2>/dev/null | grep -E "\.(${EXTS})$" | sort)

# 2. 极速构建列表 (纯 Bash 运算)
while IFS= read -r file; do
    if [[ -z "$file" ]]; then continue; fi

    # 加入索引数组
    WALLPAPER_LIST+=("$file")

    # 优化1: 使用 Bash 内置替换代替 basename (速度快)
    filename="${file##*/}"

    # 优化2: 使用路径字符替换代替 md5sum (速度快 100倍)
    # 将 /home/user/pic.jpg 转换为 home_user_pic.jpg
    flat_path="${file//\//_}"
    flat_path="${flat_path#_}"

    # 兼容性检查: 如果路径极长，才使用 md5
    if [[ ${#flat_path} -gt 240 ]]; then
        # 只有极少数文件会走这里
        hash=$(echo -n "$file" | md5sum | cut -d" " -f1)
        thumb="$CACHE_DIR/${hash}.jpg"
    else
        thumb="$CACHE_DIR/${flat_path}.jpg"
    fi

    # 优化3: 只检查存在性，绝不在此处生成
    if [[ -f "$thumb" ]]; then
        echo -en "${filename}\0icon\x1f${thumb}\n" >> "$ROFI_INPUT_CACHE"
    else
        # 记录缺失的文件，稍后后台生成
        MISSING_THUMBS+=("$file")
        # 暂时显示无图标条目
        echo -en "${filename}\n" >> "$ROFI_INPUT_CACHE"
    fi

done <<< "$all_files"

# 3. 如果有缺失的缩略图，在后台启动生成 (不阻塞 UI)
if [[ ${#MISSING_THUMBS[@]} -gt 0 ]]; then
    (generate_thumbs_background "${MISSING_THUMBS[@]}" &) > /dev/null 2>&1
fi

# 4. 瞬间启动 Rofi
SELECTED_INDEX=$(cat "$ROFI_INPUT_CACHE" | rofi -dmenu -i -show-icons -p "🖼️ Wallpapers" -theme "${ROFI_THEME}" -format i)

# 清理
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
    matugen image ~/.cache/current_wallpaper


    # 尝试获取图标用于通知 (需要重新计算一次路径)
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
