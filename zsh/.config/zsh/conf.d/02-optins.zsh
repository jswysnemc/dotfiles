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
# 使用 ctrl + v 进入编辑器编辑当前命令，并在返回后同步光标位置
__edit_command_line_cursor_to_line_col() {
  emulate -L zsh

  local text="$1"
  local cursor="${2:-0}"
  local line=1
  local col=1
  local i
  local char

  (( cursor < 0 )) && cursor=0
  (( cursor > ${#text} )) && cursor=${#text}

  for (( i = 1; i <= cursor; ++i )); do
    char="${text[i]}"
    if [[ "$char" == $'\n' ]]; then
      (( line++ ))
      col=1
    else
      (( col++ ))
    fi
  done

  REPLY="${line}:${col}"
}

__edit_command_line_line_col_to_cursor() {
  emulate -L zsh

  local text="$1"
  local target_line="${2:-1}"
  local target_col="${3:-1}"
  local line=1
  local col=1
  local i
  local pos
  local char
  local last_same_line_pos=''

  (( target_line < 1 )) && target_line=1
  (( target_col < 1 )) && target_col=1

  for (( i = 1; i <= ${#text}; ++i )); do
    pos=$(( i - 1 ))

    if (( line == target_line )); then
      last_same_line_pos=$pos
      if (( col == target_col )); then
        REPLY=$pos
        return 0
      fi
    elif (( line > target_line )); then
      REPLY=${last_same_line_pos:-$pos}
      return 0
    fi

    char="${text[i]}"
    if [[ "$char" == $'\n' ]]; then
      (( line++ ))
      col=1
    else
      (( col++ ))
    fi
  done

  pos=${#text}
  if (( line == target_line )); then
    last_same_line_pos=$pos
    if (( col == target_col )); then
      REPLY=$pos
      return 0
    fi
  fi

  REPLY=${last_same_line_pos:-$pos}
}

edit-command-line() {
  emulate -L zsh
  setopt localoptions noaliases noshwordsplit

  local editor="${VISUAL:-${EDITOR:-vi}}"
  local -a editor_argv
  local editor_base
  local tmp_file
  local cursor_file
  local editor_exit
  local updated_buffer
  local cursor_state
  local line
  local col

  editor_argv=(${(z)editor})
  if (( ! ${#editor_argv} )); then
    zle -M 'EDITOR is empty'
    return 1
  fi

  tmp_file="$(mktemp -t zsh-edit-buffer.XXXXXX)" || {
    zle -M 'mktemp failed'
    return 1
  }
  cursor_file="${tmp_file}.cursor"
  print -rn -- "$BUFFER" >| "$tmp_file"

  __edit_command_line_cursor_to_line_col "$BUFFER" "$CURSOR"
  line="${REPLY%%:*}"
  col="${REPLY##*:}"
  editor_base="${editor_argv[1]:t}"

  zle -I

  case "$editor_base" in
    nvim|vim|vi)
      "${editor_argv[@]}" \
        -c "call setcharpos('.', [0, ${line}, ${col}, 0])" \
        -c "let g:zsh_edit_cursor_file='${cursor_file}'" \
        -c "augroup ZshEditCursor" \
        -c "autocmd! * <buffer>" \
        -c "autocmd CursorMoved,CursorMovedI,TextChanged,TextChangedI,BufEnter <buffer> call writefile([getcurpos()[1] . ':' . getcurpos()[2]], g:zsh_edit_cursor_file)" \
        -c "augroup END" \
        -c "call writefile([getcurpos()[1] . ':' . getcurpos()[2]], g:zsh_edit_cursor_file)" \
        "$tmp_file"
      editor_exit=$?
      ;;
    *)
      "${editor_argv[@]}" "$tmp_file"
      editor_exit=$?
      ;;
  esac

  if (( editor_exit == 0 )) && [[ -r "$tmp_file" ]]; then
    updated_buffer="$(<"$tmp_file")"
    BUFFER="$updated_buffer"

    if [[ -r "$cursor_file" ]]; then
      cursor_state="$(<"$cursor_file")"
      line="${cursor_state%%:*}"
      col="${cursor_state##*:}"
      if [[ "$line" == <-> && "$col" == <-> ]]; then
        __edit_command_line_line_col_to_cursor "$BUFFER" "$line" "$col"
        CURSOR="$REPLY"
      else
        CURSOR=${#BUFFER}
      fi
    else
      CURSOR=${#BUFFER}
    fi
  fi

  rm -f -- "$tmp_file" "$cursor_file"
  zle reset-prompt
}

zle -N edit-command-line

# zsh-vi-mode 下需要显式绑定到各个 keymap，否则在 vicmd 中会失效
bindkey -M main  '^V' edit-command-line
bindkey -M viins '^V' edit-command-line
bindkey -M vicmd '^V' edit-command-line
bindkey -M emacs '^V' edit-command-line
alias vl=edit-command-line

# 粘贴高亮修复
zle_highlight=('paste:none')


# ------------------- 基础补全配置 -------------------
# compinit 由 zi turbo (zicompinit) 统一处理，此处不再重复调用

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



# ------------------- 自动建议配置 -------------------
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_COMPLETION_IGNORE='( |man |pikaur -S )*'
ZSH_AUTOSUGGEST_HISTORY_IGNORE='?(#c50,)'


# ------------------- fzf-tab 快捷键与图标 -------------------
# zstyle ':fzf-tab:*' fzf-bindings '`:accept'
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
