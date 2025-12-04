#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# PY_STITCH="wf-stitch"
PY_STITCH="rust-stitch"

CONFIG_DIR="$HOME/.cache/longshot-sh"
CONFIG_FILE="$CONFIG_DIR/mode"
SAVE_DIR="$HOME/Pictures/Screenshots/longshots"
mkdir -p "$SAVE_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TMP_VIDEO="/tmp/longshot_${TIMESTAMP}.mp4"
OUTPUT_IMG="${SAVE_DIR}/longshot_${TIMESTAMP}.png"

# 语言
if env | grep -q "zh_CN"; then
    TXT_REC="录制中"
    TXT_MSG="正在拼接..."
    TXT_SAVED="已保存并复制"
    WIDTH=6
else
    TXT_REC="Recording"
    TXT_MSG="Stitching..."
    TXT_SAVED="Saved"
    WIDTH=10
fi

# 录制菜单
if command -v fuzzel &> /dev/null; then
    # MENU_REC_CMD="fuzzel -d --anchor top --y-margin 20 --width $WIDTH --lines 0"
    MENU_REC_CMD="fuzzel -d --anchor top --y-margin 20 --width 30 --lines 1"
elif command -v wofi &> /dev/null; then
    MENU_REC_CMD="wofi -d -i -p Rec"
else
    MENU_REC_CMD="rofi -dmenu -p Rec"
fi

# Step 1: 选区
GEOMETRY=$(slurp)
if [ -z "$GEOMETRY" ]; then exit 1; fi

# Step 2: 录制
wf-recorder -g "$GEOMETRY" -f "$TMP_VIDEO" \
    -c libx264 -p crf=0 -p preset=ultrafast -p pixel_format=yuv420p \
    &> /dev/null &
REC_PID=$!

sleep 0.5
if ! kill -0 $REC_PID 2>/dev/null; then
    notify-send "Error" "wf-recorder failed"
    exit 1
fi

# Step 3: 停止菜单
echo "Stop" | $MENU_REC_CMD -p "$TXT_REC" > /dev/null

kill -SIGINT $REC_PID
wait $REC_PID 2>/dev/null

# Step 4: 处理
if [ -f "$TMP_VIDEO" ]; then
    notify-send -t 2000 "Longshot" "$TXT_MSG"

    "$PY_STITCH" "$TMP_VIDEO" "$OUTPUT_IMG"
    rm -f "$TMP_VIDEO"

    if [ -f "$OUTPUT_IMG" ]; then
        if command -v wl-copy &> /dev/null; then wl-copy < "$OUTPUT_IMG"; fi

        markpix -f "$OUTPUT_IMG"

        # 自动执行动作
        # FINAL_MODE=$(cat "$CONFIG_FILE" 2>/dev/null || echo "PREVIEW")
        # case "$FINAL_MODE" in
        #     "PREVIEW") imv "$OUTPUT_IMG" ;;
        #     "EDIT")    if command -v satty &> /dev/null; then satty -f "$OUTPUT_IMG"; else imv "$OUTPUT_IMG"; fi ;;
        #     "SAVE")    notify-send "Longshot" "$TXT_SAVED: $(basename "$OUTPUT_IMG")" ;;
        # esac
    fi
else
    notify-send "Error" "No video"
fi
