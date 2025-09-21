export PATH=$HOME/.custom/bin:$PATH
export PATH=$PATH:$HOME/.local/share/cargo/bin

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end


[[ -f $HOME/.ssh/keys/keys.env ]] && source $HOME/.ssh/keys/keys.env
