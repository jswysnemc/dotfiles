# eval "$(starship init zsh)"


[[ -t 1 && "$TERM" != "linux" ]] && eval "$(starship init zsh)" || PROMPT=$'%B%F{cyan}[%m@%n]%f%b %B%F{yellow}%d%f%b\n%B%F{green}%#%f%b '
