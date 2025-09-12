# 测试速度时取消 以下一行 注释
# zmodload zsh/zprof


# 1. 在 .zshrc 的最顶部启动计时器
zmodload zsh/datetime
typeset -gF ZSH_START_TIME=$EPOCHREALTIME


# 预加载
[[ -f $HOME/.config/zsh/preload.zsh ]] && source $HOME/.config/zsh/preload.zsh

##############################
# -----------------------------------------------------------------------------
# 加载自定义配置目录
# -----------------------------------------------------------------------------
# Source all configuration files from the conf.d directory

for config_file in $HOME/.config/zsh/conf.d/*.zsh(N); do
  source "$config_file"
done
unset config_file

_handle_zsh_startup() {
  # ================= PART 1: 首次启动设置 =================
  # 检查初始计时器变量，这确保了这部分代码只在 shell 启动时运行一次
  if [[ -n "$ZSH_START_TIME" ]]; then
    typeset -F end_time=$EPOCHREALTIME
    typeset -F duration_ms=$(((end_time - ZSH_START_TIME) * 1000))

    # 设置数据变量，它将在此次 shell 会话中一直存在
    export STARSHIP_STARTUP_TIME=$(printf "%.0fms" $duration_ms)

    # 设置标志变量，仅用于告诉 Starship 第一次需要显示
    export STARSHIP_SHOW_STARTUP="true"

    # 用完后立即销毁初始计时器变量
    unset ZSH_START_TIME
    return
  fi

  # ================= PART 2: 显示后清理 =================
  # 如果上面的 if 没有执行，说明不是首次启动。
  # 我们检查标志变量是否存在。如果存在，说明 Starship 已经（或即将）
  # 显示过一次时间了，我们现在需要销毁这个标志，并让本函数不再运行。
  if [[ -n "$STARSHIP_SHOW_STARTUP" ]]; then
    unset STARSHIP_SHOW_STARTUP
    # 为了极致的效率，将此函数从 precmd 钩子中移除，因为它已完成使命。
    add-zsh-hook -d precmd _handle_zsh_startup
  fi
}

# 3. 将我们的函数添加到 precmd 钩子数组中
autoload -U add-zsh-hook
add-zsh-hook precmd _handle_zsh_startup


# 最后加载
[[ -f $HOME/.config/zsh/lastload.zsh ]] && source $HOME/.config/zsh/lastload.zsh

# 测速命令
#zprof

