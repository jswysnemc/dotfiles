#!/bin/bash
# Thin bootstrapper for curl-based installs.

set -euo pipefail

DOTFILES_REPO="https://github.com/jswysnemc/dotfiles"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

# If running from a checked-out repo, delegate to the modular installer.
script_dir=""
if script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd); then
    if [[ -f "$script_dir/setup/main.sh" ]]; then
        exec bash "$script_dir/setup/main.sh" "$@"
    fi
fi

# If a repo already exists at the default location, use it.
if [[ -f "$DOTFILES_DIR/setup/main.sh" ]]; then
    exec bash "$DOTFILES_DIR/setup/main.sh" "$@"
fi

# Otherwise, bootstrap the repo for curl-based installs.
if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    if ! command -v git >/dev/null 2>&1; then
        echo "[i] Installing git..."
        sudo pacman -S --needed --noconfirm git
    fi
    echo "[i] Cloning dotfiles to $DOTFILES_DIR..."
    git clone --depth 1 "$DOTFILES_REPO" "$DOTFILES_DIR"
    # Mark as freshly cloned via env var
    export DOTFILES_JUST_CLONED=1
fi

if [[ ! -f "$DOTFILES_DIR/setup/main.sh" ]]; then
    echo "[FAIL] setup/main.sh not found in $DOTFILES_DIR. Please update the repo."
    exit 1
fi

exec bash "$DOTFILES_DIR/setup/main.sh" "$@"
