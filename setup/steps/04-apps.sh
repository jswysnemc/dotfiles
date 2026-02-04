# shellcheck shell=bash

setup_nvim() {
    section "Phase 6a" "Neovim Editor"

    if is_done "setup_nvim"; then
        print_skip "Neovim setup (already done)"
        return
    fi

    echo ""
    echo -e "   ${WHITE}Neovim is a modern, extensible text editor.${NC}"
    echo -e "   ${DIM}This will install Neovim and apply the pre-configured setup.${NC}"
    echo ""

    if ! confirm "Install and configure Neovim?"; then
        print_skip "Neovim installation (user declined)"
        mark_done "setup_nvim"
        return
    fi

    # Install neovim
    print_info "Installing Neovim..."
    if $AUR_HELPER -S --needed --noconfirm neovim >> "$LOG_FILE" 2>&1; then
        print_ok "Neovim installed"
    else
        print_fail "Failed to install Neovim"
        return
    fi

    # Apply nvim config with stow
    print_info "Applying Neovim configuration..."
    cd "$DOTFILES_DIR"
    if [[ -d "nvim" ]]; then
        # Backup existing config
        if [[ -e "$HOME/.config/nvim" && ! -L "$HOME/.config/nvim" ]]; then
            local backup_dir="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir"
            cp -r "$HOME/.config/nvim" "$backup_dir/"
            rm -rf "$HOME/.config/nvim"
            print_info "Backed up existing nvim config"
        fi

        if stow -R nvim >> "$LOG_FILE" 2>&1; then
            print_ok "Neovim configuration applied"
        else
            print_fail "Failed to apply Neovim configuration"
        fi
    else
        print_warn "Nvim config directory not found in dotfiles"
    fi

    # Bootstrap lazy.nvim (clone lazy.nvim and install plugins)
    print_info "Bootstrapping lazy.nvim..."
    if nvim --headless "+Lazy! sync" +qa >> "$LOG_FILE" 2>&1; then
        print_ok "Lazy.nvim bootstrapped and plugins installed"
    else
        print_warn "Lazy.nvim bootstrap may have issues (check manually)"
    fi

    # Optional: Install LSP dependencies
    if confirm "Install LSP dependencies (tree-sitter-cli, clang, stylua, ruff, pyright, lua-language-server)?"; then
        local lsp_pkgs="tree-sitter-cli clang stylua ruff pyright lua-language-server"
        print_info "Installing LSP dependencies..."
        if $AUR_HELPER -S --needed --noconfirm $lsp_pkgs >> "$LOG_FILE" 2>&1; then
            print_ok "LSP dependencies installed"
        else
            print_warn "Some LSP dependencies failed"
        fi
    fi

    mark_done "setup_nvim"
    log "Neovim configured"
}

setup_zsh() {
    section "Phase 6b" "Zsh Shell"

    if is_done "setup_zsh"; then
        print_skip "Zsh setup (already done)"
        return
    fi

    echo ""
    echo -e "   ${WHITE}Zsh is a powerful shell with advanced features.${NC}"
    echo -e "   ${DIM}Includes starship prompt, plugins, and custom configuration.${NC}"
    echo ""

    if ! confirm "Install and configure Zsh?"; then
        print_skip "Zsh installation (user declined)"
        mark_done "setup_zsh"
        return
    fi

    # Install zsh
    print_info "Installing Zsh..."
    if $AUR_HELPER -S --needed --noconfirm zsh >> "$LOG_FILE" 2>&1; then
        print_ok "Zsh installed"
    else
        print_fail "Failed to install Zsh"
        return
    fi

    # Apply zsh config with stow
    print_info "Applying Zsh configuration..."
    cd "$DOTFILES_DIR"
    if [[ -d "zsh" ]]; then
        # Backup existing config
        if [[ -e "$HOME/.config/zsh" && ! -L "$HOME/.config/zsh" ]]; then
            local backup_dir="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir"
            cp -r "$HOME/.config/zsh" "$backup_dir/"
            rm -rf "$HOME/.config/zsh"
            print_info "Backed up existing zsh config"
        fi

        if stow -R zsh >> "$LOG_FILE" 2>&1; then
            print_ok "Zsh configuration applied"
        else
            print_fail "Failed to apply Zsh configuration"
        fi
    else
        print_warn "Zsh config directory not found in dotfiles"
    fi

    # Create .zshenv
    cat > "$HOME/.zshenv" << 'ZSHENV'
# Zsh config directory
export ZDOTDIR="$HOME/.config/zsh"
[[ -f "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"
ZSHENV
    print_ok "Created .zshenv"

    # Set default shell
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

setup_tmux() {
    section "Phase 6c" "Tmux Terminal Multiplexer"

    if is_done "setup_tmux"; then
        print_skip "Tmux setup (already done)"
        return
    fi

    echo ""
    echo -e "   ${WHITE}Tmux is a terminal multiplexer for managing multiple sessions.${NC}"
    echo -e "   ${DIM}Features: Split panes, session persistence, custom keybindings.${NC}"
    echo ""

    if ! confirm "Install and configure Tmux?"; then
        print_skip "Tmux installation (user declined)"
        mark_done "setup_tmux"
        return
    fi

    # Install tmux
    print_info "Installing Tmux..."
    if $AUR_HELPER -S --needed --noconfirm tmux >> "$LOG_FILE" 2>&1; then
        print_ok "Tmux installed"
    else
        print_fail "Failed to install Tmux"
        return
    fi

    # Apply tmux config with stow
    print_info "Applying Tmux configuration..."
    cd "$DOTFILES_DIR"
    if [[ -d "tmux" ]]; then
        # Backup existing config
        if [[ -e "$HOME/.config/tmux" && ! -L "$HOME/.config/tmux" ]]; then
            local backup_dir="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir"
            cp -r "$HOME/.config/tmux" "$backup_dir/"
            rm -rf "$HOME/.config/tmux"
            print_info "Backed up existing tmux config"
        fi

        if stow -R tmux >> "$LOG_FILE" 2>&1; then
            print_ok "Tmux configuration applied"
        else
            print_fail "Failed to apply Tmux configuration"
        fi
    else
        print_warn "Tmux config directory not found in dotfiles"
    fi

    mark_done "setup_tmux"
    log "Tmux configured"
}

setup_mpv() {
    section "Phase 6d" "MPV Media Player"

    if is_done "setup_mpv"; then
        print_skip "MPV setup (already done)"
        return
    fi

    echo ""
    echo -e "   ${WHITE}MPV is a powerful media player with Anime4K support.${NC}"
    echo -e "   ${DIM}Features: Hardware decoding, modern OSC, thumbnail preview.${NC}"
    echo ""

    if ! confirm "Install and configure MPV?"; then
        print_skip "MPV installation (user declined)"
        mark_done "setup_mpv"
        return
    fi

    # Install mpv
    print_info "Installing MPV..."
    if $AUR_HELPER -S --needed --noconfirm mpv >> "$LOG_FILE" 2>&1; then
        print_ok "MPV installed"
    else
        print_fail "Failed to install MPV"
        return
    fi

    # Apply mpv config with stow
    print_info "Applying MPV configuration..."
    cd "$DOTFILES_DIR"
    if [[ -d "mpv" ]]; then
        # Backup existing config
        if [[ -e "$HOME/.config/mpv" && ! -L "$HOME/.config/mpv" ]]; then
            local backup_dir="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir"
            cp -r "$HOME/.config/mpv" "$backup_dir/"
            rm -rf "$HOME/.config/mpv"
            print_info "Backed up existing mpv config"
        fi

        if stow -R mpv >> "$LOG_FILE" 2>&1; then
            print_ok "MPV configuration applied"
            # Comment out glsl-shaders line (user needs to download shaders first)
            local mpv_conf="$HOME/.config/mpv/mpv.conf"
            if [[ -f "$mpv_conf" ]]; then
                sed -i 's/^glsl-shaders=/# glsl-shaders=/' "$mpv_conf"
            fi
        else
            print_fail "Failed to apply MPV configuration"
        fi
    else
        print_warn "MPV config directory not found in dotfiles"
    fi

    # Download Anime4K shaders
    if confirm "Download Anime4K shaders for enhanced anime playback?"; then
        print_info "Downloading Anime4K shaders..."
        local shader_dir="$HOME/.config/mpv/shaders"
        mkdir -p "$shader_dir"

        if git clone --depth 1 https://github.com/bloc97/Anime4K.git /tmp/Anime4K >> "$LOG_FILE" 2>&1; then
            cp -r /tmp/Anime4K/glsl_4.0/* "$shader_dir/"
            rm -rf /tmp/Anime4K
            print_ok "Anime4K shaders installed"

            # Enable shaders in config
            local mpv_conf="$HOME/.config/mpv/mpv.conf"
            if [[ -f "$mpv_conf" ]]; then
                sed -i 's/^# glsl-shaders=/glsl-shaders=/' "$mpv_conf"
                print_ok "Anime4K shaders enabled in config"
            fi
        else
            print_warn "Failed to download Anime4K shaders (check manually)"
        fi
    else
        print_info "Skipped Anime4K shaders (can be installed later, see mpv README)"
    fi

    mark_done "setup_mpv"
    log "MPV configured"
}

setup_yazi() {
    section "Phase 9c" "Yazi File Manager"

    if is_done "setup_yazi"; then
        print_skip "Yazi setup (already done)"
        return
    fi

    echo ""
    echo -e "   ${WHITE}Yazi is a modern terminal file manager with image preview support.${NC}"
    echo -e "   ${DIM}Features: Git integration, compression, smart filtering, Kitty image protocol${NC}"
    echo ""

    if ! confirm "Install and configure Yazi file manager?"; then
        print_skip "Yazi installation (user declined)"
        mark_done "setup_yazi"
        return
    fi

    # Core packages
    local yazi_core="yazi"
    # Preview dependencies
    local yazi_preview="ffmpegthumbnailer poppler jq imagemagick ffmpeg p7zip"
    # Opener dependencies
    local yazi_opener="xdg-utils mpv"
    # Optional dependencies (already in cli group: fd ripgrep fzf zoxide)
    local yazi_optional="exiftool"

    print_info "Installing Yazi and dependencies..."

    # Install core
    if $AUR_HELPER -S --needed --noconfirm $yazi_core >> "$LOG_FILE" 2>&1; then
        print_ok "Yazi installed"
    else
        print_fail "Failed to install Yazi"
        return
    fi

    # Install preview dependencies
    print_info "Installing preview dependencies..."
    if $AUR_HELPER -S --needed --noconfirm $yazi_preview >> "$LOG_FILE" 2>&1; then
        print_ok "Preview dependencies installed"
    else
        print_warn "Some preview dependencies failed"
    fi

    # Install opener dependencies
    print_info "Installing opener dependencies..."
    if $AUR_HELPER -S --needed --noconfirm $yazi_opener >> "$LOG_FILE" 2>&1; then
        print_ok "Opener dependencies installed"
    else
        print_warn "Some opener dependencies failed"
    fi

    # Optional: exiftool
    if confirm "Install exiftool (for EXIF metadata display)?"; then
        if $AUR_HELPER -S --needed --noconfirm $yazi_optional >> "$LOG_FILE" 2>&1; then
            print_ok "exiftool installed"
        else
            print_warn "Failed to install exiftool"
        fi
    fi

    # Apply yazi config with stow
    print_info "Applying Yazi configuration..."
    cd "$DOTFILES_DIR"
    if [[ -d "yazi" ]]; then
        # Backup existing config
        if [[ -e "$HOME/.config/yazi" && ! -L "$HOME/.config/yazi" ]]; then
            local backup_dir="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir"
            cp -r "$HOME/.config/yazi" "$backup_dir/"
            rm -rf "$HOME/.config/yazi"
            print_info "Backed up existing yazi config"
        fi

        if stow -R yazi >> "$LOG_FILE" 2>&1; then
            print_ok "Yazi configuration applied"
        else
            print_fail "Failed to apply Yazi configuration"
        fi
    else
        print_warn "Yazi config directory not found in dotfiles"
    fi

    mark_done "setup_yazi"
    log "Yazi configured"
}
