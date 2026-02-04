# shellcheck shell=bash

command_exists() {
    command -v "$1" &> /dev/null
}

# Run command with spinner
exe() {
    local cmd="$*"
    local spin_chars='|/-\'
    local spin_pid

    # Start spinner
    (
        local i=0
        while true; do
            printf "\r   ${YELLOW}[%c]${NC} Running..." "${spin_chars:$i:1}"
            i=$(( (i + 1) % 4 ))
            sleep 0.1
        done
    ) &
    spin_pid=$!

    # Run command
    local result=0
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        result=0
    else
        result=1
    fi

    # Stop spinner
    kill "$spin_pid" 2>/dev/null
    wait "$spin_pid" 2>/dev/null || true
    printf "\r\033[K"

    return $result
}

# Run with live output
exe_live() {
    local msg="$1"
    shift
    local cmd="$*"

    echo ""
    echo -e "   ${CYAN}>>>${NC} ${WHITE}$msg${NC}"
    echo -e "   ${DIM}\$ $cmd${NC}"
    echo ""

    if eval "$cmd" 2>&1 | tee -a "$LOG_FILE"; then
        echo ""
        print_ok "$msg"
        return 0
    else
        echo ""
        print_fail "$msg"
        return 1
    fi
}
