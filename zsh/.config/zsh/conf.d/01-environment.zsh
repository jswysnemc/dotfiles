export PATH=$HOME/.custom/bin:$PATH
export PATH=$PATH:$HOME/.local/share/cargo/bin
export PATH=$PATH:$HOME/.local/bin

export TERMINAL="kitty --single-instance --instance-group=main"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
export PATH=$HOME/.local/share/pnpm/bin:$PATH


[[ -f $HOME/.ssh/keys/keys.env ]] && source $HOME/.ssh/keys/keys.env
