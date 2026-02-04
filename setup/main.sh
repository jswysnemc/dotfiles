#!/bin/bash
# Dotfiles Installation Script v2.0 (modular)
# For fresh Arch Linux systems (after archinstall)

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SETUP_DIR="$ROOT_DIR/setup"

source "$SETUP_DIR/lib/config.sh"
source "$SETUP_DIR/lib/ui.sh"
source "$SETUP_DIR/lib/exec.sh"
source "$SETUP_DIR/lib/state.sh"

for step in "$SETUP_DIR/steps/"*.sh; do
    source "$step"
done

trap cleanup EXIT

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
    setup_nvim
    setup_zsh
    setup_tmux
    setup_mpv
    setup_locale
    setup_bash_path
    setup_quickshell
    install_wayscrollshot
    setup_pam_lock
    setup_yazi
    setup_user_dirs
    setup_matugen
    setup_theme
    enable_services
    setup_sddm

    show_completion
}

main "$@"
