#!/usr/bin/env bash

set -euo pipefail

# --- Pre-flight Checks for WSL ---
# Ensures the repository is in the correct location for Stow to work reliably.
pre_flight_checks() {
    # Check for 'wsl' in /proc/version as a reliable indicator.
    if grep -q -i "wsl" /proc/version && [[ "$(pwd)" == /mnt/* ]]; then
        echo "⚠️ The dotfiles repository is currently on the Windows filesystem (/mnt/...)."
        echo "Stow works best when the repository is inside the WSL filesystem."
        echo
        
        read -rp "Do you want to copy the repo to your WSL home (~/.dotfiles) to continue? (Y/n) " choice
        if [[ "$choice" =~ ^[Nn]$ ]]; then
            echo "Aborting. Please re-clone the repository into your WSL home directory (e.g., /home/your_user/.dotfiles)."
            exit 1
        else
            # Copy the repo instead of moving it to avoid file lock issues from editors like VS Code.
            local new_path="$HOME/.dotfiles"
            if [ -d "$new_path" ]; then
                echo "Error: A directory already exists at $new_path. Please remove it first to proceed:"
                echo "rm -rf $new_path"
                exit 1
            fi
            
            local current_path
            current_path=$(pwd)
            
            echo "Copying repository to $new_path..."
            # Create the destination directory first.
            sudo mkdir -p "$new_path"
            # Use cp -aT to copy all contents, including hidden dotfiles, into the new directory.
            if sudo cp -aT "$current_path" "$new_path"; then
                # Set ownership to the current user to avoid sudo issues later
                sudo chown -R "$USER:$USER" "$new_path"
                
                echo "✅ Repository successfully copied to $new_path."
                echo
                echo "⚠️ IMPORTANT: The original directory has not been removed automatically."
                echo
                echo "Please perform the following steps:"
                echo "1. Close this terminal and any programs using the old directory (like VS Code)."
                echo "2. You may want to manually delete the old repository directory: $current_path"
                echo "3. Open a NEW WSL terminal. It will start in your WSL home directory."
                echo "4. Navigate to the new directory and re-run the installer:"
                echo "   cd ~/.dotfiles && ./install.sh"
                exit 0
            else
                echo "❌ Failed to copy the repository to $new_path."
                exit 1
            fi
        fi
    fi
}

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
        # The following line is carefully quoted to ensure $PATH is expanded when the shell starts,
        # not when this script is run.
        echo "export PATH=\"\$PATH${path_additions}\"" | sudo tee -a "$profile_script" > /dev/null
        echo "✅ Windows application paths configured. Please restart your shell for changes to take effect."
    else
        echo "No Windows applications found in default locations."
    fi
}


# Main execution
main() {
    pre_flight_checks
    detect_os
    setup_windows_path
}

main "$@"
