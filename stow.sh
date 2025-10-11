#!/usr/bin/env bash

set -euo pipefail

# --- Determine the correct home directory for WSL ---
# The $HOME variable in WSL can sometimes point to the Windows user profile (/mnt/c/Users/...).
# We explicitly find the correct Linux home directory from /etc/passwd to be safe.
WSL_HOME=$(getent passwd "$USER" | cut -d: -f6)

if [ -z "$WSL_HOME" ]; then
    echo "❌ Could not determine the correct WSL home directory for user '$USER'. Exiting."
    exit 1
fi

# --- Determine the absolute path to the dotfiles directory ---
# This is more robust than `cd` as it allows us to explicitly tell Stow where to find the packages.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

echo "--- Stow Configuration ---"
echo "📦 Stow (source) directory: $SCRIPT_DIR"
echo "🎯 Target (home) directory: $WSL_HOME"
echo "--------------------------"


STOW_PACKAGES=(
    git
    zsh
    nvim
    shell
    npm
    pip
    docker
    go
    copilot
)

# Stow dotfiles to the correct WSL home directory.
# -d (--dir) explicitly sets the directory where the packages are located.
# -t (--target) sets the destination directory for the symlinks.
# --no-folding is more robust for WSL/NTFS environments.
# Crucially, we temporarily set HOME=$WSL_HOME for the command's execution.
# This overrides any incorrect environment variables that Stow might be using internally.
HOME="$WSL_HOME" stow --dir="$SCRIPT_DIR" --target="$WSL_HOME" --verbose --no-folding --restow "${STOW_PACKAGES[@]}"

echo "✅ Dotfiles stowed successfully to $WSL_HOME"
