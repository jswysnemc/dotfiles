#!/bin/bash
# 滚动截图脚本
# 依赖: slurp, wf-recorder, fuzzel, imv, rust-stitch

set -e

# =====================
# 配置
# =====================
OUTPUT_DIR="${SCROLL_CAPTURE_DIR:-$HOME/Pictures/ScrollCaptures}"
STITCH_BIN="${STITCH_BIN:-/home/snemc/Desktop/rust-stitch/target/release/rust-stitch}"
LOG_FILE="/tmp/scroll-capture-debug.log"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$OUTPUT_DIR/scroll_$TIMESTAMP.png"

# 清空日志
echo "=== Scroll Capture Started: $(date) ===" > "$LOG_FILE"

log() {
    echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"
}

# 记录我们启动的进程 PID
OUR_RECORD_PID=""
OUR_STITCH_PID=""
OUR_RELAY_PID=""

cleanup() {
    log "Cleaning up..."
    # 只杀死我们自己启动的 wf-recorder 进程，不影响其他录屏
    if [[ -n "$OUR_RECORD_PID" ]] && kill -0 "$OUR_RECORD_PID" 2>/dev/null; then
        kill -SIGINT "$OUR_RECORD_PID" 2>/dev/null || true
        sleep 0.2
        kill -9 "$OUR_RECORD_PID" 2>/dev/null || true
    fi
    [[ -n "$OUR_STITCH_PID" ]] && kill -9 "$OUR_STITCH_PID" 2>/dev/null || true
    [[ -n "$OUR_RELAY_PID" ]] && kill -9 "$OUR_RELAY_PID" 2>/dev/null || true
    rm -f /tmp/scroll-capture-*.fifo /tmp/scroll-capture-*.log 2>/dev/null || true
}

trap cleanup EXIT

# 确保输出目录存在
mkdir -p "$OUTPUT_DIR"

# =====================
# 步骤1: 使用 slurp 选区
# =====================
log "Step 1: Select region with slurp..."
GEOMETRY=$(slurp 2>> "$LOG_FILE")

if [ -z "$GEOMETRY" ]; then
    log "ERROR: No region selected"
    exit 1
fi

log "Selected region: $GEOMETRY"

log "Dimensions (logical): $GEOMETRY"

# =====================
# 步骤2: 录屏 + fuzzel 停止按钮
# =====================
log "Step 2: Starting recording..."

# 创建命名管道
RAW_FIFO="/tmp/scroll-capture-raw-$$.fifo"      # wf-recorder 写入
STITCH_FIFO="/tmp/scroll-capture-stitch-$$.fifo" # rust-stitch 读取
DONE_FIFO="/tmp/scroll-capture-done-$$.fifo"
WF_STDERR="/tmp/scroll-capture-wf-stderr-$$.log"
rm -f "$RAW_FIFO" "$STITCH_FIFO" "$DONE_FIFO" "$WF_STDERR" 2>/dev/null || true
mkfifo "$RAW_FIFO"
mkfifo "$STITCH_FIFO"
mkfifo "$DONE_FIFO"

# 启动 wf-recorder
log "Starting wf-recorder..."
yes | wf-recorder \
    -g "$GEOMETRY" \
    --pixel-format bgra \
    -c rawvideo \
    -m rawvideo \
    -f "$RAW_FIFO" \
    2> >(tee "$WF_STDERR" >> "$LOG_FILE") &
OUR_RECORD_PID=$!

# 等待 wf-recorder 输出尺寸信息
sleep 0.5

# 从 wf-recorder stderr 解析实际尺寸 (格式: "1034x1224")
ACTUAL_DIM=$(grep -oP '\d+x\d+(?= \[SAR)' "$WF_STDERR" | head -1)
if [ -z "$ACTUAL_DIM" ]; then
    log "ERROR: Could not parse wf-recorder dimensions"
    exit 1
fi
log "Actual dimensions from wf-recorder: $ACTUAL_DIM"

# 中间进程：写入尺寸头 + 转发视频数据
(
    echo "$ACTUAL_DIM"
    cat "$RAW_FIFO"
) > "$STITCH_FIFO" &
OUR_RELAY_PID=$!

# 启动 rust-stitch (自动从流头读取尺寸)
(
    log "Starting stitch process (auto mode)..."
    STITCH_RAW=1 "$STITCH_BIN" "$OUTPUT_FILE" < "$STITCH_FIFO" 2>> "$LOG_FILE"
    log "Stitch process finished"
    echo "done" > "$DONE_FIFO"
) &
OUR_STITCH_PID=$!

log "Recording started (PID: $OUR_RECORD_PID)"

# 等待一小段时间让录制启动
sleep 0.3

# =====================
# 步骤3: fuzzel 停止按钮
# =====================
log "Step 3: Launching stop button..."

# 使用 fuzzel 显示停止按钮
(
    echo -e "停止录制\n" | fuzzel \
        --dmenu \
        --prompt="🔴 录制中 " \
        --width=25 \
        --lines=1 \
        --anchor=top \
        2>> "$LOG_FILE"

    log "User clicked stop, sending SIGINT to wf-recorder (PID: $OUR_RECORD_PID)..."
    kill -SIGINT "$OUR_RECORD_PID" 2>> "$LOG_FILE" || true
) &
FUZZEL_PID=$!

log "Fuzzel started (PID: $FUZZEL_PID)"

# =====================
# 等待完成
# =====================
log "Waiting for completion..."

# 等待管道信号或超时
read -t 300 _ < "$DONE_FIFO" || {
    log "Timeout or error waiting for completion"
}

rm -f "$RAW_FIFO" "$STITCH_FIFO" "$DONE_FIFO" "$WF_STDERR"

# 等待进程结束
wait $OUR_RECORD_PID 2>/dev/null || true
pkill -9 -P $FUZZEL_PID 2>/dev/null || true
wait $FUZZEL_PID 2>/dev/null || true

# =====================
# 步骤4: 显示结果
# =====================
if [ -f "$OUTPUT_FILE" ]; then
    log "Success! Output: $OUTPUT_FILE"
    log "Opening with imv..."
    image-viewer "$OUTPUT_FILE" &

    # 发送通知
    notify-send "滚动截图完成" "$OUTPUT_FILE" 2>/dev/null || true
else
    log "ERROR: Output file not created"
    notify-send -u critical "滚动截图失败" "查看日志: $LOG_FILE" 2>/dev/null || true
    exit 1
fi

log "=== Scroll Capture Completed ==="
