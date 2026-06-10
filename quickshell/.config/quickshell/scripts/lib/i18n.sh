#!/usr/bin/env bash

# 获取受支持的语言代码
qs_i18n_language() {
    local language="${QS_LANG:-${LANG:-${LC_ALL:-${LC_MESSAGES:-en_US}}}}"
    language="${language//-/_}"
    if [[ "${language,,}" == zh* ]]; then
        printf 'zh_CN\n'
    else
        printf 'en_US\n'
    fi
}

# 从功能语言包读取旧界面字面量
qs_i18n_literal() {
    local catalog="$1"
    local source="$2"
    local config_root="${QS_CONFIG_ROOT:-"$HOME/.config/quickshell"}"
    local language
    language="$(qs_i18n_language)"
    local catalog_path="$config_root/locales/$language/$catalog.json"
    local fallback_path="$config_root/locales/en_US/$catalog.json"

    if command -v jq >/dev/null 2>&1 && [[ -f "$catalog_path" ]]; then
        local translated
        translated="$(jq -r --arg source "$source" '.literals[$source] // empty' "$catalog_path" 2>/dev/null)"
        if [[ -n "$translated" ]]; then
            printf '%s\n' "$translated"
            return
        fi
    fi

    if command -v jq >/dev/null 2>&1 && [[ -f "$fallback_path" ]]; then
        local fallback
        fallback="$(jq -r --arg source "$source" '.literals[$source] // empty' "$fallback_path" 2>/dev/null)"
        if [[ -n "$fallback" ]]; then
            printf '%s\n' "$fallback"
            return
        fi
    fi

    printf '%s\n' "$source"
}
