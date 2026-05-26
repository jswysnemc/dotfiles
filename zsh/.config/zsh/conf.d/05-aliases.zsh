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
alias uvr='$HOME/.conda/envs/uvr5/bin/python $HOME/.local/share/uvr5/ultimatevocalremovergui/UVR.py'
alias tssh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
alias npm=pnpm
alias yay=paru
alias k="ps aux | fzf --height 40% --reverse | awk '{print $2}' | xargs kill -9"
alias gc="git clone"
alias lg="lazygit"
alias ca="chat ask --stream"
alias cn="chat ask --stream --new-session"
alias ct="chat ask --stream --new-session --temp"
alias cgt="chat ask --stream --new-session --temp --model grok-4-20-fast --provider grok2api"
alias cga="chat ask --stream --model grok-4-20-fast --provider grok2api"
alias cgn="chat ask --stream --new-session --model grok-4-20-fast --provider grok2api"
alias ccm="chat config model use \`chat config model list| fzf\`"

css() {
    chat session switch "$(chat --no-color session list | fzf | awk '{print ($1=="*" ? $2 : $1)}')"
}

wshowkeys() {
    local cmd=${commands[wshowkeys]:-/usr/bin/wshowkeys}
    local -a opts=(
        -a bottom
        -a right
        -m 20
        -F 'Sans Bold 30'
        -s '#B5B520ff'
        -f '#ecd29cff'
        -b '#201B1488'
        -l 60
        # -t 的单位是毫秒；5000 表示 5 秒。
        -t 5000
    )

    if [[ ! -x "$cmd" ]]; then
        echo "wshowkeys 未安装: $cmd" >&2
        return 127
    fi

    if pgrep -U "$USER" -x "wshowkeys" >/dev/null; then
        pkill -U "$USER" -x "wshowkeys"
        echo "wshowkeys 已关闭"
    else
        nohup "$cmd" "${opts[@]}" > /dev/null 2>&1 &
        echo "wshowkeys 已在后台启动"
    fi
}

alias xo="xdg-open"

# 如果你在仓库中看到这个别名,别学我
alias claude="claude --dangerously-skip-permissions"

# systemctl 相关短别名
alias ssta="systemctl status"
alias sstr="systemctl start"
alias ssen="systemctl enable"
alias sstp="systemctl stop"

alias zl='zoxide query -i' # z + Enter 打开 fzf 交互界面
alias c='print -z $(zl)'

# Kitty terminal enhancements
alias kk="kitty +kitten"
[ "$TERM" = "xterm-kitty" ] && alias ssh="kitty +kitten ssh"

# Application launchers
alias ffd="find /usr/share/applications ~/.local/share/applications -name \"*.desktop\" 2>/dev/null"

# source zshrc
alias s="source ~/.config/zsh/.zshrc"
