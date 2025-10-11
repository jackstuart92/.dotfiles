#!/usr/bin/env bash

set -euo pipefail

# Function to detect the operating system
detect_os() {
    case "$(uname -s)" in
        Darwin)
            echo "macos"
            ;;
        Linux)
            if [ -f /etc/os-release ]; then
                # shellcheck source=/etc/os-release
                . /etc/os-release
                if [ "$ID" = "ubuntu" ]; then
                    echo "ubuntu"
                else
                    echo "linux"
                fi
            else
                echo "linux"
            fi
            ;;
        *)
            echo "unsupported"
            ;;
    esac
}

# Package lists
BREW_PACKAGES=(
    "git"
    "go-task"
    "go"
    "gradle"
    "jenv"
    "jq"
    "yq"
    "maven"
    "nvm"
    "openssl"
    "podman"
    "python@3.15"
    "pyenv"
    "pyenv-virtualenv"
    "stow"
    "wget"
    "visual-studio-code"
    "neovim"
)

APT_PACKAGES=(
    "git"
    "golang-go" # go
    "gradle"
    "jq"
    "maven"
    # "nvm" # Removed, will be installed via script
    "openssl"
    "podman"
    "python3"
    # "pyenv" # Removed, will be installed via script
    "stow"
    "wget"
    "build-essential" # for go-task and others
    "libssl-dev"
    "zlib1g-dev"
    "libbz2-dev"
    "libreadline-dev"
    "libsqlite3-dev"
    "curl"
    "llvm"
    "libncursesw5-dev"
    "xz-utils"
    "tk-dev"
    "libxml2-dev"
    "libxmlsec1-dev"
    "libffi-dev"
    "liblzma-dev"
    "neovim"
)


install_macos() {
    echo "Installing packages for macOS..."
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    echo "Updating Homebrew..."
    brew update
    echo "Installing packages..."
    brew install "${BREW_PACKAGES[@]}"
    echo "macOS setup complete."
}

install_ubuntu() {
    echo "Installing packages for Ubuntu..."
    sudo apt-get update
    sudo apt-get install -y "${APT_PACKAGES[@]}"

    # Special handling for go-task
    if ! command -v task &> /dev/null; then
        echo "Installing go-task..."
        go install github.com/go-task/task/v3/cmd/task@latest
    fi

    # Special handling for nvm
    if [ ! -d "$HOME/.nvm" ]; then
        echo "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    fi
    
    # Special handling for pyenv
    if ! command -v pyenv &> /dev/null; then
        echo "Installing pyenv..."
        curl https://pyenv.run | bash
    fi

    echo "Ubuntu setup complete."
}

# --- Setup Windows PATH in WSL ---
# Adds common Windows applications to the WSL PATH for easy access.
setup_windows_path() {
    if ! grep -q -i "wsl" /proc/version; then
        echo "Not running in WSL, skipping Windows PATH setup."
        return
    fi

    echo "Running in WSL, configuring PATH for Windows applications..."

    local win_user_profile
    win_user_profile=$(powershell.exe -Command 'Write-Output $env:USERPROFILE' | tr -d '\r')

    if [ -z "$win_user_profile" ]; then
        echo "Could not determine Windows user profile. Aborting PATH setup."
        return
    fi

    local wsl_user_profile
    wsl_user_profile=$(wslpath "$win_user_profile")

    local path_additions=""
    local vscode_path="$wsl_user_profile/AppData/Local/Programs/Microsoft VS Code/bin"
    local cursor_path="$wsl_user_profile/AppData/Local/Programs/Cursor/resources/app/bin"
    local chrome_path="/mnt/c/Program Files/Google/Chrome/Application"
    local edge_path="/mnt/c/Program Files (x86)/Microsoft/Edge/Application"

    if [ -d "$vscode_path" ]; then
        path_additions="$path_additions:$vscode_path"
        echo "Found VS Code."
    fi

    if [ -d "$cursor_path" ]; then
        path_additions="$path_additions:$cursor_path"
        echo "Found Cursor."
    fi

    if [ -d "$chrome_path" ]; then
        path_additions="$path_additions:$chrome_path"
        echo "Found Google Chrome."
    fi

    if [ -d "$edge_path" ]; then
        path_additions="$path_additions:$edge_path"
        echo "Found Microsoft Edge."
    fi

    if [ -n "$path_additions" ]; then
        local profile_script="/etc/profile.d/99-windows-apps.sh"
        echo "Adding applications to PATH. You may be prompted for your password."
        echo "# This file is auto-generated. Adds common Windows apps to the WSL PATH." | sudo tee "$profile_script" > /dev/null
        # Note: We use a raw string literal with single quotes to prevent shell expansion here.
        echo 'export PATH="$PATH'"$path_additions" | sudo tee -a "$profile_script" > /dev/null
        echo "✅ Windows application paths configured. Please restart your shell for changes to take effect."
    else
        echo "No Windows applications found in default locations."
    fi
}


# Main execution
main() {
    detect_os
    setup_windows_path
}

main "$@"
