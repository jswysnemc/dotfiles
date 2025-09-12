# 加载 zsh 的 高亮 man 和 sudo 插件
zi snippet OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh
zi snippet OMZ::plugins/sudo/sudo.plugin.zsh

# zi light hlissner/zsh-autopair


# vimode 插件， 在行编辑模式启用 vi
zi ice atinit'
    ZVM_VI_INSERT_ESCAPE_BINDKEY="jj"
    ZVM_VI_MODE_RESET_PROMPT_ON_MODE_CHANGE=1
'
zi light jeffreytse/zsh-vi-mode


# 补全增强 & 补全初始化
zi ice wait"0a" lucid atload"zicompinit; zicdreplay" blockf
zi light zsh-users/zsh-completions



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


# 自动建议
zi ice wait"0c" lucid \
    atload'
        _zsh_autosuggest_start
        bindkey "\`" autosuggest-accept
    '
zi light zsh-users/zsh-autosuggestions

# 高亮
#zi light z-shell/F-Sy-H


# 语法高亮
zi ice wait"0e" lucid atinit"zpcompinit;zpcdreplay"
zi light zdharma-continuum/fast-syntax-highlighting

# 加载 zoxide插件
export _ZO_DATA_DIR=$HOME/.local/share/zoxide
eval "$(zoxide init zsh --no-cmd)"
alias zl='zoxide query -i'
alias z='__zoxide_z'
alias c='print -z $(zl)'
unset zi

