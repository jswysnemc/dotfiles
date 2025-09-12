# ~/.zshrc

# =======================================================
# ==              递归展开别名的函数及快捷键 (V2)         ==
# =======================================================

# 步骤 1: 核心展开函数 (已更新)
expand_alias() {
  local cmd="$1"
  local expanded_cmd
  local alias_name
  local remaining_args
  local expanded_first_word
  local max_depth=100
  local current_depth=0

  if [[ -z "$cmd" ]]; then
    echo ""
    return 0
  fi

  while (( current_depth < max_depth )); do
    alias_name="${cmd%% *}"
    if [[ "$cmd" == "$alias_name" ]]; then
      remaining_args=""
    else
      remaining_args="${cmd#* }"
    fi

    if [[ -n "${aliases[$alias_name]}" ]]; then
      expanded_cmd="${aliases[$alias_name]}"

      # --- 新增的关键逻辑 ---
      expanded_first_word="${expanded_cmd%% *}"
      if [[ "$expanded_first_word" == "$alias_name" ]]; then
        if [[ -n "$remaining_args" ]]; then
          echo "$expanded_cmd $remaining_args"
        else
          echo "$expanded_cmd"
        fi
        return 0
      fi
      # --- 新增逻辑结束 ---

      if [[ -n "$remaining_args" ]]; then
        cmd="$expanded_cmd $remaining_args"
      else
        cmd="$expanded_cmd"
      fi
    else
      echo "$cmd"
      return 0
    fi
    (( current_depth++ ))
  done

  echo "已达到最大递归深度，可能存在循环别名: $1" >&2
  return 1
}



expand-alias-widget() {
  # BUFFER 变量包含了当前命令行缓冲区的完整内容
  local expanded_command
  expanded_command=$(expand_alias "$BUFFER")

  # 如果展开成功，则用展开后的命令替换当前缓冲区
  if [[ $? -eq 0 ]]; then
    BUFFER="$expanded_command"
  fi

  # 将光标移动到行尾
  zle .end-of-line
}

zle -N expand-alias-widget

bindkey '^x' expand-alias-widget
