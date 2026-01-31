# -----------------------------------------------------------------------------
# ENVIRONMENT & OPTIONS
# -----------------------------------------------------------------------------

# 目录相关
setopt AUTO_CD                # 输入目录名直接 cd
setopt EXTENDED_GLOB          # 启用高级文件匹配
setopt INTERACTIVE_COMMENTS   # 允许在交互式 shell 中使用 # 注释

# 性能监控
REPORTTIME=2                  # 超过2s的命令统计耗时

# ------------------- 快捷键配置 -------------------
# 使用 ctrl + v 进入 vim 行编辑模式
# [修复] 必须先加载模块，否则快捷键无效
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^v' edit-command-line
alias vl=edit-command-line

# 粘贴高亮修复
zle_highlight=('paste:none')


# ------------------- 基础补全配置 -------------------
# 加载补全模块
autoload -Uz compinit && compinit

zstyle ':completion:*' completer _expand _complete _ignored
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # 忽略大小写
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no


# ------------------- Kill 命令专属配置 (修复版) -------------------

# 1. [修复] 让补全列表显示当前用户的所有进程，而不仅仅是当前 session 的任务
#    -u $USER: 仅当前用户
#    -o ...  : 指定显示格式 (PID, 用户, 启动命令)
zstyle ':completion:*:*:kill:*:processes' command "ps -u $USER -o pid,user,comm -w -w"

# 2. [美化] 给进程列表的 PID 加上红色，更醒目
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'

# 3. [修复] Kill 命令的 fzf-tab 预览
#    增加了 2>/dev/null，防止选中 PID 0 或进程已结束时报错
zstyle ':fzf-tab:complete:kill:argument-rest' fzf-preview \
  '[[ $word =~ ^[0-9]+$ ]] && ps --pid=$word -o cmd --no-headers -w -w 2>/dev/null || echo "Process info not available"'
zstyle ':fzf-tab:complete:kill:argument-rest' fzf-flags '--preview-window=down:3:wrap'
zstyle ':fzf-tab:complete:kill:*' popup-pad 0 3


# ------------------- fzf-tab 通用配置 -------------------
zstyle ':fzf-tab:*' use-fzf-default-opts yes

# 目录预览 (ls)
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color=always $realpath'
zstyle ':fzf-tab:complete:cd:*' popup-pad 30 0
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color=always $realpath'
zstyle ':fzf-tab:complete:z:*' fzf-preview 'ls --color=always $realpath'

# 快捷键
zstyle ':fzf-tab:*' fzf-bindings '`:accept'
zstyle ':fzf-tab:*' switch-group '<' '>'


# ------------------- 自动建议配置 -------------------
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_COMPLETION_IGNORE='( |man |pikaur -S )*'
ZSH_AUTOSUGGEST_HISTORY_IGNORE='?(#c50,)'


# ------------------- fzf-tab 快捷键与图标 -------------------
zstyle ':fzf-tab:*' fzf-bindings '`:accept'
# 替换默认的 < > 为更漂亮的 Nerd Font 箭头
zstyle ':fzf-tab:*' switch-group '' ''
# ------------------- fzf 界面配置 (Nerd Font 版) -------------------
# 图标说明：
# prompt  (λ ->):  (nf-fa-angle_right) 或者  (nf-fa-search)
# pointer (▷)   :  (nf-fa-caret_right) 或者  (nf-oct-chevron_right)
# marker  (✓)   :  (nf-fa-check_circle)
export FZF_DEFAULT_OPTS="
--ansi
--layout=reverse
--info=inline
--height=50%
--multi
--cycle
--preview-window=right:50%
--preview-window=cycle
--prompt='  '
--pointer=''
--marker=' '
--header='CTRL-J/K to move'
--color=bg+:236,gutter:-1,fg:-1,bg:-1,hl:-1,hl+:-1
--color=prompt:110,pointer:161,marker:118,spinner:214,header:240
"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
