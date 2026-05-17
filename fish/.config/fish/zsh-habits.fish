# Environment and command defaults migrated from the zsh setup.
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx TERMINAL ghostty
set -gx CRYPTOGRAPHY_OPENSSL_NO_LEGACY 1
set -gx PNPM_HOME "$HOME/.local/share/pnpm"

fish_add_path --global "$HOME/.custom/bin" "$PNPM_HOME" "$HOME/.local/bin" "$HOME/.local/share/cargo/bin"

# Colored man pages, equivalent to the OMZ colored-man-pages plugin.
set -gx LESS_TERMCAP_mb (printf '\e[1;31m')
set -gx LESS_TERMCAP_md (printf '\e[1;31m')
set -gx LESS_TERMCAP_me (printf '\e[0m')
set -gx LESS_TERMCAP_se (printf '\e[0m')
set -gx LESS_TERMCAP_so (printf '\e[01;44;33m')
set -gx LESS_TERMCAP_ue (printf '\e[0m')
set -gx LESS_TERMCAP_us (printf '\e[1;32m')

# fzf visual defaults from the zsh config.
set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -gx FZF_CTRL_R_COMMAND ''
set -gx FZF_DEFAULT_OPTS "
--ansi
--layout=reverse
--info=inline
--height=50%
--multi
--cycle
--bind=tab:down,btab:up,ctrl-space:toggle
--preview-window=right:50%
--preview-window=cycle
--prompt='  '
--pointer=''
--marker=' '
--header='CTRL-J/K to move'
--color=bg+:236,gutter:-1,fg:-1,bg:-1,hl:-1,hl+:-1
--color=prompt:110,pointer:161,marker:118,spinner:214,header:240
"

function export_from_file
    set -l var_name $argv[1]
    set -l file_path $argv[2]
    set -l fallback_value $argv[3]

    if test -z "$var_name" -o -z "$file_path"
        echo "Usage: export_from_file <var_name> <file_path> [fallback_value]" >&2
        return 1
    end

    set -l content "$fallback_value"
    if test -r "$file_path"
        set content (string collect <"$file_path")
    end

    set -gx $var_name "$content"
end

function cv
    if test (count $argv) -eq 0
        echo "Usage: cv <file>" >&2
        return 1
    end

    set -l file $argv[1]
    command touch "$file"; or return
    printf '' >"$file"
    command $EDITOR "$file"
end

function y
    set -l tmp (mktemp -t yazi-cwd.XXXXXX)
    command yazi $argv --cwd-file="$tmp"
    set -l cwd (command cat -- "$tmp" 2>/dev/null)

    if test -n "$cwd" -a "$cwd" != "$PWD"
        builtin cd -- "$cwd"
    end

    command rm -f -- "$tmp"
end

function proxy
    switch "$argv[1]"
        case on
            set -gx http_proxy "http://127.0.0.1:7897"
            set -gx https_proxy "http://127.0.0.1:7897"
            set -gx all_proxy "socks5://127.0.0.1:7897"
            set -gx HTTP_PROXY "$http_proxy"
            set -gx HTTPS_PROXY "$https_proxy"
            set -gx ALL_PROXY "$all_proxy"
            echo "Proxy is ON"
            echo "http_proxy: $http_proxy"
            echo "https_proxy: $https_proxy"
            echo "all_proxy: $all_proxy"
        case off
            set -e http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
            echo "Proxy is OFF"
        case status
            if test -n "$http_proxy$HTTP_PROXY"
                echo "Proxy is ON"
                echo "--------------------"
                echo "http_proxy: "(set -q http_proxy; and echo $http_proxy; or echo "Not set")
                echo "https_proxy: "(set -q https_proxy; and echo $https_proxy; or echo "Not set")
                echo "all_proxy: "(set -q all_proxy; and echo $all_proxy; or echo "Not set")
                echo "--------------------"
                echo "HTTP_PROXY: "(set -q HTTP_PROXY; and echo $HTTP_PROXY; or echo "Not set")
                echo "HTTPS_PROXY: "(set -q HTTPS_PROXY; and echo $HTTPS_PROXY; or echo "Not set")
                echo "ALL_PROXY: "(set -q ALL_PROXY; and echo $ALL_PROXY; or echo "Not set")
            else
                echo "Proxy is OFF"
            end
        case '*'
            echo "Usage: proxy [on|off|status]"
            return 1
    end
end

function any
    if test (count $argv) -eq 0
        echo "any - grep for process(es) by keyword" >&2
        echo "Usage: any <keyword>" >&2
        return 1
    end

    set -l keyword $argv[1]
    set -l first (string sub -s 1 -l 1 -- "$keyword")
    set -l rest (string sub -s 2 -- "$keyword")
    ps xauwww | grep -i --color=auto "[$first]$rest"
end

function arkh
    set -l c_reset (set_color normal)
    set -l c_bold (set_color --bold)
    set -l c_cmd (set_color cyan)
    set -l c_file (set_color yellow)
    set -l c_info (set_color green)
    set -l c_error (set_color red)

    if test (count $argv) -eq 0; or contains -- "$argv[1]" -h --help
        printf "%sArk - Fish Archive Helper%s\n" "$c_bold" "$c_reset"
        echo "Shows you the command to compress or decompress files."
        echo
        printf "%sUSAGE:%s\n" "$c_bold" "$c_reset"
        printf "  arkh %s<action>%s %s<archive_name>%s [files_to_add...]\n" "$c_info" "$c_reset" "$c_file" "$c_reset"
        echo
        printf "%sACTIONS:%s\n" "$c_bold" "$c_reset"
        printf "  %sc, create%s    Show command to CREATE an archive.\n" "$c_info" "$c_reset"
        printf "  %sx, extract%s   Show command to EXTRACT an archive.\n" "$c_info" "$c_reset"
        echo
        printf "%sEXAMPLES:%s\n" "$c_bold" "$c_reset"
        echo "  arkh c my_stuff.tar.gz file1.txt documents/"
        echo "  arkh x my_stuff.tar.gz"
        return 0
    end

    set -l action $argv[1]
    set -l archive_name $argv[2]
    set -l cmd_string

    switch "$action"
        case c create
            if test (count $argv) -lt 3
                printf "%sError: 'create' action requires an archive name and at least one file to add.%s\n" "$c_error" "$c_reset"
                return 1
            end

            set -l files_to_add (string join ' ' -- $argv[3..-1])
            printf "To %sCREATE%s archive %s%s%s with your files:\n" "$c_bold" "$c_reset" "$c_file" "$archive_name" "$c_reset"

            switch "$archive_name"
                case '*.tar.gz' '*.tgz'
                    set cmd_string "tar -czvf $archive_name $files_to_add"
                case '*.tar.bz2' '*.tbz2'
                    set cmd_string "tar -cjvf $archive_name $files_to_add"
                case '*.tar.xz' '*.txz'
                    set cmd_string "tar -cJvf $archive_name $files_to_add"
                case '*.zip'
                    set cmd_string "zip -r $archive_name $files_to_add"
                case '*.rar'
                    set cmd_string "rar a $archive_name $files_to_add"
                case '*.7z'
                    set cmd_string "7z a $archive_name $files_to_add"
                case '*.tar'
                    set cmd_string "tar -cvf $archive_name $files_to_add"
                case '*'
                    printf "%sUnsupported archive format for creation: '%s'%s\n" "$c_error" "$archive_name" "$c_reset"
                    return 1
            end
        case x extract
            if test (count $argv) -ne 2
                printf "%sError: 'extract' action requires exactly one archive name.%s\n" "$c_error" "$c_reset"
                return 1
            end

            printf "To %sEXTRACT%s archive %s%s%s:\n" "$c_bold" "$c_reset" "$c_file" "$archive_name" "$c_reset"

            switch "$archive_name"
                case '*.tar.gz' '*.tgz'
                    set cmd_string "tar -xzvf $archive_name"
                case '*.tar.bz2' '*.tbz2'
                    set cmd_string "tar -xjvf $archive_name"
                case '*.tar.xz' '*.txz'
                    set cmd_string "tar -xJvf $archive_name"
                case '*.zip'
                    set cmd_string "unzip $archive_name"
                case '*.rar'
                    set cmd_string "unrar x $archive_name"
                case '*.7z'
                    set cmd_string "7z x $archive_name"
                case '*.tar'
                    set cmd_string "tar -xvf $archive_name"
                case '*.gz'
                    set cmd_string "gunzip $archive_name"
                case '*.bz2'
                    set cmd_string "bunzip2 $archive_name"
                case '*.xz'
                    set cmd_string "unxz $archive_name"
                case '*'
                    printf "%sUnsupported archive format for extraction: '%s'%s\n" "$c_error" "$archive_name" "$c_reset"
                    return 1
            end
        case '*'
            printf "%sError: Unknown action '%s'. Use 'c' or 'x'.%s\n" "$c_error" "$action" "$c_reset"
            return 1
    end

    echo
    printf "  %s%s%s\n" "$c_cmd" "$cmd_string" "$c_reset"
    echo
end

function ...
    builtin cd ../..
end

function ....
    builtin cd ../../..
end

function k
    set -l pid (ps aux | fzf --height 40% --reverse | awk '{print $2}')
    test -n "$pid"; and command kill -9 $pid
end

function css
    set -l session (chat --no-color session list | fzf | awk '{print ($1=="*" ? $2 : $1)}')
    test -n "$session"; and chat session switch "$session"
end

function ccm
    set -l model (chat config model list | fzf)
    test -n "$model"; and chat config model use "$model"
end

function wshowkeys
    command nohup wshowkeys -a bottom -F 'Sans Bold 30' -s '#B5B520ff' -f '#ecd29cff' -b '#201B1488' -l 60 >/dev/null 2>&1 &
end

function uvr
    command "$HOME/.conda/envs/uvr5/bin/python" "$HOME/.local/share/uvr5/ultimatevocalremovergui/UVR.py" $argv
end

function indextts
    command indextts --model_dir "$HOME/.local/share/index-tts/index-tts/checkpoints" -c "$HOME/.local/share/index-tts/index-tts/checkpoints/config.yaml" $argv
end

function tssh
    command ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $argv
end

function vl
    edit_command_buffer
end

alias v='nvim'
alias nv='nvim'
alias vi='nvim'
alias vim='nvim'
alias sd='sudoedit'
alias psr='podman stop linux-teaching-env && podman rm linux-teaching-env'
alias pr='podman run -it --name linux-teaching-env --dns=114.114.114.114 docker.io/library/archlinux:latest /bin/bash'
alias npm='pnpm'
alias yay='paru'
alias gc='git clone'
alias lg='lazygit'
alias ca='chat ask --stream'
alias cn='chat ask --stream --new-session'
alias ct='chat ask --stream --new-session --temp'
alias cgt='chat ask --stream --new-session --temp --model grok-4-20-fast --provider grok2api'
alias cga='chat ask --stream --model grok-4-20-fast --provider grok2api'
alias cgn='chat ask --stream --new-session --model grok-4-20-fast --provider grok2api'
alias claude='claude --dangerously-skip-permissions'
alias ssta='systemctl status'
alias sstr='systemctl start'
alias ssen='systemctl enable'
alias sstp='systemctl stop'
alias kk='kitty +kitten'
alias ffd='find /usr/share/applications ~/.local/share/applications -name "*.desktop" 2>/dev/null'
alias s='source ~/.config/fish/config.fish'

if test "$TERM" = xterm-kitty
    function ssh --wraps ssh
        command kitty +kitten ssh $argv
    end
end

if command -q eza
    alias ls='eza --git -g'
    alias l='eza -l --git -g'
    alias la='eza -la --git -g'
    alias lls='eza --icons --git -g'
    alias lla='eza --icons --git -g -al'
    alias ll='eza -la --header --icons --git -g'
    alias llt='eza -la --header --icons --git -g -s modified'
    alias llS='eza -la --header --icons --git -g -s size'
    alias tree2='eza --tree --level=2 --icons -g'
end

if test -f /opt/miniconda3/etc/fish/conf.d/conda.fish
    function conda
        functions -e conda
        source /opt/miniconda3/etc/fish/conf.d/conda.fish
        conda $argv
    end
end

function __fish_alias_replacement
    switch "$argv[1]"
        case v nv vi vim
            echo nvim
        case sd
            echo sudoedit
        case psr
            echo 'podman stop linux-teaching-env && podman rm linux-teaching-env'
        case pr
            echo 'podman run -it --name linux-teaching-env --dns=114.114.114.114 docker.io/library/archlinux:latest /bin/bash'
        case npm
            echo pnpm
        case yay
            echo paru
        case gc
            echo 'git clone'
        case lg
            echo lazygit
        case ca
            echo 'chat ask --stream'
        case cn
            echo 'chat ask --stream --new-session'
        case ct
            echo 'chat ask --stream --new-session --temp'
        case cgt
            echo 'chat ask --stream --new-session --temp --model grok-4-20-fast --provider grok2api'
        case cga
            echo 'chat ask --stream --model grok-4-20-fast --provider grok2api'
        case cgn
            echo 'chat ask --stream --new-session --model grok-4-20-fast --provider grok2api'
        case claude
            echo 'claude --dangerously-skip-permissions'
        case ssta
            echo 'systemctl status'
        case sstr
            echo 'systemctl start'
        case ssen
            echo 'systemctl enable'
        case sstp
            echo 'systemctl stop'
        case kk
            echo 'kitty +kitten'
        case ffd
            echo 'find /usr/share/applications ~/.local/share/applications -name "*.desktop" 2>/dev/null'
        case s
            echo 'source ~/.config/fish/config.fish'
        case ls
            echo 'eza --git -g'
        case l
            echo 'eza -l --git -g'
        case la
            echo 'eza -la --git -g'
        case lls
            echo 'eza --icons --git -g'
        case lla
            echo 'eza --icons --git -g -al'
        case ll
            echo 'eza -la --header --icons --git -g'
        case llt
            echo 'eza -la --header --icons --git -g -s modified'
        case llS
            echo 'eza -la --header --icons --git -g -s size'
        case tree2
            echo 'eza --tree --level=2 --icons -g'
    end
end

function __fish_expand_alias
    set -l cmd (string trim -- "$argv")

    if not string length -q -- "$cmd"
        echo
        return 0
    end

    for depth in (seq 1 100)
        set -l split_cmd (string split -m1 ' ' -- "$cmd")
        set -l alias_name $split_cmd[1]
        set -l remaining_args

        if test (count $split_cmd) -gt 1
            set remaining_args $split_cmd[2]
        end

        set -l expanded (__fish_alias_replacement "$alias_name")
        if not string length -q -- "$expanded"
            echo "$cmd"
            return 0
        end

        if test "$expanded" = "$alias_name"
            echo "$cmd"
            return 0
        end

        if string length -q -- "$remaining_args"
            set cmd "$expanded $remaining_args"
        else
            set cmd "$expanded"
        end
    end

    echo "已达到最大递归深度，可能存在循环别名: $argv" >&2
    return 1
end

function __fish_expand_alias_widget
    set -l expanded (__fish_expand_alias (commandline -b) | string collect)
    if test $status -eq 0
        commandline -r -- "$expanded"
        commandline -C 999999
    end
    commandline -f repaint
end

function __fish_cmdh_expand
    set -l query "$argv"

    if not string length -q -- "$query"
        echo
        return 0
    end

    if not test -x "$HOME/.custom/bin/cmdh"
        echo "$query"
        return 1
    end

    set -l cmdh_output ($HOME/.custom/bin/cmdh "$query" 2>/dev/null | string collect)
    if test $status -eq 0 -a -n "$cmdh_output"
        set -l command_only (printf "%s\n" "$cmdh_output" | sed -n '/^[[:space:]]*#/,$p' | grep -v '^[[:space:]]*#' | head -1)
        if string length -q -- "$command_only"
            echo "$command_only"
            return 0
        end
    end

    echo "$query"
    return 1
end

function __fish_cmdh_expand_widget
    set -l current_input (commandline -b | string collect)

    if not string length -q -- "$current_input"
        return 0
    end

    set -l expanded (__fish_cmdh_expand "$current_input" | string collect)
    if test $status -eq 0
        commandline -r -- "$expanded"
        commandline -C 999999
    end

    commandline -f repaint
end

function fish_user_key_bindings
    bind -M insert j,j 'set fish_bind_mode default; commandline -f repaint-mode'
    bind -M insert alt-\; accept-autosuggestion
    bind -M default alt-\; accept-autosuggestion
    bind -M insert alt-s 'fish_commandline_prepend sudo'
    bind -M default alt-s 'fish_commandline_prepend sudo'
    bind -M insert ctrl-v edit_command_buffer
    bind -M default ctrl-v edit_command_buffer
    bind -M insert ctrl-x __fish_expand_alias_widget
    bind -M default ctrl-x __fish_expand_alias_widget
    bind -M insert ctrl-g __fish_cmdh_expand_widget
    bind -M default ctrl-g __fish_cmdh_expand_widget
end

set -g fish_key_bindings fish_vi_key_bindings
fish_vi_key_bindings
fish_user_key_bindings

if command -q fzf
    fzf --fish | source
end

if command -q zoxide
    set -gx _ZO_DATA_DIR "$HOME/.local/share/zoxide"
    zoxide init fish --no-cmd | source
    alias z='__zoxide_z'

    function zl
        zoxide query -i $argv
    end

    function c
        set -l selected (zoxide query -i $argv)
        or return

        if status is-interactive
            commandline -r -- (string escape -- "$selected")
            commandline -f repaint
        else
            echo "$selected"
        end
    end
end

if command -q atuin
    atuin init fish | source
end
