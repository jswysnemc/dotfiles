# eval "$(starship init zsh)"
#




[[ -t 1 && "$TERM" != "linux" ]] && eval "$(starship init zsh)" || PROMPT=$'%F{cyan}[%(!.%F{red}.%f)%n%F{cyan}@%m]%f %F{yellow}%~%f
%F{green}%(!.#.$) %f'
