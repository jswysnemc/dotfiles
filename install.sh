#!/bin/bash
#
# Dotfiles Installation Script v2.0
# For fresh Arch Linux systems (after archinstall)
#

set -euo pipefail

# ==============================================================================
# Colors & Styles
# ==============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ==============================================================================
# Configuration
# ==============================================================================
DOTFILES_REPO="https://github.com/jswysnemc/dotfiles"
DOTFILES_DIR="$HOME/.dotfiles"
LOG_FILE="/tmp/dotfiles-install-$(date +%Y%m%d-%H%M%S).log"
STATE_FILE="$HOME/.dotfiles_install_progress"

# Install options
INSTALL_MINIMAL=false
SKIP_AUR=false
SKIP_STOW=false
AUR_HELPER=""

# ==============================================================================
# Package Groups
# ==============================================================================
declare -A PKG_GROUPS

PKG_GROUPS[wm]="niri swww swayidle hyprpolkitagent"
PKG_GROUPS[bar]="waybar"
PKG_GROUPS[terminal]="kitty zsh starship tmux"
PKG_GROUPS[editor]="neovim"
PKG_GROUPS[files]="yazi dolphin"
PKG_GROUPS[theme]="matugen kvantum qt5ct qt6ct"
PKG_GROUPS[appearance]="papirus-icon-theme phinger-cursors"
PKG_GROUPS[input]="fcitx5 fcitx5-im fcitx5-chinese-addons"
PKG_GROUPS[clipboard]="wl-clipboard cliphist grim slurp wayfreeze xclip"
PKG_GROUPS[audio]="wireplumber pipewire pipewire-pulse pipewire-alsa playerctl"
PKG_GROUPS[network]="networkmanager bluez bluez-utils"
PKG_GROUPS[portal]="xdg-desktop-portal xdg-desktop-portal-gtk"
PKG_GROUPS[launcher]="fuzzel"
PKG_GROUPS[notify]="libnotify"
PKG_GROUPS[dev]="python python-pip nodejs npm"
PKG_GROUPS[cli]="ripgrep fd fzf bat eza zoxide jq curl wget unzip brightnessctl psmisc gawk"
PKG_GROUPS[fonts]="noto-fonts-cjk ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols-mono"

PKG_GROUP_NAMES=(
    "wm:Window Manager (niri)"
    "bar:Status Bar (waybar)"
    "terminal:Terminal & Shell"
    "editor:Editor (neovim)"
    "files:File Manager"
    "theme:Theme System (matugen/kvantum/qt*ct)"
    "appearance:Appearance (icons/cursors)"
    "input:Input Method (fcitx5)"
    "clipboard:Clipboard & Screenshot"
    "audio:Audio (pipewire)"
    "network:Network & Bluetooth"
    "portal:XDG Portal"
    "launcher:App Launcher (rofi/fuzzel)"
    "notify:Notifications (mako)"
    "dev:Development Tools"
    "cli:CLI Utilities"
    "fonts:Fonts"
)

AUR_PACKAGES=(
    quickshell
    uv
    xdg-desktop-portal-kde
    xwayland-satellite
    clipse
    clipnotify
    catppuccin-gtk-theme-latte
    catppuccin-gtk-theme-mocha
    catppuccin-cursors-latte
    kvantum-theme-matchama
    fcitx5-skin-fluentlight-git
)

OPTIONAL_GROUPS=(
    "apps:Applications:firefox firefox-i18n-zh-cn dolphin btop pavucontrol blueman"
    "media:Media Tools:ffmpegthumbnailer poppler imagemagick ffmpeg mpv playerctl cava wf-recorder"
    "shell:Shell Enhancements:atuin thefuck"
    "lsp:Neovim LSP:tree-sitter-cli clang stylua ruff pyright lua-language-server"
)

# ==============================================================================
# ASCII Banners
# ==============================================================================
banner1() {
cat << "EOF"
    ____        __  _____ __
   / __ \____  / /_/ __(_) /__  _____
  / / / / __ \/ __/ /_/ / / _ \/ ___/
 / /_/ / /_/ / /_/ __/ / /  __(__  )
/_____/\____/\__/_/ /_/_/\___/____/
EOF
}

banner2() {
cat << "EOF"
 ___   ___ ___ ___ ___ _    ___ ___
|   \ / _ \_  _| __|_ _| |  | __/ __|
| |) | (_) || || _| | || |__| _|\__ \
|___/ \___/ |_||_| |___|____|___|___/
EOF
}

banner3() {
cat << "EOF"
     _       _    __ _ _
  __| | ___ | |_ / _(_) | ___  ___
 / _` |/ _ \| __| |_| | |/ _ \/ __|
| (_| | (_) | |_|  _| | |  __/\__ \
 \__,_|\___/ \__|_| |_|_|\___||___/
EOF
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
trap cleanup EXIT

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

# Mark step as done
mark_done() {
    echo "$1" >> "$STATE_FILE"
}

# Check if step is done
is_done() {
    [[ -f "$STATE_FILE" ]] && grep -q "^$1$" "$STATE_FILE"
}

# ==============================================================================
# Install Functions
# ==============================================================================

check_system() {
    section "Pre-Flight" "System Check"

    local checks=(
        "Arch Linux:/etc/arch-release:file"
        "Non-root:0:notroot"
        "Network:8.8.8.8:ping"
        "Pacman:pacman:cmd"
    )

    local failed=false

    for check in "${checks[@]}"; do
        IFS=':' read -r name target type <<< "$check"

        local result=false
        case "$type" in
            file)   [[ -f "$target" ]] && result=true ;;
            notroot) [[ $EUID -ne 0 ]] && result=true ;;
            ping)   ping -c 1 -W 3 "$target" &>/dev/null && result=true ;;
            cmd)    command_exists "$target" && result=true ;;
        esac

        if $result; then
            print_ok "$name"
        else
            print_fail "$name"
            failed=true
        fi
    done

    if $failed; then
        echo ""
        print_fail "System check failed. Exiting."
        exit 1
    fi

    log "System check passed"
}

install_base() {
    section "Phase 1" "Base Tools"

    if is_done "base_tools"; then
        print_skip "Base tools (already done)"
        return
    fi

    # Check pacman lock
    if [[ -f /var/lib/pacman/db.lck ]]; then
        print_warn "Pacman database is locked"
        if confirm "Remove lock file?"; then
            sudo rm -f /var/lib/pacman/db.lck
            print_ok "Lock removed"
        else
            print_fail "Cannot proceed"
            exit 1
        fi
    fi

    exe_live "Updating system" "sudo pacman -Syu --noconfirm"
    exe_live "Installing base tools" "sudo pacman -S --needed --noconfirm git stow base-devel"

    mark_done "base_tools"
    log "Base tools installed"
}

install_aur_helper() {
    section "Phase 2" "AUR Helper (paru)"

    if $SKIP_AUR; then
        print_skip "AUR helper (--no-aur)"
        return
    fi

    if command_exists paru; then
        print_ok "paru already installed"
        AUR_HELPER="paru"
        return
    elif command_exists yay; then
        print_ok "yay already installed"
        AUR_HELPER="yay"
        return
    fi

    if is_done "aur_helper"; then
        print_skip "AUR helper (already done)"
        AUR_HELPER="paru"
        return
    fi

    print_info "Adding archlinuxcn repository (BFSU mirror)..."

    # Add archlinuxcn repo if not exists
    if ! grep -q "\[archlinuxcn\]" /etc/pacman.conf; then
        sudo tee -a /etc/pacman.conf > /dev/null << 'REPO'

[archlinuxcn]
Server = https://mirrors.bfsu.edu.cn/archlinuxcn/$arch
REPO
        print_ok "archlinuxcn repo added"
    else
        print_info "archlinuxcn repo exists"
    fi

    exe_live "Syncing pacman database" "sudo pacman -Sy"
    exe_live "Installing archlinuxcn-keyring" "sudo pacman -S --noconfirm archlinuxcn-keyring"
    exe_live "Installing paru" "sudo pacman -S --noconfirm paru"

    AUR_HELPER="paru"
    mark_done "aur_helper"
    print_ok "paru installed via archlinuxcn"
    log "AUR helper installed"
}

clone_dotfiles() {
    section "Phase 3" "Clone Dotfiles"

    if [[ -d "$DOTFILES_DIR" ]]; then
        print_info "Directory exists: $DOTFILES_DIR"
        if confirm "Update existing repo?"; then
            if exe "cd '$DOTFILES_DIR' && git pull"; then
                print_ok "Repository updated"
            else
                print_warn "Update failed, continuing..."
            fi
        fi
        return
    fi

    if is_done "clone_dotfiles"; then
        print_skip "Clone dotfiles (already done)"
        return
    fi

    # Git config for large repos
    git config --global http.postBuffer 524288000
    git config --global http.lowSpeedLimit 1000
    git config --global http.lowSpeedTime 60

    local max_retries=3
    local retry=0

    while [[ $retry -lt $max_retries ]]; do
        retry=$((retry + 1))
        print_info "Clone attempt $retry/$max_retries"

        if exe "git clone --depth 1 '$DOTFILES_REPO' '$DOTFILES_DIR'"; then
            exe "cd '$DOTFILES_DIR' && git fetch --unshallow" || true
            print_ok "Repository cloned"
            mark_done "clone_dotfiles"
            log "Dotfiles cloned"
            return 0
        else
            rm -rf "$DOTFILES_DIR" 2>/dev/null || true
            [[ $retry -lt $max_retries ]] && sleep 3
        fi
    done

    print_fail "Clone failed after $max_retries attempts"
    print_info "Try: git clone $DOTFILES_REPO $DOTFILES_DIR"
    exit 1
}

install_packages() {
    section "Phase 4" "Install Packages"

    local total=${#PKG_GROUP_NAMES[@]}
    local current=0
    local failed=0

    echo -e "   Installing ${WHITE}$total${NC} package groups..."
    echo ""

    for group_info in "${PKG_GROUP_NAMES[@]}"; do
        IFS=':' read -r key name <<< "$group_info"
        current=$((current + 1))
        local packages="${PKG_GROUPS[$key]}"

        if [[ -z "$packages" ]]; then
            continue
        fi

        # Check if already done
        if is_done "pkg_$key"; then
            echo -e "   ${GREEN}[${current}/${total}]${NC} $name ${DIM}(done)${NC}"
            continue
        fi

        echo -e "   ${CYAN}[${current}/${total}]${NC} $name"
        echo -e "         ${DIM}$packages${NC}"

        # Spinner
        local spin_pid
        (
            local i=0
            local chars='|/-\'
            while true; do
                printf "\r         \033[0;33m[%c]\033[0m Installing..." "${chars:$i:1}"
                i=$(( (i + 1) % 4 ))
                sleep 0.12
            done
        ) &
        spin_pid=$!

        local result=0
        if $AUR_HELPER -S --needed --noconfirm $packages >> "$LOG_FILE" 2>&1; then
            result=0
        else
            result=1
        fi

        kill "$spin_pid" 2>/dev/null
        wait "$spin_pid" 2>/dev/null || true

        if [[ $result -eq 0 ]]; then
            printf "\r         ${GREEN}[OK]${NC} Done            \n"
            mark_done "pkg_$key"
        else
            printf "\r         ${RED}[FAIL]${NC} Error          \n"
            failed=$((failed + 1))
        fi
    done

    echo ""
    if [[ $failed -gt 0 ]]; then
        print_warn "$failed group(s) had errors (check log)"
    else
        print_ok "All core packages installed"
    fi

    # AUR packages
    section "Phase 4b" "AUR Packages"

    if is_done "aur_packages"; then
        print_skip "AUR packages (already done)"
    else
        echo -e "   ${DIM}${AUR_PACKAGES[*]}${NC}"
        echo ""
        print_info "AUR packages may prompt for provider selection"

        # Install AUR packages interactively (without --noconfirm)
        if $AUR_HELPER -S --needed --skipreview ${AUR_PACKAGES[*]} < /dev/tty; then
            mark_done "aur_packages"
        else
            print_warn "Some AUR packages failed"
        fi
    fi

    # Optional packages
    if ! $INSTALL_MINIMAL; then
        section "Phase 4c" "Optional Packages"

        for opt_info in "${OPTIONAL_GROUPS[@]}"; do
            IFS=':' read -r key name packages <<< "$opt_info"

            if is_done "opt_$key"; then
                echo -e "   ${GREEN}[OK]${NC} $name ${DIM}(done)${NC}"
                continue
            fi

            echo ""
            if confirm "Install $name?"; then
                echo -e "      ${DIM}$packages${NC}"

                local spin_pid
                (
                    local i=0
                    local chars='|/-\'
                    while true; do
                        printf "\r      \033[0;33m[%c]\033[0m Installing..." "${chars:$i:1}"
                        i=$(( (i + 1) % 4 ))
                        sleep 0.12
                    done
                ) &
                spin_pid=$!

                local result=0
                if $AUR_HELPER -S --needed --noconfirm $packages >> "$LOG_FILE" 2>&1; then
                    result=0
                else
                    result=1
                fi

                kill "$spin_pid" 2>/dev/null
                wait "$spin_pid" 2>/dev/null || true

                if [[ $result -eq 0 ]]; then
                    printf "\r      ${GREEN}[OK]${NC} Installed       \n"
                    mark_done "opt_$key"
                else
                    printf "\r      ${RED}[FAIL]${NC} Error          \n"
                fi
            fi
        done
    fi

    log "Packages installed"
}

apply_dotfiles() {
    section "Phase 5" "Apply Configurations"

    if $SKIP_STOW; then
        print_skip "Config deployment (--no-stow)"
        return
    fi

    if is_done "apply_dotfiles"; then
        print_skip "Dotfiles applied (already done)"
        return
    fi

    cd "$DOTFILES_DIR"

    # Clean up broken symlinks in dotfiles repo
    # These symlinks point to absolute paths that don't exist on fresh systems
    print_info "Cleaning up stale symlinks in dotfiles repo..."
    local stale_symlinks=(
        "waybar/.config/waybar/colors.css"
        "quickshell/.config/quickshell/Commons/Theme.js"
        "quickshell/.config/quickshell/colors.js"
    )
    for link in "${stale_symlinks[@]}"; do
        local link_path="$DOTFILES_DIR/$link"
        if [[ -L "$link_path" ]] && [[ ! -e "$link_path" ]]; then
            rm -f "$link_path"
            print_ok "Removed stale symlink: $link"
        elif [[ -L "$link_path" ]]; then
            # Symlink exists but points somewhere - check if target is outside dotfiles
            local target
            target=$(readlink "$link_path")
            if [[ "$target" == /* ]] && [[ ! "$target" == "$DOTFILES_DIR"* ]]; then
                rm -f "$link_path"
                print_ok "Removed external symlink: $link"
            fi
        fi
    done

    # Backup existing configs
    print_info "Backing up existing configs..."
    local backup_dir="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
    local configs=(
        "$HOME/.config/niri"
        "$HOME/.config/waybar"
        "$HOME/.config/quickshell"
        "$HOME/.config/matugen"
        "$HOME/.config/nvim"
        "$HOME/.config/zsh"
        "$HOME/.config/kitty"
        "$HOME/.config/yazi"
        "$HOME/.config/tmux"
        "$HOME/.config/starship.toml"
        "$HOME/.config/fontconfig"
        "$HOME/.zshrc"
    )

    local has_backup=false
    for config in "${configs[@]}"; do
        if [[ -e "$config" && ! -L "$config" ]]; then
            mkdir -p "$backup_dir"
            cp -r "$config" "$backup_dir/" 2>/dev/null || true
            rm -rf "$config"
            has_backup=true
        fi
    done

    if $has_backup; then
        print_ok "Backed up to: $backup_dir"
    fi

    # Stow
    print_info "Applying configs with stow..."
    local stow_dirs=(niri waybar quickshell matugen nvim zsh starship tmux yazi kitty font my-scripts electron-flags)

    for dir in "${stow_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if stow -R "$dir" >> "$LOG_FILE" 2>&1; then
                echo -e "      ${GREEN}[OK]${NC} $dir"
            else
                echo -e "      ${RED}[FAIL]${NC} $dir"
            fi
        fi
    done

    # Initialize matugen default colors (required for symlinks like waybar/colors.css)
    local init_script="$HOME/.config/matugen/defaults/matugen-init"
    if [[ -x "$init_script" ]]; then
        print_info "Initializing matugen default colors..."
        if "$init_script" -s >> "$LOG_FILE" 2>&1; then
            print_ok "Matugen colors initialized"
        else
            print_warn "Matugen init failed (will retry in setup_matugen)"
        fi
    fi

    mark_done "apply_dotfiles"
    print_ok "Configs applied"
    log "Dotfiles applied"
}

setup_zsh() {
    section "Phase 6" "Zsh Configuration"

    if is_done "setup_zsh"; then
        print_skip "Zsh setup (already done)"
        return
    fi

    cat > "$HOME/.zshenv" << 'ZSHENV'
# Zsh config directory
export ZDOTDIR="$HOME/.config/zsh"
[[ -f "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"
ZSHENV
    print_ok "Created .zshenv"

    if [[ "$SHELL" != *"zsh"* ]]; then
        if confirm "Set Zsh as default shell?"; then
            if chsh -s /bin/zsh; then
                print_ok "Default shell changed to zsh"
            else
                print_warn "Failed to change shell"
            fi
        fi
    else
        print_ok "Zsh is already default"
    fi

    mark_done "setup_zsh"
    log "Zsh configured"
}

setup_locale() {
    section "Phase 6a" "Locale Configuration"

    if is_done "setup_locale"; then
        print_skip "Locale setup (already done)"
        return
    fi

    local need_gen=false

    # Check if en_US.UTF-8 locale exists
    if ! locale -a 2>/dev/null | grep -qi "en_US.utf8"; then
        print_info "Enabling en_US.UTF-8..."
        if grep -q "^#en_US.UTF-8" /etc/locale.gen; then
            sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
        elif ! grep -q "^en_US.UTF-8" /etc/locale.gen; then
            echo "en_US.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen > /dev/null
        fi
        need_gen=true
    else
        print_ok "en_US.UTF-8 locale available"
    fi

    # Check if zh_CN.UTF-8 locale exists
    if ! locale -a 2>/dev/null | grep -qi "zh_CN.utf8"; then
        print_info "Enabling zh_CN.UTF-8..."
        if grep -q "^#zh_CN.UTF-8" /etc/locale.gen; then
            sudo sed -i 's/^#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
        elif ! grep -q "^zh_CN.UTF-8" /etc/locale.gen; then
            echo "zh_CN.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen > /dev/null
        fi
        need_gen=true
    else
        print_ok "zh_CN.UTF-8 locale available"
    fi

    # Generate locales if needed
    if $need_gen; then
        print_info "Generating locales..."
        if sudo locale-gen >> "$LOG_FILE" 2>&1; then
            print_ok "Locales generated"
        else
            print_warn "locale-gen failed"
        fi
    fi

    # Keep /etc/locale.conf as English (Chinese is set via niri environment)
    print_info "System locale: en_US.UTF-8 (Chinese set via niri environment)"

    mark_done "setup_locale"
    log "Locale configured"
}

setup_bash_path() {
    section "Phase 6b" "Bash PATH Configuration"

    if is_done "setup_bash_path"; then
        print_skip "Bash PATH (already done)"
        return
    fi

    # Add ~/.local/bin to bash PATH
    local bash_profile="$HOME/.bash_profile"
    local bashrc="$HOME/.bashrc"
    local path_line='export PATH="$HOME/.local/bin:$PATH"'

    # Add to .bash_profile if exists or create
    if [[ -f "$bash_profile" ]]; then
        if ! grep -q '\.local/bin' "$bash_profile"; then
            echo "" >> "$bash_profile"
            echo "# Add local bin to PATH" >> "$bash_profile"
            echo "$path_line" >> "$bash_profile"
            print_ok "Updated .bash_profile"
        else
            print_info ".bash_profile already has PATH"
        fi
    else
        cat > "$bash_profile" << 'BASHPROFILE'
# ~/.bash_profile - Bash login shell configuration

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Source .bashrc if it exists
[[ -f ~/.bashrc ]] && source ~/.bashrc
BASHPROFILE
        print_ok "Created .bash_profile"
    fi

    # Also add to .bashrc for interactive non-login shells
    if [[ -f "$bashrc" ]]; then
        if ! grep -q '\.local/bin' "$bashrc"; then
            echo "" >> "$bashrc"
            echo "# Add local bin to PATH" >> "$bashrc"
            echo "$path_line" >> "$bashrc"
            print_ok "Updated .bashrc"
        else
            print_info ".bashrc already has PATH"
        fi
    fi

    mark_done "setup_bash_path"
    log "Bash PATH configured"
}

setup_quickshell() {
    section "Phase 7" "Quickshell Configuration"

    if is_done "setup_quickshell"; then
        print_skip "Quickshell setup (already done)"
        return
    fi

    mkdir -p "$HOME/.local/bin"

    # Copy scripts from dotfiles local-bin
    local src_dir="$DOTFILES_DIR/local-bin"
    if [[ -d "$src_dir" ]]; then
        print_info "Copying scripts from local-bin..."
        for script in "$src_dir"/*; do
            if [[ -f "$script" ]]; then
                local name=$(basename "$script")
                cp "$script" "$HOME/.local/bin/$name"
                chmod +x "$HOME/.local/bin/$name"
                echo -e "      ${GREEN}[OK]${NC} $name"
            fi
        done
    else
        print_warn "local-bin directory not found: $src_dir"
    fi

    # Python deps
    if [[ -d "$HOME/.config/quickshell" ]] && command_exists uv; then
        if exe "cd '$HOME/.config/quickshell' && uv sync"; then
            print_ok "Python dependencies installed"
        else
            print_warn "Run manually: cd ~/.config/quickshell && uv sync"
        fi
    fi

    mark_done "setup_quickshell"
    log "Quickshell configured"
}

setup_pam_lock() {
    section "Phase 7b" "PAM Lockscreen Configuration"

    if is_done "setup_pam_lock"; then
        print_skip "PAM qs-lock (already done)"
        return
    fi

    local pam_file="/etc/pam.d/qs-lock"

    if [[ -f "$pam_file" ]]; then
        print_ok "PAM qs-lock already exists"
    else
        print_info "Creating PAM configuration for qs-lock..."
        sudo tee "$pam_file" > /dev/null << 'PAM'
#%PAM-1.0
# Password-only authentication for lockscreen
auth       include    system-auth
account    include    system-auth
session    include    system-auth
PAM
        if [[ -f "$pam_file" ]]; then
            print_ok "Created $pam_file"
        else
            print_fail "Failed to create $pam_file"
            print_info "Create manually: sudo nano $pam_file"
        fi
    fi

    mark_done "setup_pam_lock"
    log "PAM lockscreen configured"
}

setup_matugen() {
    section "Phase 8" "Theme System (Matugen)"

    if is_done "setup_matugen"; then
        print_skip "Matugen setup (already done)"
        return
    fi

    if ! command_exists matugen; then
        print_warn "matugen not installed, skipping theme generation"
        mark_done "setup_matugen"
        return
    fi

    local cache_wallpaper="$HOME/.cache/current_wallpaper"
    local wallpaper_dir="$HOME/Pictures/Wallpapers"
    local default_wallpaper="$DOTFILES_DIR/wallpaper/Pictures/wallpapers/paper-ganyu.png"
    local selected_wallpaper=""

    # Priority: 1. existing cache link  2. wallpaper from dir  3. default
    if [[ -L "$cache_wallpaper" ]] && [[ -f "$cache_wallpaper" ]]; then
        selected_wallpaper="$cache_wallpaper"
        print_info "Using existing wallpaper: $(readlink -f "$cache_wallpaper")"
    elif [[ -d "$wallpaper_dir" ]]; then
        # Find first available wallpaper
        local found_wp
        found_wp=$(find "$wallpaper_dir" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \) 2>/dev/null | head -1)
        if [[ -n "$found_wp" ]]; then
            selected_wallpaper="$found_wp"
            # Create cache symlink for consistency with wallpaper-selector
            mkdir -p "$(dirname "$cache_wallpaper")"
            ln -sf "$found_wp" "$cache_wallpaper"
            print_info "Using wallpaper: $(basename "$found_wp")"
        fi
    fi

    # Fallback to default
    if [[ -z "$selected_wallpaper" ]] && [[ -f "$default_wallpaper" ]]; then
        selected_wallpaper="$default_wallpaper"
        mkdir -p "$(dirname "$cache_wallpaper")"
        ln -sf "$default_wallpaper" "$cache_wallpaper"
        print_info "Using default wallpaper: paper-ganyu.png"
    fi

    if [[ -n "$selected_wallpaper" ]]; then
        print_info "Generating theme from wallpaper..."
        if exe "matugen image '$selected_wallpaper'"; then
            print_ok "Theme generated successfully"
        else
            print_warn "Matugen failed, try: matugen image $selected_wallpaper"
        fi
    else
        # No wallpaper found, use matugen-init for default colors
        local init_script="$HOME/.config/matugen/defaults/matugen-init"
        if [[ -x "$init_script" ]]; then
            if exe "'$init_script' -s"; then
                print_ok "Matugen initialized with default colors"
            else
                print_warn "Matugen init failed"
            fi
        else
            print_warn "No wallpaper found"
            print_info "Run: matugen image /path/to/wallpaper.jpg"
        fi
    fi

    mark_done "setup_matugen"
    log "Matugen initialized"
}

setup_theme() {
    section "Phase 8b" "GTK/Qt Theme Configuration"

    if is_done "setup_theme"; then
        print_skip "Theme setup (already done)"
        return
    fi

    # Theme settings
    local GTK_THEME="catppuccin-latte-blue-standard+default"
    local ICON_THEME="Papirus-Light"
    local CURSOR_THEME="phinger-cursors-light"
    local CURSOR_SIZE="24"
    local FONT_NAME="Adwaita Sans 11"
    local KVANTUM_THEME="KvArc"

    # --- GTK-3.0 ---
    print_info "Configuring GTK-3.0..."
    mkdir -p "$HOME/.config/gtk-3.0"
    cat > "$HOME/.config/gtk-3.0/settings.ini" << GTKCONF
[Settings]
gtk-theme-name=${GTK_THEME}
gtk-icon-theme-name=${ICON_THEME}
gtk-font-name=${FONT_NAME}
gtk-cursor-theme-name=${CURSOR_THEME}
gtk-cursor-theme-size=${CURSOR_SIZE}
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=0
GTKCONF
    print_ok "GTK-3.0 configured"

    # --- GTK-4.0 ---
    print_info "Configuring GTK-4.0..."
    mkdir -p "$HOME/.config/gtk-4.0"
    cat > "$HOME/.config/gtk-4.0/settings.ini" << GTKCONF
[Settings]
gtk-theme-name=${GTK_THEME}
gtk-icon-theme-name=${ICON_THEME}
gtk-font-name=${FONT_NAME}
gtk-cursor-theme-name=${CURSOR_THEME}
gtk-cursor-theme-size=${CURSOR_SIZE}
gtk-application-prefer-dark-theme=0
GTKCONF
    print_ok "GTK-4.0 configured"

    # --- Qt5ct ---
    print_info "Configuring Qt5ct..."
    mkdir -p "$HOME/.config/qt5ct"
    cat > "$HOME/.config/qt5ct/qt5ct.conf" << QT5CONF
[Appearance]
custom_palette=false
icon_theme=${ICON_THEME}
standard_dialogs=default
style=Fusion

[Fonts]
fixed="Noto Sans,12,-1,5,50,0,0,0,0,0"
general="Noto Sans,12,-1,5,50,0,0,0,0,0"

[Interface]
activate_item_on_single_click=1
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
gui_effects=@Invalid()
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
stylesheets=@Invalid()
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3

[Troubleshooting]
force_raster_widgets=1
QT5CONF
    print_ok "Qt5ct configured"

    # --- Qt6ct ---
    print_info "Configuring Qt6ct..."
    mkdir -p "$HOME/.config/qt6ct"
    cat > "$HOME/.config/qt6ct/qt6ct.conf" << QT6CONF
[Appearance]
custom_palette=false
icon_theme=${ICON_THEME}
standard_dialogs=default
style=kvantum

[Fonts]
fixed="Noto Sans,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
general="Noto Sans,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"

[Interface]
activate_item_on_single_click=1
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
gui_effects=@Invalid()
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
stylesheets=@Invalid()
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3

[Troubleshooting]
force_raster_widgets=1
QT6CONF
    print_ok "Qt6ct configured"

    # --- Kvantum ---
    print_info "Configuring Kvantum..."
    mkdir -p "$HOME/.config/Kvantum"
    cat > "$HOME/.config/Kvantum/kvantum.kvconfig" << KVCONF
[General]
theme=${KVANTUM_THEME}
KVCONF
    print_ok "Kvantum configured"

    # --- Default cursor ---
    print_info "Setting default cursor..."
    mkdir -p "$HOME/.icons/default"
    cat > "$HOME/.icons/default/index.theme" << CURSORCONF
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=${CURSOR_THEME}
CURSORCONF
    print_ok "Default cursor configured"

    # --- Fcitx5 theme ---
    print_info "Configuring Fcitx5 theme..."
    mkdir -p "$HOME/.config/fcitx5/conf"
    cat > "$HOME/.config/fcitx5/conf/classicui.conf" << FCITX5CONF
# 垂直候选列表
Vertical Candidate List=False
# 使用鼠标滚轮翻页
WheelForPaging=True
# 字体
Font="Sans 10"
# 菜单字体
MenuFont="Sans 10"
# 托盘字体
TrayFont="Sans Bold 10"
# 托盘标签轮廓颜色
TrayOutlineColor=#000000
# 托盘标签文本颜色
TrayTextColor=#ffffff
# 优先使用文字图标
PreferTextIcon=False
# 在图标中显示布局名称
ShowLayoutNameInIcon=True
# 使用输入法的语言来显示文字
UseInputMethodLanguageToDisplayText=True
# 主题
Theme=FluentLight-solid
# 深色主题
DarkTheme=FluentLight-solid
# 跟随系统浅色/深色设置
UseDarkTheme=False
# 当被主题和桌面支持时使用系统的重点色
UseAccentColor=True
# 在 X11 上针对不同屏幕使用单独的 DPI
PerScreenDPI=False
# 固定 Wayland 的字体 DPI
ForceWaylandDPI=0
# 在 Wayland 下启用分数缩放
EnableFractionalScale=True
FCITX5CONF
    print_ok "Fcitx5 theme configured (FluentLight-solid)"

    # --- Dolphin terminal ---
    print_info "Configuring Dolphin..."
    mkdir -p "$HOME/.config"
    if [[ -f "$HOME/.config/dolphinrc" ]]; then
        if grep -q "^\[General\]" "$HOME/.config/dolphinrc"; then
            if grep -q "^TerminalApplication=" "$HOME/.config/dolphinrc"; then
                sed -i 's/^TerminalApplication=.*/TerminalApplication=kitty/' "$HOME/.config/dolphinrc"
            else
                sed -i '/^\[General\]/a TerminalApplication=kitty' "$HOME/.config/dolphinrc"
            fi
        else
            echo -e "[General]\nTerminalApplication=kitty" >> "$HOME/.config/dolphinrc"
        fi
    else
        cat > "$HOME/.config/dolphinrc" << 'DOLPHINCONF'
[General]
TerminalApplication=kitty
DOLPHINCONF
    fi
    print_ok "Dolphin terminal set to kitty"

    mark_done "setup_theme"
    log "Theme configured"
}

enable_services() {
    section "Phase 9" "System Services"

    if is_done "enable_services"; then
        print_skip "Services enabled (already done)"
        return
    fi

    local services=("NetworkManager" "bluetooth")

    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^$service.service"; then
            if sudo systemctl enable --now "$service" >> "$LOG_FILE" 2>&1; then
                print_ok "Enabled $service"
            else
                print_warn "Failed to enable $service"
            fi
        fi
    done

    mark_done "enable_services"
    log "Services enabled"
}

setup_user_dirs() {
    section "Phase 10" "User Directories"

    if is_done "setup_user_dirs"; then
        print_skip "User directories (already done)"
        return
    fi

    local dirs=(
        "$HOME/.local/bin"
        "$HOME/.local/share"
        "$HOME/.cache"
        "$HOME/Pictures/Screenshots"
        "$HOME/Pictures/Wallpapers"
        "$HOME/Videos/Recordings"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done

    if [[ -d "$DOTFILES_DIR/wallpaper/Pictures/wallpapers" ]]; then
        cp -r "$DOTFILES_DIR/wallpaper/Pictures/wallpapers/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
        print_ok "Wallpapers copied"
    fi

    # Fix Dolphin application menu (KDE menu file for niri)
    mkdir -p "$HOME/.config/menus"
    if curl -sL "https://raw.githubusercontent.com/KDE/plasma-workspace/master/menu/desktop/plasma-applications.menu" \
        -o "$HOME/.config/menus/applications.menu" 2>/dev/null; then
        print_ok "Dolphin application menu fixed"
    else
        print_warn "Failed to download plasma-applications.menu"
    fi

    print_ok "Directories created"
    mark_done "setup_user_dirs"
    log "User directories created"
}

show_completion() {
    clear
    show_banner

    echo -e "${GREEN}+==============================================================+${NC}"
    echo -e "${GREEN}|              INSTALLATION COMPLETE                           |${NC}"
    echo -e "${GREEN}+==============================================================+${NC}"
    echo ""

    echo -e "   ${BOLD}Next Steps:${NC}"
    echo ""
    echo -e "   ${CYAN}1.${NC} Reboot the system"
    echo -e "   ${CYAN}2.${NC} Login at TTY (no display manager configured)"
    echo -e "   ${CYAN}3.${NC} Start desktop:  ${YELLOW}niri-session${NC}"
    echo -e "   ${CYAN}4.${NC} Set wallpaper:  ${YELLOW}matugen image /path/to/wallpaper.jpg${NC}"
    echo -e "   ${CYAN}5.${NC} Input method:   ${YELLOW}fcitx5-configtool${NC}"
    echo ""
    echo -e "   ${DIM}Note: No SDDM/GDM configured. Login via TTY then run 'niri-session'${NC}"
    echo -e "   ${DIM}Log: $LOG_FILE${NC}"
    echo ""

    # Remove state file on success
    rm -f "$STATE_FILE"

    # Reboot countdown
    echo -e "${YELLOW}>>> System requires a REBOOT.${NC}"
    echo ""

    for i in {10..1}; do
        echo -ne "\r   ${DIM}Auto-rebooting in ${i}s... (Press 'n' to cancel)${NC}"

        if read -t 1 -n 1 input; then
            if [[ "$input" == "n" || "$input" == "N" ]]; then
                echo -e "\n\n   ${BLUE}>>> Reboot cancelled.${NC}"
                exit 0
            fi
        fi
    done

    echo -e "\n\n   ${GREEN}>>> Rebooting...${NC}"
    sudo systemctl reboot
}

show_help() {
    cat << EOF
Dotfiles Installation Script v2.0

Usage: ./install.sh [options]

Options:
    --minimal    Install core packages only
    --no-aur     Skip AUR helper installation
    --no-stow    Skip config deployment
    --reset      Clear progress and start fresh
    --help       Show this help

Examples:
    ./install.sh              # Full installation
    ./install.sh --minimal    # Minimal installation
    ./install.sh --reset      # Clear progress, start fresh

EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --minimal)
                INSTALL_MINIMAL=true
                shift
                ;;
            --no-aur)
                SKIP_AUR=true
                shift
                ;;
            --no-stow)
                SKIP_STOW=true
                shift
                ;;
            --reset)
                rm -f "$STATE_FILE"
                echo "Progress cleared."
                shift
                ;;
            --help|-h)
                show_help
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                ;;
        esac
    done
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    echo "Dotfiles Installation Log - $(date)" > "$LOG_FILE"

    parse_args "$@"

    show_banner
    sys_dashboard

    if ! confirm "Start installation?"; then
        print_info "Cancelled"
        exit 0
    fi

    [[ ! -f "$STATE_FILE" ]] && touch "$STATE_FILE"

    check_system
    install_base
    install_aur_helper
    clone_dotfiles
    install_packages
    apply_dotfiles
    setup_zsh
    setup_locale
    setup_bash_path
    setup_quickshell
    setup_pam_lock
    setup_matugen
    setup_theme
    enable_services
    setup_user_dirs

    show_completion
}

main "$@"
