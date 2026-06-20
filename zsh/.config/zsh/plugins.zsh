# 加载 zsh 的 高亮 man 和 sudo 插件
zi snippet OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh
zi snippet OMZ::plugins/sudo/sudo.plugin.zsh

# zi light hlissner/zsh-autopair


# vimode 插件， 在行编辑模式启用 vi
# 注意: zsh-vi-mode 不兼容 turbo 延迟加载，必须同步加载
zi ice wait"0" lucid atinit'
    ZVM_VI_INSERT_ESCAPE_BINDKEY="jj"
    ZVM_VI_MODE_RESET_PROMPT_ON_MODE_CHANGE=1
'
zi light jeffreytse/zsh-vi-mode


# 补全增强 & 补全初始化
zi ice wait"0a" lucid atload"zicompinit; zicdreplay" blockf
zi light zsh-users/zsh-completions

# MoonshotAI/zsh-kimi-cli
# zi light MoonshotAI/zsh-kimi-cli



# fzf 补全
zi ice wait"0d" lucid \
    atload'
        eval "$(fzf --zsh)"
    '
zi light Aloxaf/fzf-tab

# 历史记录插件
zi ice wait"0b" lucid \
    atload'
        eval "$(atuin init zsh)"
        bindkey "^R" _atuin_search_widget
    '
zi light atuinsh/atuin


# 自动建议 (zsh-sage: 多信号智能建议，替代 zsh-autosuggestions)
# 注意: zsh-vi-mode 把右箭头绑到 vi-forward-char，而 sage 包装的是 forward-char，
# 需要在 viins keymap 中显式把右箭头和 ^[; 绑到 forward-char（sage 已包装），
# 否则按右箭头不经过 sage 的 accept 逻辑。
zi ice wait"0c" lucid \
    atload'
        # main keymap（emacs 模式或非 vi 环境）
        bindkey "^[;" forward-char
        bindkey "^[[C" forward-char
        # vi-mode insert keymap 兼容
        bindkey -M viins "^[;" forward-char
        bindkey -M viins "^[[C" forward-char
        # Ctrl+Right 逐词接受（sage 包装了 forward-word）
        bindkey -M viins "^[[1;5C" forward-word

        # Ctrl+L: 有建议则接受，无建议则清屏
        # Ctrl+Alt+L: 清屏（原 Ctrl+L 行为）
        _sage_accept_or_clear() {
            emulate -L zsh
            if [[ -n "$_SAGE_CURRENT_SUGGESTION" ]]; then
                # forward-char 已被 sage 包装为接受建议的 widget
                zle forward-char
            else
                zle clear-screen
            fi
        }
        zle -N _sage_accept_or_clear
        bindkey "^L" _sage_accept_or_clear
        bindkey "^[^L" clear-screen
        bindkey -M viins "^L" _sage_accept_or_clear
        bindkey -M viins "^[^L" clear-screen
    '
zi light UtsavMandal2022/zsh-sage

# 高亮
#zi light z-shell/F-Sy-H


# 语法高亮
# zi ice wait"0e" lucid atinit"zpcompinit;zpcdreplay"
# zi light zdharma-continuum/fast-syntax-highlighting

# zsh-patina 必须在 zsh-vi-mode 初始化完成后再加载
# 原因: patina 与 zvm 都会包装 ZLE widget，若 patina 先加载，zvm 后加载时会
# 递归包装导致 "zvm_widget_wrapper: maximum nested function level reached"
# 通过 zvm_after_init 钩子确保 patina 在 zvm 之后激活
zvm_after_init() {
    eval "$(zsh-patina activate)"
}




# 加载 zoxide插件
export _ZO_DATA_DIR=$HOME/.local/share/zoxide
eval "$(zoxide init zsh --no-cmd)"
alias zl='zoxide query -i'
alias z='__zoxide_z'
alias c='print -z $(zl)'
unset zi




