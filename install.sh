#!/usr/bin/env bash

set -euo pipefail

# --- Pre-flight Checks for WSL ---
# Ensures the repository is in the correct location for Stow to work reliably.
if [[ -n "${WSL_DISTRO_NAME-}" ]] && [[ "$(pwd)" == /mnt/* ]]; then
    echo "⚠️ The dotfiles repository is currently on the Windows filesystem (/mnt/...)."
    echo "Stow works best when the repository is inside the WSL filesystem."
    echo
    
    read -rp "Do you want to move the repo to your WSL home (~/.dotfiles)? (Y/n) " choice
    if [[ "$choice" =~ ^[Nn]$ ]]; then
        echo "Aborting. Please re-clone the repository into your WSL home directory (e.g., /home/your_user/.dotfiles)."
        exit 1
    else
        # Move the repo and create a symlink back to the original location
        local new_path="$HOME/.dotfiles"
        if [ -d "$new_path" ]; then
            echo "Error: A directory already exists at $new_path."
            exit 1
        fi
        
        # Get the absolute path of the current directory
        local current_path
        current_path=$(pwd)
        
        # Move the directory
        echo "Moving repository to $new_path..."
        mv -T "$current_path" "$new_path"
        
        # Create a symlink from the new location back to the old one
        echo "Creating a symlink from $new_path to $current_path..."
        ln -s "$new_path" "$current_path"
        
        echo "✅ Repository moved. Please 'cd' into the new directory and re-run this script:"
        echo "cd $new_path && ./install.sh"
        exit 0
    fi
fi


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

main() {
    OS=$(detect_os)
    case "$OS" in
        macos)
            install_macos
            ;;
        ubuntu)
            install_ubuntu
            ;;
        *)
            echo "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
}

main "$@"
