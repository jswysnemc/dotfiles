# ~/.zshrc

# =======================================================
# ==              cmdh命令展开函数及快捷键             ==
# =======================================================

# 步骤 1: 核心cmdh展开函数
cmdh-expand() {
  local query="$1"
  local cmdh_output
  
  if [[ -z "$query" ]]; then
    echo ""
    return 0
  fi
  
  # 调用cmdh脚本获取命令建议
  cmdh_output=$(~/.custom/bin/cmdh "$query" 2>/dev/null)
  
  # 检查cmdh是否成功返回结果
  if [[ $? -eq 0 && -n "$cmdh_output" ]]; then
    # 过滤掉#行之前的所有输出，只保留从#行开始的内容
    local filtered_output
    filtered_output=$(echo "$cmdh_output" | sed -n '/^[[:space:]]*#/,$p')
    
    if [[ -n "$filtered_output" ]]; then
      # 移除注释行（以#开头的行），只保留实际的命令
      local command_only
      command_only=$(echo "$filtered_output" | grep -v '^[[:space:]]*#' | head -1)
      
      if [[ -n "$command_only" ]]; then
        echo "$command_only"
      else
        # 如果没有找到命令行，返回原始输入
        echo "$query"
      fi
    else
      echo "$query"
    fi
    return 0
  else
    echo "$query"
    return 1
  fi
}

# 步骤 2: 创建zle widget函数
cmdh-expand-widget() {
  # BUFFER 变量包含了当前命令行缓冲区的完整内容
  local current_input="$BUFFER"
  
  if [[ -z "$current_input" ]]; then
    return 0
  fi
  
  # 调用cmdh展开函数
  local expanded_command
  expanded_command=$(cmdh-expand "$current_input")
  
  # 如果展开成功，则用展开后的命令替换当前缓冲区
  if [[ $? -eq 0 ]]; then
    BUFFER="$expanded_command"
  fi
  
  # 将光标移动到最后一行的最后一个字符后面
  zle .end-of-line
}

# 注册zle widget
zle -N cmdh-expand-widget

# 绑定快捷键到 Ctrl+g
bindkey '^g' cmdh-expand-widget