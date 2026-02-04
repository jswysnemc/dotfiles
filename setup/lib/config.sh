# shellcheck shell=bash

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
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
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
PKG_GROUPS[terminal]="kitty starship"
PKG_GROUPS[editor]=""
PKG_GROUPS[files]="dolphin"
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
    markpix-bin
)

OPTIONAL_GROUPS=(
    "apps:Applications:firefox firefox-i18n-zh-cn dolphin btop pavucontrol blueman"
    "media:Media Tools:ffmpegthumbnailer poppler imagemagick ffmpeg mpv playerctl cava wf-recorder"
    "shell:Shell Enhancements:atuin thefuck"
    "lsp:Neovim LSP:tree-sitter-cli clang stylua ruff pyright lua-language-server"
)
