# -----------------------------------------------------------------------------
# ENVIRONMENT & OPTIONS
# -----------------------------------------------------------------------------

# 目录相关
setopt AUTO_CD                # 如果输入一个目录名，直接 `cd` 进去
#setopt AUTO_PUSHD             # 自动将 `cd` 过的目录放入目录栈 (方便用 `dirs -v` 查看和 `cd -N` 跳转)
#setopt PUSHD_IGNORE_DUPS      # 不要将重复的目录放入目录栈``

# 其他交互
setopt EXTENDED_GLOB          # 启用更强大的文件匹配模式 (例如 `^` 排除, `#` 递归)
#setopt NOTIFY                 # 立即报告后台任务的状态变化，而不是等下一次回车
#setopt NO_BEEP                # 关闭所有烦人的蜂鸣声
#setopt LONGLISTJOBS           # 使用 `jobs` 命令时显示任务的 PID
setopt INTERACTIVE_COMMENTS

# 超过3s的命令统计耗时
REPORTTIME=2

# 使用ctrl + v 进入 vim 行编辑模式
bindkey '^v' edit-command-line
alias vl=edit-command-line


# 粘贴相关
zle_highlight=('paste:none')


# ------------------- 补全配置 -------------------
# 基础补全设置
zstyle ':completion:*' completer _expand _complete _ignored
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no

# fzf-tab 基础设置
zstyle ':fzf-tab:*' use-fzf-default-opts yes


# fzf-tab 预览设置
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls $realpath'
zstyle ':fzf-tab:complete:cd:*' popup-pad 30 0
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls $realpath'
zstyle ':fzf-tab:complete:z:*' fzf-preview 'ls $realpath'

# 进程补全预览
zstyle ':fzf-tab:complete:kill:argument-rest' fzf-preview '[[ "$word" =~ ^[0-9]+$ ]] && ps --pid=$word -o cmd --no-headers -w -w'
zstyle ':fzf-tab:complete:kill:argument-rest' fzf-flags '--preview-window=down:3:wrap'
zstyle ':fzf-tab:complete:kill:*' popup-pad 0 3


# fzf-tab 快捷键
zstyle ':fzf-tab:*' fzf-bindings '`:accept'
zstyle ':fzf-tab:*' switch-group '<' '>'



# ------------------- 自动建议配置 -------------------
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_COMPLETION_IGNORE='( |man |pikaur -S )*'
ZSH_AUTOSUGGEST_HISTORY_IGNORE='?(#c50,)'


# ------------------- fzf 配置 -------------------
export FZF_DEFAULT_OPTS="
--ansi
--layout=reverse
--info=inline
--height=50%
--multi
--cycle
--preview-window=right:50%
--preview-window=cycle
--prompt='λ -> '
--pointer='▷'
--marker='✓'
--color=bg+:236,gutter:-1,fg:-1,bg:-1,hl:-1,hl+:-1,prompt:-1,pointer:105,marker:-1,spinner:-1
"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
