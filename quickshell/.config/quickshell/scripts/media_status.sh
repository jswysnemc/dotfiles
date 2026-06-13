#!/bin/bash
# Waybar 媒体状态模块，向 Waybar 输出 JSON

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/i18n.sh
source "$script_dir/lib/i18n.sh"

POLL_INTERVAL="${MEDIA_STATUS_POLL_INTERVAL:-2}"
EVENT_PIPE="${XDG_RUNTIME_DIR:-/tmp}/waybar-media-status-$$.fifo"
WATCHER_PID=""
LAST_OUTPUT=""

# 按 UTF-8 字符长度截断文本，避免截断多字节字符。
#
# @param $1 待截断文本
# @param $2 最大字符数
# @returns 截断后的文本
utf8_truncate() {
    local str="$1"
    local max_chars="$2"

    # 1. 使用 awk 按字符截断，避免破坏 UTF-8 字符
    echo -n "$str" | awk -v max="$max_chars" '{print substr($0, 1, max)}'
}

# 转义 JSON 字符串中的特殊字符，并移除非法控制字符。
#
# @param $1 待转义文本
# @returns 可安全写入 JSON 字段的文本
json_escape() {
    local str="$1"

    # 1. 先移除非法 UTF-8 序列
    str=$(echo -n "$str" | iconv -f UTF-8 -t UTF-8 -c 2>/dev/null)
    # 2. 依次转义 JSON 中有特殊含义的字符
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/}"
    str="${str//$'\t'/\\t}"
    # 3. 移除剩余控制字符
    str=$(echo -n "$str" | tr -d '\000-\037')
    echo -n "$str"
}

# 读取当前活动播放器状态，并组装 Waybar JSON。
#
# @param 无
# @returns Waybar custom 模块需要的 JSON 行
get_status() {
    local player=""
    local status=""
    local icon=$'\uf04b'
    local class="stopped"
    local tooltip
    local players
    tooltip="$(qs_i18n_literal "media" "没有正在播放的媒体")"

    # 1. 没有播放器时直接返回，避免空闲轮询时反复查询元数据
    players=$(playerctl -l 2>/dev/null)
    if [[ -z "$players" ]]; then
        printf '{"text": "%s", "alt": "stopped", "tooltip": "%s", "class": "stopped"}\n' "$icon" "$tooltip"
        return
    fi

    # 2. 优先选择正在播放的播放器，其次选择暂停中的播放器
    while IFS= read -r p; do
        local s
        s=$(playerctl -p "$p" status 2>/dev/null)
        if [[ "$s" == "Playing" ]]; then
            player="$p"
            status="Playing"
            break
        elif [[ "$s" == "Paused" && -z "$player" ]]; then
            player="$p"
            status="Paused"
        fi
    done <<< "$players"

    # 3. 没有明确活动播放器时回退到 playerctl 默认播放器
    if [[ -z "$player" ]]; then
        status=$(playerctl status 2>/dev/null)
        player=$(playerctl metadata --format '{{playerName}}' 2>/dev/null)
    fi

    if [[ -z "$status" || "$status" == "No players found" ]]; then
        printf '{"text": "%s", "alt": "stopped", "tooltip": "%s", "class": "stopped"}\n' "$icon" "$tooltip"
        return
    fi

    # 4. 读取元数据并限制显示长度
    local title
    local artist
    title=$(playerctl -p "$player" metadata title 2>/dev/null)
    artist=$(playerctl -p "$player" metadata artist 2>/dev/null)
    title=$(utf8_truncate "$title" 30)
    artist=$(utf8_truncate "$artist" 20)

    case "$status" in
        Playing)
            icon=$'\uf04c'
            class="playing"
            ;;
        Paused)
            icon=$'\uf04b'
            class="paused"
            ;;
        *)
            icon=$'\uf04b'
            class="stopped"
            ;;
    esac

    if [[ -n "$title" ]]; then
        # 5. 标题、作者和播放器名称写入 JSON 前先转义
        title=$(json_escape "$title")
        artist=$(json_escape "$artist")
        player=$(json_escape "$player")

        tooltip="$title"
        if [[ -n "$artist" ]]; then
            tooltip="$tooltip - $artist"
        fi
        if [[ -n "$player" ]]; then
            tooltip="$tooltip\\n$player"
        fi
    else
        tooltip="$status"
    fi

    printf '{"text": "%s", "alt": "%s", "tooltip": "%s", "class": "%s"}\n' \
        "$icon" "$class" "$tooltip" "$class"
}

# 判断当前是否存在 MPRIS 播放器。
#
# @param 无
# @returns 存在播放器时返回 0，否则返回 1
has_players() {
    playerctl -l 2>/dev/null | grep -q .
}

# 停止 playerctl 状态事件监听器。
#
# @param 无
# @returns 无
stop_status_watcher() {
    # 1. 没有监听器时直接返回
    if [[ -z "$WATCHER_PID" ]]; then
        return
    fi
    # 2. 终止当前监听器并回收进程
    kill "$WATCHER_PID" 2>/dev/null
    wait "$WATCHER_PID" 2>/dev/null
    WATCHER_PID=""
}

# 清理事件管道和后台监听进程。
#
# @param 无
# @returns 无
cleanup() {
    trap - EXIT INT TERM HUP PIPE
    # 1. 终止状态监听器及其子进程
    stop_status_watcher
    # 2. 清理当前脚本启动的其他后台任务
    jobs -p | xargs -r kill 2>/dev/null
    # 3. 删除本次实例的临时管道
    rm -f "$EVENT_PIPE"
    exit 0
}
trap cleanup EXIT INT TERM HUP PIPE

# 状态发生变化时输出一行 JSON。
#
# @param 无
# @returns 无
output_if_changed() {
    local output

    # 1. 只由主循环调用，避免多个子 shell 各自输出重复内容
    output=$(get_status)
    if [[ "$output" != "$LAST_OUTPUT" ]]; then
        echo "$output"
        LAST_OUTPUT="$output"
    fi
}

# 启动单个 playerctl 状态事件监听器。
#
# @param 无
# @returns 无
start_status_watcher() {
    # 1. 监听器存活时不重复启动
    if [[ -n "$WATCHER_PID" ]] && kill -0 "$WATCHER_PID" 2>/dev/null; then
        return
    fi
    # 2. 直接后台运行 playerctl，避免额外常驻 Bash 子 shell
    playerctl --follow status 2>/dev/null >&3 &
    WATCHER_PID=$!
}

# 同步 playerctl 状态事件监听器。
#
# @param 无
# @returns 无
sync_status_watcher() {
    # 1. 有播放器时启动监听器，保证播放状态变化可以即时刷新
    if has_players; then
        start_status_watcher
        return
    fi
    # 2. 没有播放器时停止监听器，空闲状态只保留低频轮询
    stop_status_watcher
}

# 1. 创建当前实例专用事件管道
rm -f "$EVENT_PIPE"
mkfifo "$EVENT_PIPE"
exec 3<>"$EVENT_PIPE"
rm -f "$EVENT_PIPE"

# 2. 输出初始状态并启动唯一的 playerctl 事件监听器
output_if_changed
sync_status_watcher

# 3. 主循环统一响应事件，并用低频轮询兜底元数据和播放器增删
while true; do
    sync_status_watcher
    if IFS= read -r -t "$POLL_INTERVAL" _ <&3; then
        output_if_changed
        sync_status_watcher
        while IFS= read -r -t 0.05 _ <&3; do
            :
        done
    else
        output_if_changed
        sync_status_watcher
    fi
done
