#!/usr/bin/env bash
set -euo pipefail

########################
# 配置区域
########################

NIRI_CONFIG="$HOME/.config/niri/config.kdl"

# --- 修改点 1: 默认编辑器改为 markpix ---
SHOTEDITOR_DEFAULT="markpix"
COPY_CMD="wl-copy"

# 菜单程序
MENU_CMD='fuzzel --dmenu'

# 图片目录
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
SCREEN_DIR="$PICTURES_DIR/Screenshots"

########################
# 本地化（中/英）
########################

LOCALE="${LC_MESSAGES:-${LANG:-en}}"
if [[ "$LOCALE" == zh* ]]; then
    LABEL_CANCEL="取消"
    LABEL_SETTINGS="设置"
    LABEL_EDIT_YES="编辑"
    LABEL_EDIT_NO="不编辑"
    LABEL_NIRI_FULL="全屏"
    LABEL_NIRI_WINDOW="窗口"
    LABEL_NIRI_REGION="选取区域"
    LABEL_GRIM_FULL="全屏"
    LABEL_GRIM_REGION="选取区域"
    LABEL_SETTINGS_EDITOR="截图工具"
    LABEL_SETTINGS_BACKEND="后端模式"
    LABEL_BACKEND_AUTO="自动（检测 Niri）"
    LABEL_BACKEND_GRIM="仅 Grim+slurp"
    LABEL_BACK="返回"
    LABEL_EDIT_STATE_ON="编辑：开启"
    LABEL_EDIT_STATE_OFF="编辑：关闭"
    PROMPT_MAIN="请选择截图模式"
    PROMPT_SETTINGS="设置 / 更改选项"
    PROMPT_EDITOR="请选择截图编辑工具"
    PROMPT_BACKEND="请选择后端模式"
else
    LABEL_CANCEL="Cancel"
    LABEL_SETTINGS="Settings"
    LABEL_EDIT_YES="Edit"
    LABEL_EDIT_NO="No edit"
    LABEL_NIRI_FULL="Fullscreen"
    LABEL_NIRI_WINDOW="Window"
    LABEL_NIRI_REGION="Region"
    LABEL_GRIM_FULL="Fullscreen"
    LABEL_GRIM_REGION="Select area"
    LABEL_SETTINGS_EDITOR="Screenshot tool"
    LABEL_SETTINGS_BACKEND="Backend mode"
    LABEL_BACKEND_AUTO="Auto (detect Niri)"
    LABEL_BACKEND_GRIM="Grim+slurp only"
    LABEL_BACK="Back"
    LABEL_EDIT_STATE_ON="Edit: ON"
    LABEL_EDIT_STATE_OFF="Edit: OFF"
    PROMPT_MAIN="Choose screenshot mode"
    PROMPT_SETTINGS="Settings / Options"
    PROMPT_EDITOR="Choose screenshot editor"
    PROMPT_BACKEND="Choose backend mode"
fi

########################
# 持久化配置路径
########################

CONFIG_DIR="$HOME/.cache/waybar/waybar-shot"
BACKEND_FILE="$CONFIG_DIR/backend"
EDITOR_FILE="$CONFIG_DIR/editor"
EDIT_MODE_FILE="$CONFIG_DIR/edit_mode"

########################
# 通用工具函数
########################

menu() {
    printf '%s\n' "$@" | eval "$MENU_CMD" 2>/dev/null || true
}

menu_prompt() {
    local prompt="$1"
    shift
    local esc_prompt="${prompt//\"/\\\"}"
    printf '%s\n' "$@" | eval "$MENU_CMD --prompt \"$esc_prompt\"" 2>/dev/null || true
}

load_backend_mode() {
    local mode
    if [[ -n "${SHOT_BACKEND:-}" ]]; then
        mode="$SHOT_BACKEND"
    elif [[ -f "$BACKEND_FILE" ]]; then
        mode="$(<"$BACKEND_FILE")"
    else
        mode="auto"
    fi
    case "$mode" in
        auto|grim|niri) ;;
        *) mode="auto" ;;
    esac
    printf '%s\n' "$mode"
}

save_backend_mode() {
    local mode="$1"
    mkdir -p "$CONFIG_DIR"
    printf '%s\n' "$mode" >"$BACKEND_FILE"
}

load_editor() {
    local ed
    if [[ -n "${SHOTEDITOR:-}" ]]; then
        ed="$SHOTEDITOR"
    elif [[ -f "$EDITOR_FILE" ]]; then
        ed="$(<"$EDITOR_FILE")"
    else
        ed="$SHOTEDITOR_DEFAULT"
    fi

    ed="${ed,,}"
    # --- 修改点 2: 允许 markpix ---
    case "$ed" in
        swappy|satty|markpix) ;;
        *) ed="$SHOTEDITOR_DEFAULT" ;;
    esac
    printf '%s\n' "$ed"
}

save_editor() {
    local ed="$1"
    mkdir -p "$CONFIG_DIR"
    printf '%s\n' "$ed" >"$EDITOR_FILE"
}

load_edit_mode() {
    local v="yes"
    if [[ -f "$EDIT_MODE_FILE" ]]; then
        v="$(<"$EDIT_MODE_FILE")"
    fi
    case "$v" in
        yes|no) ;;
        *) v="yes" ;;
    esac
    printf '%s\n' "$v"
}

save_edit_mode() {
    local v="$1"
    mkdir -p "$CONFIG_DIR"
    printf '%s\n' "$v" >"$EDIT_MODE_FILE"
}

detect_backend() {
    case "$BACKEND_MODE" in
        niri) echo "niri" ;;
        grim) echo "grim" ;;
        auto|*)
            if command -v niri >/dev/null 2>&1 && pgrep -x niri >/dev/null 2>&1; then
                echo "niri"
            else
                echo "grim"
            fi
            ;;
    esac
}

choose_editor() {
    local choice
    # --- 修改点 3: 菜单中加入 markpix ---
    choice="$(menu_prompt "$PROMPT_EDITOR" "markpix" "swappy" "satty" "$LABEL_BACK")"
    case "$choice" in
        markpix|Markpix)
            SHOTEDITOR="markpix"
            save_editor "$SHOTEDITOR"
            ;;
        swappy|Swappy)
            SHOTEDITOR="swappy"
            save_editor "$SHOTEDITOR"
            ;;
        satty|Satty)
            SHOTEDITOR="satty"
            save_editor "$SHOTEDITOR"
            ;;
        *) : ;;
    esac
}

choose_backend_mode() {
    local choice
    choice="$(menu_prompt "$PROMPT_BACKEND" "$LABEL_BACKEND_AUTO" "$LABEL_BACKEND_GRIM" "$LABEL_BACK")"
    case "$choice" in
        "$LABEL_BACKEND_AUTO")
            BACKEND_MODE="auto"
            save_backend_mode "$BACKEND_MODE"
            ;;
        "$LABEL_BACKEND_GRIM")
            BACKEND_MODE="grim"
            save_backend_mode "$BACKEND_MODE"
            ;;
        *) : ;;
    esac
}

settings_menu() {
    while :; do
        local backend_desc editor_line backend_line choice

        if [[ -n "${SHOT_BACKEND:-}" ]]; then
            backend_desc="${BACKEND_MODE} (env)"
        else
            if [[ "$BACKEND_MODE" == "grim" ]]; then
                backend_desc="$LABEL_BACKEND_GRIM"
            elif [[ "$BACKEND_MODE" == "niri" ]]; then
                backend_desc="niri"
            else
                backend_desc="$LABEL_BACKEND_AUTO"
            fi
        fi

        editor_line="$LABEL_SETTINGS_EDITOR: $SHOTEDITOR"
        backend_line="$LABEL_SETTINGS_BACKEND: $backend_desc"

        choice="$(menu_prompt "$PROMPT_SETTINGS" "$editor_line" "$backend_line" "$LABEL_BACK")"
        case "$choice" in
            "$editor_line")  choose_editor ;;
            "$backend_line")
                if [[ -n "${SHOT_BACKEND:-}" ]]; then
                    :
                else
                    choose_backend_mode
                fi
                ;;
            *)               return ;;
        esac
    done
}

latest_in_dir() {
    local dir="$1"
    find "$dir" -maxdepth 1 -type f -printf '%T@ %p\n' 2>/dev/null \
        | sort -n | tail -1 | cut -d' ' -f2-
}

########################
# 剪贴板相关
########################

clip_hash() {
    wl-paste -t image/png 2>/dev/null \
        | sha1sum 2>/dev/null \
        | cut -d' ' -f1 2>/dev/null \
        || echo ""
}

wait_clipboard_change() {
    local old new i
    old="$(clip_hash)"
    for i in {1..200}; do
        new="$(clip_hash)"
        if [[ -n "$new" && "$new" != "$old" ]]; then
            return 0
        fi
        sleep 0.05
    done
    return 1
}

########################
# 核心编辑逻辑
########################

# Grim 模式：传入已有文件路径，调用编辑器
edit_file_image() {
    local src="$1"
    local backend="$2"

    local dir ts dst
    if [[ "$backend" == "niri" ]]; then
        dir="$NIRI_EDIT_DIR"
    else
        dir="$SCREEN_DIR"
    fi

    mkdir -p "$dir"
    ts="$(date +'%Y-%m-%d_%H-%M-%S')"
    dst="$dir/${SHOTEDITOR}-$ts.png"

    # --- 修改点 4: markpix 处理逻辑 ---
    if [[ "$SHOTEDITOR" == "markpix" ]]; then
        # 将源文件移动或复制到目标文件（作为编辑底图）
        cp "$src" "$dst"
        # 直接把图片传给 markpix
        markpix "$dst"
    else
        # 旧的 swappy/satty 逻辑（这里其实用不到了，如果只用 markpix）
        if [[ -f "$src" ]]; then
           if [[ "$SHOTEDITOR" == "swappy" ]]; then
               swappy -f "$src" -o "$dst"
           elif [[ "$SHOTEDITOR" == "satty" ]]; then
               satty -f "$src" --output-filename "$dst"
           fi
        fi
    fi

    # 编辑结束后，将结果复制到剪贴板
    if [[ -f "$dst" ]]; then
        if [[ "$backend" == "grim" && "$src" == /tmp/* ]]; then
            rm -f "$src"
        fi
        "$COPY_CMD" < "$dst"
    fi
}

# Niri 模式：剪贴板 -> 文件 -> 编辑器
edit_from_clipboard() {
    local backend="$1"

    local dir ts dst
    if [[ "$backend" == "niri" ]]; then
        dir="$NIRI_EDIT_DIR"
    else
        dir="$SCREEN_DIR"
    fi

    mkdir -p "$dir"
    ts="$(date +'%Y-%m-%d_%H-%M-%S')"
    dst="$dir/${SHOTEDITOR}-$ts.png"

    # --- 修改点 5: Niri 剪贴板流转给 markpix ---
    if [[ "$SHOTEDITOR" == "markpix" ]]; then
        # 1. 先把剪贴板存为文件
        wl-paste -t image/png > "$dst"
        # 2. 用 markpix 打开该文件
        if [[ -s "$dst" ]]; then
            markpix "$dst"
        fi
    else
        case "$SHOTEDITOR" in
            satty)
                wl-paste -t image/png 2>/dev/null | satty -f - --output-filename "$dst"
                ;;
            swappy)
                wl-paste -t image/png 2>/dev/null | swappy -f - -o "$dst"
                ;;
            *)
                echo "Unknown SHOTEDITOR: $SHOTEDITOR" >&2
                return 0
                ;;
        esac
    fi

    if [[ -f "$dst" ]]; then
        "$COPY_CMD" < "$dst"
    fi
}

########################
# Niri 流程
########################

get_niri_shot_dir() {
    [[ -f "$NIRI_CONFIG" ]] || { echo "Config not found: $NIRI_CONFIG" >&2; return 1; }
    local line tpl dir
    line="$(grep -E '^[[:space:]]*screenshot-path[[:space:]]' "$NIRI_CONFIG" | grep -v '^[[:space:]]*//' | tail -n 1 || true)"
    [[ -n "$line" ]] || { echo "No screenshot-path in config" >&2; return 1; }
    tpl="$(sed -E 's/.*screenshot-path[[:space:]]+"([^"]+)".*/\1/' <<<"$line")"
    [[ -n "$tpl" ]] || { echo "Failed to parse screenshot-path" >&2; return 1; }
    tpl="${tpl/#\~/$HOME}"
    dir="${tpl%/*}"
    printf '%s\n' "$dir"
}

niri_capture_and_maybe_edit() {
    local mode="$1"
    local need_edit="$2"
    local action
    case "$mode" in
        fullscreen) action="screenshot-screen" ;;
        window)     action="screenshot-window" ;;
        region)     action="screenshot"       ;;
        *)          return 0 ;;
    esac

    if [[ "$need_edit" != "yes" ]]; then
        local before shot
        before="$(latest_in_dir "$NIRI_SHOT_DIR" || true)"
        niri msg action "$action"
        while :; do
            shot="$(latest_in_dir "$NIRI_SHOT_DIR" || true)"
            if [[ -z "$before" && -n "$shot" ]] || [[ -n "$before" && -n "$shot" && "$shot" != "$before" ]]; then
                break
            fi
            sleep 0.05
        done
        return 0
    fi

    niri msg action "$action"
    if ! wait_clipboard_change; then
        echo "等待剪贴板超时" >&2
        return 0
    fi
    edit_from_clipboard "niri"
    return 0
}

run_niri_flow() {
    NIRI_SHOT_DIR="$(get_niri_shot_dir)" || return 0
    NIRI_EDIT_DIR="$NIRI_SHOT_DIR/Edited"
    mkdir -p "$NIRI_SHOT_DIR" "$NIRI_EDIT_DIR"

    while :; do
        local choice mode edit_mode edit_label
        edit_mode="$(load_edit_mode)"
        if [[ "$edit_mode" == "yes" ]]; then
            edit_label="$LABEL_EDIT_STATE_ON"
        else
            edit_label="$LABEL_EDIT_STATE_OFF"
        fi

        choice="$(menu_prompt "$PROMPT_MAIN" "$LABEL_NIRI_FULL" "$LABEL_NIRI_WINDOW" "$LABEL_NIRI_REGION" "$edit_label" "$LABEL_SETTINGS" "$LABEL_CANCEL")"
        [[ -z "$choice" || "$choice" == "$LABEL_CANCEL" ]] && return 2

        case "$choice" in
            "$LABEL_NIRI_FULL")   mode="fullscreen" ;;
            "$LABEL_NIRI_WINDOW") mode="window"     ;;
            "$LABEL_NIRI_REGION") mode="region"     ;;
            "$edit_label")
                [[ "$edit_mode" == "yes" ]] && save_edit_mode "no" || save_edit_mode "yes"
                continue
                ;;
            "$LABEL_SETTINGS")
                settings_menu
                SHOTEDITOR="$(load_editor)"
                BACKEND_MODE="$(load_backend_mode)"
                NEW_BACKEND="$(detect_backend)"
                [[ "$NEW_BACKEND" != "niri" ]] && return 1
                continue
                ;;
            *) return 2 ;;
        esac

        edit_mode="$(load_edit_mode)"
        if [[ "$edit_mode" == "yes" ]]; then
            niri_capture_and_maybe_edit "$mode" "yes"
        else
            niri_capture_and_maybe_edit "$mode" "no"
        fi
        return 0
    done
}

########################
# Grim + slurp 流程
########################

grim_capture_and_maybe_edit() {
    local mode="$1"
    local need_edit="$2"
    mkdir -p "$SCREEN_DIR"
    local ts shot geo
    ts="$(date +'%Y-%m-%d_%H-%M-%S')"

    if [[ "$need_edit" == "yes" ]]; then
        shot="/tmp/waybar-shot-$ts.png"
        case "$mode" in
            fullscreen) grim "$shot" ;;
            region)
                geo="$(slurp 2>/dev/null)" || return 0
                grim -g "$geo" "$shot"
                ;;
            *) return 0 ;;
        esac
        edit_file_image "$shot" "grim"
        return 0
    else
        shot="$SCREEN_DIR/Screenshot_$ts.png"
        case "$mode" in
            fullscreen) grim "$shot" ;;
            region)
                geo="$(slurp 2>/dev/null)" || return 0
                grim -g "$geo" "$shot"
                ;;
            *) return 0 ;;
        esac
        return 0
    fi
}

run_grim_flow() {
    mkdir -p "$SCREEN_DIR"
    while :; do
        local choice mode edit_mode edit_label
        edit_mode="$(load_edit_mode)"
        if [[ "$edit_mode" == "yes" ]]; then
            edit_label="$LABEL_EDIT_STATE_ON"
        else
            edit_label="$LABEL_EDIT_STATE_OFF"
        fi

        choice="$(menu_prompt "$PROMPT_MAIN" "$LABEL_GRIM_FULL" "$LABEL_GRIM_REGION" "$edit_label" "$LABEL_SETTINGS" "$LABEL_CANCEL")"
        [[ -z "$choice" || "$choice" == "$LABEL_CANCEL" ]] && return 2

        case "$choice" in
            "$LABEL_GRIM_FULL")   mode="fullscreen" ;;
            "$LABEL_GRIM_REGION") mode="region"     ;;
            "$edit_label")
                [[ "$edit_mode" == "yes" ]] && save_edit_mode "no" || save_edit_mode "yes"
                continue
                ;;
            "$LABEL_SETTINGS")
                settings_menu
                SHOTEDITOR="$(load_editor)"
                BACKEND_MODE="$(load_backend_mode)"
                NEW_BACKEND="$(detect_backend)"
                [[ "$NEW_BACKEND" != "grim" ]] && return 1
                continue
                ;;
            *) return 2 ;;
        esac

        edit_mode="$(load_edit_mode)"
        if [[ "$edit_mode" == "yes" ]]; then
            grim_capture_and_maybe_edit "$mode" "yes"
        else
            grim_capture_and_maybe_edit "$mode" "no"
        fi
        return 0
    done
}

########################
# 主循环
########################

while :; do
    BACKEND_MODE="$(load_backend_mode)"
    SHOTEDITOR="$(load_editor)"
    BACKEND="$(detect_backend)"

    case "$BACKEND" in
        niri)
            rc=0
            run_niri_flow || rc=$?
            if [[ "$rc" -eq 0 ]]; then exit 0; elif [[ "$rc" -eq 1 ]]; then continue; else exit 0; fi
            ;;
        grim)
            rc=0
            run_grim_flow || rc=$?
            if [[ "$rc" -eq 0 ]]; then exit 0; elif [[ "$rc" -eq 1 ]]; then continue; else exit 0; fi
            ;;
        *)
            run_grim_flow
            exit 0
            ;;
    esac
done
