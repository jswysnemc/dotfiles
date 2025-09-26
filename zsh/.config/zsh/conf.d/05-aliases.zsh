# -----------------------------------------------------------------------------
# ALIASES
# -----------------------------------------------------------------------------

# Navigation and Editors
alias v='nvim'
alias nv='nvim'
alias vi='nvim'
alias vim='nvim'
alias sd='sudoedit'
alias psr='podman stop linux-teaching-env && podman rm linux-teaching-env'
alias pr='podman run -it --name linux-teaching-env --dns=114.114.114.114 docker.io/library/archlinux:latest /bin/bash'
alias indextts='indextts --model_dir ~/.local/share/index-tts/index-tts/checkpoints -c ~/.local/share/index-tts/index-tts/checkpoints/config.yaml'
alias wshowkeys="nohup wshowkeys -a bottom -F 'Sans Bold 30' -s '#B5B520ff' -f  '#ecd29cff' -b '#201B1488' -l 60  > /dev/null 2>&1 &"
alias uvr='/home/snemc/.conda/envs/uvr5/bin/python /home/snemc/.local/share/uvr5/ultimatevocalremovergui/UVR.py'
alias tssh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
alias npm=pnpm
alias k="ps aux | fzf --height 40% --reverse | awk '{print $2}' | xargs kill -9"
alias gc="git clone"
alias lg="lazygit"
alias cl="claude"
alias cc="ccr code"
alias cu="ccr ui"

# systemctl 相关短别名
alias ssa="systemctl status"
alias sss="systemctl start"
alias sse="systemctl enable"
alias sst="systemctl stop"

alias zl='zoxide query -i' # z + Enter 打开 fzf 交互界面
alias c='print -z $(zl)'

# Kitty terminal enhancements
alias kk="kitty +kitten"
[ "$TERM" = "xterm-kitty" ] && alias ssh="kitty +kitten ssh"

# Application launchers
alias ffd="find /usr/share/applications ~/.local/share/applications -name \"*.desktop\" 2>/dev/null"

# source zshrc
alias s="source ~/.config/zsh/.zshrc"

# 更新所有 ai 工具
alias puai='pnpm install -g  @anthropic-ai/claude-code  @musistudio/claude-code-router  @google/gemini-cli @openai/codex  @iflow-ai/iflow-cli@latest'
