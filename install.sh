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
    "zsh"
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
    "zsh"
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

    # Install Oh My Zsh non-interactively
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    # Set Zsh as the default shell
    local zsh_path
    zsh_path=$(which zsh)
    if [ -n "$zsh_path" ] && [ "$SHELL" != "$zsh_path" ]; then
        echo "Setting Zsh as the default shell. You may be prompted for your password."
        if chsh -s "$zsh_path"; then
            echo "✅ Default shell changed to Zsh. Please log out and back in for the change to take effect."
        else
            echo "⚠️  Failed to change default shell. Please run 'chsh -s $(which zsh)' manually."
        fi
    fi

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
    # We check for the directory first, as a failed install can leave it behind
    # without the `pyenv` command being available in the PATH.
    if [ -d "$HOME/.pyenv" ]; then
        # If the command exists in the current shell, we assume it's correctly installed.
        # Note: This might not be true if the shell hasn't been reloaded, but it's a safe check.
        if command -v pyenv &>/dev/null; then
            echo "✅ pyenv is already installed and available."
        else
            # The directory exists, but the command doesn't. This indicates a broken/partial install.
            echo "⚠️  Existing but incomplete pyenv installation found at ~/.pyenv."
            read -rp "Do you want to remove it and reinstall? (y/N) " choice
            if [[ "$choice" =~ ^[Yy]$ ]]; then
                echo "Removing existing ~/.pyenv directory..."
                rm -rf "$HOME/.pyenv"
                echo "Installing pyenv..."
                curl https://pyenv.run | bash
            else
                echo "Skipping pyenv installation. You may need to manually configure your shell to use it."
            fi
        fi
    else
        # The directory doesn't exist, so we should install it.
        echo "Installing pyenv..."
        curl https://pyenv.run | bash
    fi

    # Install Oh My Zsh non-interactively
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "Installing Oh My Zsh..."
        # We need zsh installed first, which is in the APT_PACKAGES list
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    # Set Zsh as the default shell
    local zsh_path
    zsh_path=$(which zsh)
    if [ -n "$zsh_path" ] && [ "$SHELL" != "$zsh_path" ]; then
        echo "Setting Zsh as the default shell. You may be prompted for your password."
        if chsh -s "$zsh_path"; then
            echo "✅ Default shell changed to Zsh. Please log out and back in for the change to take effect."
        else
            echo "⚠️  Failed to change default shell. Please run 'chsh -s $(which zsh)' manually."
        fi
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


# --- Configure IDE Terminals ---
# Sets the default integrated terminal to Zsh for VS Code and Cursor.
configure_ide_terminals() {
    echo "Configuring default terminals for VS Code and Cursor..."

    local zsh_path
    zsh_path=$(which zsh)

    if [ -z "$zsh_path" ]; then
        echo "⚠️  zsh not found in PATH, skipping IDE terminal configuration."
        return
    fi

    local os
    os=$(detect_os)

    local default_profile_key=""
    local profiles_key=""
    local ide_settings_paths=()

    if [ "$os" = "macos" ]; then
        default_profile_key="terminal.integrated.defaultProfile.osx"
        profiles_key="terminal.integrated.profiles.osx"
        local vscode_mac_path="$HOME/Library/Application Support/Code/User/settings.json"
        local cursor_mac_path="$HOME/Library/Application Support/Cursor/User/settings.json"
        if [ -f "$vscode_mac_path" ]; then ide_settings_paths+=("$vscode_mac_path"); fi
        if [ -f "$cursor_mac_path" ]; then ide_settings_paths+=("$cursor_mac_path"); fi

    elif [ "$os" = "ubuntu" ]; then
        default_profile_key="terminal.integrated.defaultProfile.linux"
        profiles_key="terminal.integrated.profiles.linux"
        # For WSL, VS Code Server settings are used
        local vscode_wsl_path="$HOME/.vscode-server/data/Machine/settings.json"
        local cursor_wsl_path="$HOME/.cursor-server/data/Machine/settings.json" # Assumed path
        if [ -f "$vscode_wsl_path" ]; then ide_settings_paths+=("$vscode_wsl_path"); fi
        if [ -f "$cursor_wsl_path" ]; then ide_settings_paths+=("$cursor_wsl_path"); fi
    else
        echo "Unsupported OS for IDE terminal configuration. Skipping."
        return
    fi

    if [ ${#ide_settings_paths[@]} -eq 0 ]; then
        echo "No VS Code or Cursor settings files found to configure."
        return
    fi

    for settings_path in "${ide_settings_paths[@]}"; do
        echo "Updating settings in: $settings_path"
        
        local settings_dir
        settings_dir=$(dirname "$settings_path")
        if [ ! -d "$settings_dir" ]; then
            mkdir -p "$settings_dir"
            echo "Created directory $settings_dir"
        fi
        
        # Ensure the file is valid JSON, creating it if it doesn't exist or is empty
        if ! jq -e . "$settings_path" >/dev/null 2>&1; then
            echo "{}" > "$settings_path"
            echo "Created or repaired empty/invalid settings file."
        fi

        # Use jq to idempotently add the zsh profile and set it as the default
        local temp_file
        temp_file=$(mktemp)
        jq \
            --arg zsh_path "$zsh_path" \
            --arg default_profile_key "$default_profile_key" \
            --arg profiles_key "$profiles_key" \
            '
            .[$profiles_key].zsh = {"path": $zsh_path} |
            .[$default_profile_key] = "zsh"
            ' \
            "$settings_path" > "$temp_file" && mv "$temp_file" "$settings_path"
        
        echo "✅ Configured $settings_path to use zsh as the default terminal."
    done
}


# Main execution
main() {
    pre_flight_checks
    
    local os
    os=$(detect_os)

    if [ "$os" = "macos" ]; then
        install_macos
    elif [ "$os" = "ubuntu" ]; then
        install_ubuntu
    else
        echo "Unsupported OS: $os. Cannot install software."
        exit 1
    fi

    setup_windows_path
    configure_ide_terminals
}

main "$@"
