alias ...='cd ../..'
alias ....='cd ../../..'

function any () {
    emulate -L zsh
    unsetopt KSH_ARRAYS
    if [[ -z "$1" ]] ; then
        echo "any - grep for process(es) by keyword" >&2
        echo "Usage: any <keyword>" >&2 ; return 1
    else
        ps xauwww | grep -i --color=auto "[${1[1]}]${1[2,-1]}"
    fi
}


function sudo-command-line () {
    [[ -z $BUFFER ]] && zle up-history
    local cmd="sudo "
    if [[ ${BUFFER} == ${cmd}* ]]; then
        CURSOR=$(( CURSOR-${#cmd} ))
        BUFFER="${BUFFER#$cmd}"
    else
        BUFFER="${cmd}${BUFFER}"
        CURSOR=$(( CURSOR+${#cmd} ))
    fi
    zle reset-prompt
}
zle -N sudo-command-line
bindkey '^[s' sudo-command-line



