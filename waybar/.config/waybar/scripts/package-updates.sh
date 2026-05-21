#!/usr/bin/env bash

set -u

TIMEOUT_SECONDS="${ARCH_UPDATES_TIMEOUT:-20}"
MAX_TOOLTIP_ITEMS="${ARCH_UPDATES_TOOLTIP_LIMIT:-8}"
ICON="󰏔"

json_escape() {
    local value="${1//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    printf '%s' "$value"
}

count_lines() {
    awk 'NF { count++ } END { print count + 0 }'
}

append_items() {
    local title="$1"
    local items="$2"
    local count="$3"
    local tooltip="$4"

    if ((count == 0)); then
        printf '%s' "$tooltip"
        return
    fi

    tooltip+=$'\n\n'
    tooltip+="$title:"

    local shown=0
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        tooltip+=$'\n'"- $item"
        shown=$((shown + 1))
        ((shown >= MAX_TOOLTIP_ITEMS)) && break
    done <<< "$items"

    if ((count > shown)); then
        tooltip+=$'\n'"- ... 还有 $((count - shown)) 项"
    fi

    printf '%s' "$tooltip"
}

run_limited_to_file() {
    local output_file="$1"
    shift

    if command -v timeout >/dev/null 2>&1; then
        timeout "${TIMEOUT_SECONDS}s" "$@" > "$output_file" 2>/dev/null
    else
        "$@" > "$output_file" 2>/dev/null
    fi
}

find_aur_helper() {
    local helper
    for helper in paru yay; do
        if command -v "$helper" >/dev/null 2>&1; then
            printf '%s' "$helper"
            return 0
        fi
    done

    return 1
}

waybar_output() {
    local repo_file aur_file
    repo_file="$(mktemp -t waybar-repo-updates.XXXXXX)"
    aur_file="$(mktemp -t waybar-aur-updates.XXXXXX)"
    trap 'rm -f "$repo_file" "$aur_file"' RETURN

    local repo_note="" aur_note="" repo_status=0 aur_status=0 has_error=false

    if command -v checkupdates >/dev/null 2>&1; then
        run_limited_to_file "$repo_file" checkupdates || repo_status=$?
        if ((repo_status == 124)); then
            repo_note="官方仓库检查超时"
            has_error=true
            : > "$repo_file"
        fi
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Qu > "$repo_file" 2>/dev/null || true
        repo_note="未找到 checkupdates，官方仓库使用 pacman -Qu 后备统计"
    else
        repo_note="未找到 checkupdates 或 pacman，无法统计官方仓库更新"
        has_error=true
    fi

    local aur_helper=""
    if aur_helper="$(find_aur_helper)"; then
        run_limited_to_file "$aur_file" "$aur_helper" -Qua || aur_status=$?
        if ((aur_status == 124)); then
            aur_note="AUR 检查超时"
            has_error=true
            : > "$aur_file"
        fi
    else
        aur_note="未找到 paru 或 yay，跳过 AUR 更新统计"
    fi

    local repo_updates aur_updates repo_count aur_count total class tooltip text
    repo_updates="$(cat "$repo_file")"
    aur_updates="$(cat "$aur_file")"
    repo_count="$(printf '%s\n' "$repo_updates" | count_lines)"
    aur_count="$(printf '%s\n' "$aur_updates" | count_lines)"
    total=$((repo_count + aur_count))

    if ((total > 0)); then
        class="updates"
        text="$ICON $total"
    elif [[ "$has_error" == true ]]; then
        class="error"
        text="$ICON ?"
    else
        class="clean"
        text="$ICON 0"
    fi

    tooltip="Arch Linux 包更新"
    tooltip+=$'\n'"官方仓库: $repo_count"
    tooltip+=$'\n'"AUR: $aur_count"
    tooltip+=$'\n'"总计: $total"

    if [[ -n "$repo_note" ]]; then
        tooltip+=$'\n\n'"$repo_note"
    fi
    if [[ -n "$aur_note" ]]; then
        tooltip+=$'\n\n'"$aur_note"
    fi

    tooltip="$(append_items "官方仓库更新" "$repo_updates" "$repo_count" "$tooltip")"
    tooltip="$(append_items "AUR 更新" "$aur_updates" "$aur_count" "$tooltip")"

    printf '{"text":"%s","tooltip":"%s","class":"%s","alt":"%s"}\n' \
        "$(json_escape "$text")" \
        "$(json_escape "$tooltip")" \
        "$(json_escape "$class")" \
        "$(json_escape "$class")"
}

upgrade() {
    local terminal_launcher="$HOME/.custom/bin/terminal-launcher"
    if ! [[ -x "$terminal_launcher" ]]; then
        terminal_launcher="terminal-launcher"
    fi

    local update_command
    if command -v paru >/dev/null 2>&1; then
        update_command="paru -Syu"
    elif command -v yay >/dev/null 2>&1; then
        update_command="yay -Syu"
    else
        update_command="sudo pacman -Syu"
    fi

    if command -v "$terminal_launcher" >/dev/null 2>&1 || [[ -x "$terminal_launcher" ]]; then
        local hold_command="$update_command; printf '\n'; read -r -p '按 Enter 关闭...'"
        local terminal_cmd=("$terminal_launcher" --float -- bash -lc "$hold_command")

        if command -v setsid >/dev/null 2>&1; then
            setsid -f "${terminal_cmd[@]}" >/dev/null 2>&1
        else
            "${terminal_cmd[@]}" >/dev/null 2>&1 &
        fi
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send "Arch 包更新" "未找到 terminal-launcher，无法打开更新终端"
    else
        printf 'package-updates: terminal-launcher not found\n' >&2
        return 127
    fi
}

case "${1:-waybar}" in
    waybar|status)
        waybar_output
        ;;
    upgrade)
        upgrade
        ;;
    *)
        printf 'Usage: %s {waybar|status|upgrade}\n' "$0" >&2
        exit 1
        ;;
esac
