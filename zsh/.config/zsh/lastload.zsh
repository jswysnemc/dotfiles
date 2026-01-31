# 在 tty 环境启用简化 prompt  其他环境启用 正常prompt
[[ -t 1 && "$TERM" != "linux" ]] && eval "$(starship init zsh)" || PROMPT=$'%F{cyan}[%(!.%F{red}.%f)%n%F{cyan}@%m]%f %F{yellow}%~%f
%F{green}%(!.#.$) %f'
