#!/usr/bin/env bash

set -euo pipefail

# --- VSCode & Cursor Extension Installation ---
# Installs a list of essential extensions for VS Code and Cursor.

install_extensions() {
    if ! command -v code &> /dev/null; then
        echo "⚠️ 'code' command not found in PATH. Skipping VS Code extension installation."
        echo "   Please ensure VS Code is installed and its shell command is available."
        return
    fi

    echo "Installing VS Code / Cursor extensions..."

    # List of extensions to install
    # You can find extension IDs on their marketplace page.
    # Format: publisher.name
    local extensions=(
        # --- Language & Framework Support ---
        "waderyan.nodejs-extension-pack"   # Node.js (Debugger, Linter, etc.)
        "golang.Go"                        # Go Language Support
        "redhat.vscode-yaml"               # YAML Language Support
        "shanoor.vscode-nginx"             # NGINX Configuration Language Support
        "HashiCorp.terraform"              # Terraform Language Support
        
        # --- DevOps & Containers ---
        "ms-azuretools.vscode-docker"      # Docker & Docker Compose Support
        "ms-vscode-remote.remote-wsl"      # WSL Remote Development

        # --- Theme ---
        "Catppuccin.catppuccin-vsc-pack"   # Catppuccin Theme Pack
    )

    for extension in "${extensions[@]}"; do
        echo "Installing $extension..."
        if code --install-extension "$extension" --force; then
            echo "✅ Successfully installed $extension"
        else
            echo "❌ Failed to install $extension"
        fi
    done

    echo "Extension installation complete."
}

# This script is intended to be sourced, but can be run directly.
# The following line prevents execution when sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_extensions
fi
