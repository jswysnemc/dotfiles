# shellcheck shell=bash

# ==============================================================================
# ASCII Banners
# ==============================================================================
banner1() {
cat << "BANNER"
    ____        __  _____ __
   / __ \____  / /_/ __(_) /__  _____
  / / / / __ \/ __/ /_/ / / _ \/ ___/
 / /_/ / /_/ / /_/ __/ / /  __(__  )
/_____/\____/\__/_/ /_/_/\___/____/
BANNER
}

banner2() {
cat << "BANNER"
 ___   ___ ___ ___ ___ _    ___ ___
|   \ / _ \_  _| __|_ _| |  | __/ __|
| |) | (_) || || _| | || |__| _|\__ \
|___/ \___/ |_||_| |___|____|___|___/
BANNER
}

banner3() {
cat << "BANNER"
     _       _    __ _ _
  __| | ___ | |_ / _(_) | ___  ___
 / _` |/ _ \| __| |_| | |/ _ \/ __|
| (_| | (_) | |_|  _| | |  __/\__ \
 \__,_|\___/ \__|_| |_|_|\___||___/
BANNER
}

show_banner() {
    clear
    local r=$(( RANDOM % 3 ))
    echo -e "${CYAN}"
    case $r in
        0) banner1 ;;
        1) banner2 ;;
        2) banner3 ;;
    esac
    echo -e "${NC}"
    echo -e "${DIM}   :: Arch Linux Dotfiles Installer :: v2.0 ::${NC}"
    echo ""
}

# ==============================================================================
# TUI Functions
# ==============================================================================
show_cursor() { printf '\033[?25h'; }
hide_cursor() { printf '\033[?25l'; }

cleanup() {
    show_cursor
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

print_ok() {
    echo -e "   ${GREEN}[OK]${NC} $1"
}

print_fail() {
    echo -e "   ${RED}[FAIL]${NC} $1"
}

print_skip() {
    echo -e "   ${YELLOW}[SKIP]${NC} $1"
}

print_info() {
    echo -e "   ${BLUE}[i]${NC} $1"
}

print_warn() {
    echo -e "   ${YELLOW}[!]${NC} $1"
}

# Section header
section() {
    local phase="$1"
    local title="$2"
    echo ""
    echo -e "${PURPLE}+----------------------------------------------------------+${NC}"
    echo -e "${PURPLE}|${NC} ${BOLD}${phase}${NC} :: ${WHITE}${title}${NC}"
    echo -e "${PURPLE}+----------------------------------------------------------+${NC}"
    echo ""
}

# System dashboard
sys_dashboard() {
    echo -e "${BLUE}+============ SYSTEM INFO =====================================+${NC}"
    echo -e "${BLUE}|${NC} ${BOLD}Kernel${NC}   : $(uname -r)"
    echo -e "${BLUE}|${NC} ${BOLD}User${NC}     : $(whoami)"
    echo -e "${BLUE}|${NC} ${BOLD}Home${NC}     : $HOME"

    if [[ -f "$STATE_FILE" ]]; then
        local done_count
        done_count=$(wc -l < "$STATE_FILE")
        echo -e "${BLUE}|${NC} ${BOLD}Progress${NC} : ${GREEN}Resuming${NC} ($done_count steps completed)"
    else
        echo -e "${BLUE}|${NC} ${BOLD}Progress${NC} : Fresh install"
    fi
    echo -e "${BLUE}+==============================================================+${NC}"
    echo ""
}

confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local response

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    echo -ne "   ${YELLOW}[?]${NC} $prompt"
    read -r response < /dev/tty
    response="${response:-$default}"
    [[ "$response" =~ ^[Yy]$ ]]
}
