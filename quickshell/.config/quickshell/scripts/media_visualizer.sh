#!/bin/bash
# Waybar media visualizer - Fixed Process Management
# Optimized for zero CPU usage when idle/paused

# Configuration
CHARS="▁▂▃▄▅▆▇█"
BARS=10
# 使用带 $$ 的绝对路径确保唯一性，防止杀错其他进程
CONF="/tmp/waybar_cava_config_$$"

# Apps to ignore (background services)
IGNORE_APPS="speech-dispatcher|sd_dummy|at-spi|orca"

# Derived values
len=$((${#CHARS}-1))
IDLE_CHAR="${CHARS:0:1}"
IDLE_LINE=$(printf "%0.s$IDLE_CHAR" $(seq 1 $BARS))

# Generate Cava config
cat > "$CONF" <<EOF
[general]
bars = $BARS
[input]
method = pulse
source = auto
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = $len
EOF

cleanup() {
    trap - EXIT INT TERM HUP QUIT PIPE
    stop_cava
    # 输出停止状态以清空 Waybar
    echo '{"text": "", "class": "stopped"}'
    rm -f "$CONF"
    exit 0
}
trap cleanup EXIT INT TERM HUP QUIT PIPE

check_audio_state() {
    local output
    output=$(pactl list sink-inputs 2>/dev/null)

    if ! echo "$output" | grep -q "Sink Input"; then
        return 2
    fi

    local has_real=0
    local has_active=0
    local current_app="" current_corked=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^"Sink Input" ]]; then
            if [[ -n "$current_app" && ! "$current_app" =~ $IGNORE_APPS ]]; then
                has_real=1
                [[ "$current_corked" == "no" ]] && has_active=1
            fi
            current_app=""
            current_corked=""
        elif [[ "$line" =~ Corked:\ (.+) ]]; then
            current_corked="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ application\.name\ =\ \"(.+)\" ]]; then
            current_app="${BASH_REMATCH[1]}"
        fi
    done <<< "$output"

    if [[ -n "$current_app" && ! "$current_app" =~ $IGNORE_APPS ]]; then
        has_real=1
        [[ "$current_corked" == "no" ]] && has_active=1
    fi

    if [[ "$has_real" != "1" ]]; then return 2; fi
    if [[ "$has_active" == "1" ]]; then return 0; fi
    return 1
}

# 强力检测 Cava 是否运行
is_cava_running() {
    pgrep -f "cava -p $CONF" >/dev/null 2>&1
}

start_cava() {
    if is_cava_running; then return 0; fi

    # 启动前确保清理干净
    stop_cava

    # 启动子 shell
    (
        idle_start=0
        last_output=""

        # 这里的 sed 负责将数字转为字符
        cava -p "$CONF" 2>/dev/null | stdbuf -o0 sed -u "$SED_DICT" | while IFS= read -r line; do
            now=$(date +%s%3N 2>/dev/null || date +%s)000
            now=${now:0:13}

            if [[ "$line" == "$IDLE_LINE" ]]; then
                # 直线状态
                if [[ "$idle_start" == "0" ]]; then
                    idle_start=$now
                fi
                idle_duration=$(( (now - idle_start) ))

                # 超过1秒才隐藏
                if [[ "$idle_duration" -ge 1000 ]]; then
                    if [[ "$last_output" != "idle" ]]; then
                        printf '{"text": "", "class": "idle"}\n'
                        last_output="idle"
                    fi
                fi
                # 1秒内保持上一次的显示状态（不输出新内容）
            else
                # 有声音，重置计时器
                idle_start=0
                if [[ "$last_output" != "$line" ]]; then
                    printf '{"text": "%s", "class": "playing"}\n' "$line"
                    last_output="$line"
                fi
            fi
        done
    ) &
}

stop_cava() {
    # 核心修改：通过唯一的配置文件路径来匹配进程，绝对不会杀错
    # 获取相关进程 ID
    local pids
    pids=$(pgrep -f "cava -p $CONF")
    
    if [[ -n "$pids" ]]; then
        # 尝试正常终止
        kill $pids 2>/dev/null
        # 等待一小会儿让它退出
        for i in {1..5}; do
            if ! pgrep -f "cava -p $CONF" >/dev/null; then
                break
            fi
            sleep 0.05
        done
        
        # 如果还在运行，强制杀死
        if pgrep -f "cava -p $CONF" >/dev/null; then
            pkill -9 -f "cava -p $CONF" 2>/dev/null
        fi
    fi
}

build_sed_dict() {
    local dict="s/;//g;"
    for ((i=0; i<=len; i++)); do
        dict="${dict}s/$i/${CHARS:$i:1}/g;"
    done
    echo "$dict"
}

SED_DICT=$(build_sed_dict)

# Initial state
echo '{"text": "", "class": "stopped"}'
last_state=2

while true; do
    check_audio_state
    state=$?

    case $state in
        0)  # 播放中
            start_cava
            last_state=0
            # 这里的 sleep 主要是防止高频检测，Cava 会在子进程里持续输出
            sleep 0.5 
            ;;
        1)  # 暂停中 - 修改：收回可视化
            if is_cava_running; then
                stop_cava
            fi
            if [[ $last_state -ne 1 ]]; then
                # 输出空文本，Class 设为 paused
                echo '{"text": "", "class": "paused"}'
                last_state=1
            fi
            # 挂起等待 pactl 事件（减少轮询）
            # timeout 防止 pactl 僵死
            timeout 5s pactl subscribe 2>/dev/null | grep --line-buffered -m1 "sink-input" >/dev/null
            ;;
        2)  # 无音频流 - 隐藏
            if is_cava_running; then
                stop_cava
            fi
            if [[ $last_state -ne 2 ]]; then
                echo '{"text": "", "class": "stopped"}'
                last_state=2
            fi
            timeout 5s pactl subscribe 2>/dev/null | grep --line-buffered -m1 "sink-input" >/dev/null
            ;;
    esac
done
