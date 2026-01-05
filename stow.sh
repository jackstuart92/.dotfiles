#!/usr/bin/env bash

set -euo pipefail

# --- Determine the correct home directory ---
OS=$(uname -s)
TARGET_HOME=""

if [ "$OS" = "Linux" ]; then
    # The $HOME variable in WSL can sometimes point to the Windows user profile (/mnt/c/Users/...).
    # We explicitly find the correct Linux home directory from /etc/passwd to be safe.
    TARGET_HOME=$(getent passwd "$USER" | cut -d: -f6)
    if [ -z "$TARGET_HOME" ]; then
        echo "❌ Could not determine the correct home directory for user '$USER' on Linux. Exiting."
        exit 1
    fi
elif [ "$OS" = "Darwin" ]; then
    TARGET_HOME="$HOME"
else
    echo "❌ Unsupported operating system: $OS. This script is for WSL (Linux) and macOS (Darwin)."
    exit 1
fi

# --- Determine the absolute path to the dotfiles directory ---
# This is more robust than `cd` as it allows us to explicitly tell Stow where to find the packages.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

echo "--- Stow Configuration ---"
echo "📦 Stow (source) directory: $SCRIPT_DIR"
echo "🎯 Target (home) directory: $TARGET_HOME"
echo "--------------------------"


STOW_PACKAGES=(
    git
    zsh
    shell
    npm
    pip
    docker
    go
    copilot
)

# Stow dotfiles to the correct home directory.
# -d (--dir) explicitly sets the directory where the packages are located.
# -t (--target) sets the destination directory for the symlinks.
# --no-folding is more robust for WSL/NTFS environments.
# Crucially, we temporarily set HOME=$TARGET_HOME for the command's execution.
# This overrides any incorrect environment variables that Stow might be using internally.
HOME="$TARGET_HOME" stow --dir="$SCRIPT_DIR" --target="$TARGET_HOME" --verbose --no-folding --restow "${STOW_PACKAGES[@]}"

echo "✅ Dotfiles stowed successfully to $TARGET_HOME"
