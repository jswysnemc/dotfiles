# shellcheck shell=bash

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
                local name
                name=$(basename "$script")
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

    # Add welcome screen to niri autostart (only if not already present)
    local autostart_file="$HOME/.config/niri/conf.d/autostart.kdl"
    local welcome_line='spawn-sh-at-startup "sleep 1 && POPUP_TYPE=welcome qs -p ~/.config/quickshell"'
    if [[ -f "$autostart_file" ]]; then
        if ! grep -q "POPUP_TYPE=welcome" "$autostart_file"; then
            print_info "Adding welcome screen to niri autostart..."
            echo "" >> "$autostart_file"
            echo "// --- Welcome screen (first-time setup, shows once) ---" >> "$autostart_file"
            echo "$welcome_line" >> "$autostart_file"
            print_ok "Welcome screen added to autostart"
        else
            print_info "Welcome screen already in autostart"
        fi
    fi

    mark_done "setup_quickshell"
    log "Quickshell configured"
}

install_wayscrollshot() {
    section "Phase 7a" "Wayscrollshot Installation"

    if is_done "install_wayscrollshot"; then
        print_skip "Wayscrollshot (already done)"
        return
    fi

    local bin_path="$HOME/.local/bin/wayscrollshot"

    if [[ -x "$bin_path" ]]; then
        print_ok "Wayscrollshot already installed"
        mark_done "install_wayscrollshot"
        return
    fi

    print_info "Downloading wayscrollshot..."

    local tmp_dir
    tmp_dir=$(mktemp -d)
    local tar_url="https://github.com/jswysnemc/wayscrollshot/releases/download/v0.1.0/wayscrollshot-linux-x86_64.tar.gz"

    if curl -sL "$tar_url" -o "$tmp_dir/wayscrollshot.tar.gz"; then
        if tar -xzf "$tmp_dir/wayscrollshot.tar.gz" -C "$tmp_dir"; then
            # Find the binary in extracted files
            local extracted_bin
            extracted_bin=$(find "$tmp_dir" -name "wayscrollshot" -type f 2>/dev/null | head -1)

            if [[ -n "$extracted_bin" && -f "$extracted_bin" ]]; then
                mkdir -p "$HOME/.local/bin"
                cp "$extracted_bin" "$bin_path"
                chmod +x "$bin_path"
                print_ok "Wayscrollshot installed to ~/.local/bin/wayscrollshot"
                mark_done "install_wayscrollshot"
            else
                print_fail "Binary not found in archive"
            fi
        else
            print_fail "Failed to extract archive"
        fi
    else
        print_fail "Failed to download wayscrollshot"
        print_info "Manual install: curl -sL $tar_url | tar -xz -C ~/.local/bin"
    fi

    rm -rf "$tmp_dir"
    log "Wayscrollshot installation attempted"
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
    local default_wallpaper="$DOTFILES_DIR/wallpaper/Pictures/Wallpapers/ys-ganyu.jpg"
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
        print_info "Using default wallpaper: ys-ganyu.jpg"
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

setup_sddm() {
    section "Phase 9b" "SDDM Display Manager"

    if is_done "setup_sddm"; then
        print_skip "SDDM setup (already done)"
        return
    fi

    echo ""
    echo -e "   ${WHITE}SDDM is a display manager that provides a graphical login screen.${NC}"
    echo -e "   ${DIM}Without it, you need to login via TTY and run 'niri-session' manually.${NC}"
    echo ""

    if ! confirm "Install and configure SDDM display manager?"; then
        print_skip "SDDM installation (user declined)"
        mark_done "setup_sddm"
        return
    fi

    # Install sddm package, Qt5 QML dependencies, and Wayland compositor
    print_info "Installing SDDM and dependencies..."
    if $AUR_HELPER -S --needed --noconfirm sddm qt5-declarative qt5-quickcontrols qt5-quickcontrols2 qt5-graphicaleffects kwin >> "$LOG_FILE" 2>&1; then
        print_ok "SDDM installed"
    else
        print_fail "Failed to install SDDM"
        return
    fi

    # Install theme
    local theme_name="lunar-glass"
    local theme_src="$DOTFILES_DIR/sddm-theme"
    local theme_dst="/usr/share/sddm/themes/$theme_name"

    if [[ -d "$theme_src" ]]; then
        print_info "Installing SDDM theme: $theme_name"

        # Backup existing theme if present
        if [[ -d "$theme_dst" ]]; then
            sudo mv "$theme_dst" "${theme_dst}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
        fi

        # Create theme directory and copy files
        sudo mkdir -p "$theme_dst"
        sudo cp -r "$theme_src"/*.qml "$theme_dst/" 2>/dev/null || true
        sudo cp -r "$theme_src"/*.conf "$theme_dst/" 2>/dev/null || true
        sudo cp -r "$theme_src"/*.desktop "$theme_dst/" 2>/dev/null || true
        sudo cp -r "$theme_src"/*.png "$theme_dst/" 2>/dev/null || true
        sudo cp -r "$theme_src"/*.svg "$theme_dst/" 2>/dev/null || true
        sudo cp -r "$theme_src"/icons "$theme_dst/" 2>/dev/null || true

        print_ok "Theme files copied to $theme_dst"

        # Configure SDDM with Wayland compositor and theme
        local sddm_conf="/etc/sddm.conf"
        print_info "Configuring SDDM with Wayland compositor..."

        # Backup existing config
        if [[ -f "$sddm_conf" ]]; then
            sudo cp "$sddm_conf" "${sddm_conf}.bak"
        fi

        # Write complete SDDM configuration (Wayland mode, no Xorg)
        sudo tee "$sddm_conf" > /dev/null << EOF
[General]
DisplayServer=wayland

[Wayland]
CompositorCommand=kwin_wayland --no-lockscreen --no-global-shortcuts --locale1

[Theme]
Current=$theme_name
EOF

        print_ok "SDDM configured (Wayland mode, theme: $theme_name)"
    else
        print_warn "Theme directory not found: $theme_src"
    fi

    # Enable SDDM service
    print_info "Enabling SDDM service..."
    if sudo systemctl enable sddm >> "$LOG_FILE" 2>&1; then
        print_ok "SDDM service enabled"
    else
        print_warn "Failed to enable SDDM service"
    fi

    mark_done "setup_sddm"
    log "SDDM configured"
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

    if [[ -d "$DOTFILES_DIR/wallpaper/Pictures/Wallpapers" ]]; then
        cp -r "$DOTFILES_DIR/wallpaper/Pictures/Wallpapers/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
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
