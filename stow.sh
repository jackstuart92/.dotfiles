#!/usr/bin/env bash

set -euo pipefail

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

# Stow dotfiles
stow --verbose --target="$HOME" --restow "${STOW_PACKAGES[@]}"

echo "✅ Dotfiles stowed"
