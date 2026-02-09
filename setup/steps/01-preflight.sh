# shellcheck shell=bash

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

    # Skip if just cloned by install.sh bootstrap
    if [[ "${DOTFILES_JUST_CLONED:-}" == "1" ]]; then
        print_ok "Repository cloned (bootstrap)"
        mark_done "clone_dotfiles"
        return
    fi

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
