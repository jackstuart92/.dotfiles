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

# --- Package lists ---

BREW_PACKAGES=(
    # Core
    "git"
    "gh"
    "stow"
    "wget"
    "openssl"
    "jq"
    "yq"

    # Build / runtimes
    "go"
    "go-task"
    "gradle"
    "maven"
    "jenv"
    "nvm"
    "python@3.15"
    "pyenv"
    "pyenv-virtualenv"

    # Containers
    "podman"

    # Editors
    "neovim"

    # Cloud CLIs
    "awscli"
    "aws-sam-cli"
    "azure-cli"
    "bicep"

    # iOS / Flutter native toolchain
    "cocoapods"
    "ios-deploy"
    "mas"

    # Quality-of-life CLIs (from macTerminalTools.md)
    "lazygit"
    "lazydocker"
    "fzf"
    "ripgrep"
    "zoxide"
    "tmux"
    "bat"
    "git-delta"
    "eza"
    "tldr"
    "shellcheck"
)

BREW_CASKS=(
    "google-cloud-sdk"
    "flutter"
    "docker"
    "font-meslo-lg-nerd-font"
    "ghostty"
    "visual-studio-code"
)

APT_PACKAGES=(
    # Core
    "git"
    "stow"
    "wget"
    "curl"
    "openssl"
    "jq"

    # Build deps (for pyenv / go-task / etc.)
    "build-essential"
    "libssl-dev"
    "zlib1g-dev"
    "libbz2-dev"
    "libreadline-dev"
    "libsqlite3-dev"
    "llvm"
    "libncursesw5-dev"
    "xz-utils"
    "tk-dev"
    "libxml2-dev"
    "libxmlsec1-dev"
    "libffi-dev"
    "liblzma-dev"

    # Runtimes
    "golang-go"
    "gradle"
    "maven"
    "python3"

    # Containers
    "podman"

    # Editors
    "neovim"

    # QoL CLIs available in apt
    "fzf"
    "ripgrep"
    "zoxide"
    "tmux"
    "bat"
    "eza"
    "tldr"
    "shellcheck"
)

install_oh_my_zsh() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "Installing oh-my-zsh..."
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
}

install_macos() {
    echo "Installing packages for macOS..."

    # Xcode Command Line Tools are a hard prerequisite for brew and Flutter iOS builds.
    if ! xcode-select -p >/dev/null 2>&1; then
        echo "Installing Xcode Command Line Tools (a GUI dialog will appear)..."
        xcode-select --install || true
    fi

    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    echo "Updating Homebrew..."
    brew update
    echo "Installing formulae..."
    brew install "${BREW_PACKAGES[@]}"
    echo "Installing casks..."
    brew install --cask "${BREW_CASKS[@]}"

    install_oh_my_zsh

    # Rosetta 2 — some CocoaPods / native gems still assume it on Apple Silicon.
    if [[ "$(uname -m)" == "arm64" ]] && ! /usr/bin/pgrep -q oahd; then
        echo "Installing Rosetta 2..."
        sudo softwareupdate --install-rosetta --agree-to-license
    fi

    # Xcode (full IDE) is a ~15GB download — ask first.
    if command -v mas >/dev/null 2>&1 && ! ls /Applications/Xcode*.app >/dev/null 2>&1; then
        read -rp "Install Xcode from the Mac App Store via mas? (y/n): " xc
        if [[ "$xc" =~ ^[Yy]$ ]]; then
            mas install 497799835 && sudo xcodebuild -license accept
        fi
    fi

    # Print Flutter status so user sees what manual steps remain.
    if command -v flutter >/dev/null 2>&1; then
        flutter doctor || true
    fi

    echo "macOS setup complete."
}

install_ubuntu() {
    echo "Installing packages for Ubuntu..."
    sudo apt-get update
    sudo apt-get install -y "${APT_PACKAGES[@]}"

    # GitHub CLI — needs its own apt source.
    if ! command -v gh &> /dev/null; then
        echo "Installing gh..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
            | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
        sudo apt-get update
        sudo apt-get install -y gh
    fi

    # go-task
    if ! command -v task &> /dev/null; then
        echo "Installing go-task..."
        go install github.com/go-task/task/v3/cmd/task@latest
    fi

    # nvm
    if [ ! -d "$HOME/.nvm" ]; then
        echo "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    fi

    # pyenv
    if ! command -v pyenv &> /dev/null; then
        echo "Installing pyenv..."
        curl https://pyenv.run | bash
    fi

    # lazygit (no official apt package)
    if ! command -v lazygit &> /dev/null; then
        echo "Installing lazygit..."
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
        tar -xf /tmp/lazygit.tar.gz -C /tmp lazygit
        sudo install /tmp/lazygit /usr/local/bin
        rm -f /tmp/lazygit /tmp/lazygit.tar.gz
    fi

    # lazydocker
    if ! command -v lazydocker &> /dev/null; then
        echo "Installing lazydocker..."
        curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
    fi

    # git-delta (not in default apt repos)
    if ! command -v delta &> /dev/null; then
        echo "Installing git-delta..."
        DELTA_VERSION=$(curl -s "https://api.github.com/repos/dandavison/delta/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
        curl -Lo /tmp/delta.deb "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_amd64.deb"
        sudo dpkg -i /tmp/delta.deb
        rm -f /tmp/delta.deb
    fi

    install_oh_my_zsh

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
