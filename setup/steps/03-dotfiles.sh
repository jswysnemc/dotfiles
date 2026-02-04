# shellcheck shell=bash

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
        "$HOME/.config/kitty"
        "$HOME/.config/yazi"
        "$HOME/.config/starship.toml"
        "$HOME/.config/fontconfig"
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
    local stow_dirs=(niri waybar quickshell matugen starship kitty font my-scripts electron-flags)

    for dir in "${stow_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if stow -R "$dir" >> "$LOG_FILE" 2>&1; then
                echo -e "      ${GREEN}[OK]${NC} $dir"
            else
                echo -e "      ${RED}[FAIL]${NC} $dir"
            fi
        fi
    done

    # Replace browser in waybar config (Brave -> Firefox)
    local waybar_config="$HOME/.config/waybar/config.jsonc"
    if [[ -f "$waybar_config" ]]; then
        print_info "Configuring waybar browser to Firefox..."
        sed -i \
            -e 's/"format": ""/"format": "󰈹"/' \
            -e 's/"tooltip-format": "浏览器(brave 浏览器)"/"tooltip-format": "Firefox 浏览器"/' \
            -e 's/"on-click": "brave"/"on-click": "firefox"/' \
            "$waybar_config"
        print_ok "Waybar browser set to Firefox"
    fi

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
