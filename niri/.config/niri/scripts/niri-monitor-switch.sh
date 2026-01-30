#!/bin/bash
# niri-monitor-switch.sh: 显示器模式切换工具
# 支持 fuzzel 菜单、命令行直接设置、持久化配置

STATE_DIR="$HOME/.local/state/display"
CONFIG_FILE="$STATE_DIR/outputs.json"

mkdir -p "$STATE_DIR"

# --- 辅助函数 ---

# 获取所有输出设备名称
get_outputs() {
    niri msg outputs | grep "^Output" | awk -F '"' '{print $2}'
}

# 获取指定输出设备支持的模式 (格式: WxH@refresh)
get_modes() {
    local output_name="$1"
    niri msg outputs | \
    awk -v name="$output_name" '
        $0 ~ "Output \"" name "\"" { flag=1; next }
        $0 ~ "^Output " { flag=0 }
        flag && /Available modes:/ { modes_flag=1; next }
        flag && modes_flag && /^[ \t]*[0-9]+x[0-9]+/ {
            gsub(/^[ \t]+/, "", $0);
            print $1
        }
    '
}

# 获取当前模式
get_current_mode() {
    local output_name="$1"
    niri msg outputs | \
    awk -v name="$output_name" '
        $0 ~ "Output \"" name "\"" { flag=1; next }
        $0 ~ "^Output " { flag=0 }
        flag && /Current mode:/ {
            gsub(/^[ \t]+Current mode: /, "", $0);
            gsub(/ .*$/, "", $0);
            print $0
        }
    '
}

# 获取当前配置 (JSON 格式)
get_current_config() {
    niri msg -j outputs | jq '[to_entries[] | .value | {
        name: .name,
        make: .make,
        model: .model,
        mode: {
            width: .modes[.current_mode].width,
            height: .modes[.current_mode].height,
            refresh: (.modes[.current_mode].refresh_rate / 1000 | floor)
        },
        scale: .logical.scale,
        vrr: .vrr_enabled,
        position: {x: .logical.x, y: .logical.y}
    }]'
}

# 保存当前配置
save_config() {
    get_current_config > "$CONFIG_FILE"
    echo "配置已保存到: $CONFIG_FILE"
}

# 应用保存的配置
apply_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "没有保存的配置"
        return 1
    fi

    jq -c '.[]' "$CONFIG_FILE" | while read -r output; do
        name=$(echo "$output" | jq -r '.name')
        width=$(echo "$output" | jq -r '.mode.width')
        height=$(echo "$output" | jq -r '.mode.height')
        refresh=$(echo "$output" | jq -r '.mode.refresh')
        mode="${width}x${height}@${refresh}.000"

        echo "应用: $name -> $mode"
        niri msg output "$name" mode "$mode" 2>/dev/null || true
    done
}

# 设置显示器模式
set_mode() {
    local output="$1"
    local mode="$2"
    local save="${3:-}"

    if niri msg output "$output" mode "$mode"; then
        notify-send "显示设置" "已设置 $output 为 $mode" 2>/dev/null || true
        if [[ "$save" == "--save" || "$save" == "-s" ]]; then
            sleep 0.3
            save_config
        fi
        return 0
    else
        notify-send -u critical "显示设置" "设置失败: $output $mode" 2>/dev/null || true
        return 1
    fi
}

# 列出所有输出及其模式 (JSON 格式，供 QS 使用)
list_json() {
    niri msg -j outputs | jq '[to_entries[] | .value | {
        name: .name,
        make: .make,
        model: .model,
        current: {
            width: .modes[.current_mode].width,
            height: .modes[.current_mode].height,
            refresh: (.modes[.current_mode].refresh_rate / 1000 | floor)
        },
        scale: .logical.scale,
        vrr_supported: .vrr_supported,
        vrr_enabled: .vrr_enabled,
        modes: [.modes[] | {
            width: .width,
            height: .height,
            refresh: (.refresh_rate / 1000 | floor),
            preferred: .is_preferred
        }] | unique_by("\(.width)x\(.height)@\(.refresh)")
    }]'
}

# Fuzzel 交互式菜单
fuzzel_menu() {
    if ! command -v fuzzel &> /dev/null; then
        notify-send "错误" "未找到 fuzzel，请先安装。"
        exit 1
    fi

    # 选择显示器
    selected_output=$(get_outputs | fuzzel --dmenu --prompt "  选择显示器 > " --lines 5 --width 40)
    [[ -z "$selected_output" ]] && exit 0

    # 获取模式列表
    modes_list=$(get_modes "$selected_output")
    if [[ -z "$modes_list" ]]; then
        notify-send "显示设置" "无法获取 $selected_output 的模式列表"
        exit 1
    fi

    # 选择模式
    selected_mode=$(echo "$modes_list" | fuzzel --dmenu --prompt "  分辨率/刷新率 > " --lines 10 --width 40)
    [[ -z "$selected_mode" ]] && exit 0

    # 应用并保存
    clean_mode=$(echo "$selected_mode" | awk '{print $1}')
    set_mode "$selected_output" "$clean_mode" --save
}

# 帮助信息
show_help() {
    cat << EOF
用法: $(basename "$0") [命令] [参数]

命令:
  (无参数)          启动 Fuzzel 交互式菜单
  list              列出所有显示器 (文本格式)
  list-json         列出所有显示器 (JSON 格式，供 QS 使用)
  modes <output>    列出指定显示器的可用模式
  current <output>  获取指定显示器的当前模式
  set <output> <mode> [--save]  设置显示器模式
                    例: $(basename "$0") set eDP-1 2560x1600@60.000 --save
  save              保存当前配置
  apply             应用保存的配置
  config            显示保存的配置

配置文件: $CONFIG_FILE
EOF
}

# --- 主逻辑 ---
case "${1:-}" in
    list)
        get_outputs
        ;;
    list-json)
        list_json
        ;;
    modes)
        get_modes "$2"
        ;;
    current)
        get_current_mode "$2"
        ;;
    set)
        set_mode "$2" "$3" "$4"
        ;;
    save)
        save_config
        ;;
    apply)
        apply_config
        ;;
    config)
        if [[ -f "$CONFIG_FILE" ]]; then
            cat "$CONFIG_FILE"
        else
            echo "无保存的配置"
        fi
        ;;
    -h|--help|help)
        show_help
        ;;
    "")
        fuzzel_menu
        ;;
    *)
        echo "未知命令: $1"
        show_help
        exit 1
        ;;
esac
