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
    "python@3.12"
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
    "azure/bicep/bicep"

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
    "starship"
    "gitleaks"
)

BREW_CASKS=(
    "google-cloud-sdk"
    "flutter"
    "android-studio"
    "android-commandlinetools"
    "docker"
    "font-meslo-lg-nerd-font"
    "ghostty"
    "google-chrome"
    "visual-studio-code"
    "brave-browser"
    "discord"
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

# Install a brew formula, tracking failures without aborting the script.
brew_install() {
    local pkg="$1"
    if brew list --formula "$pkg" &>/dev/null; then
        echo "  [skip] $pkg already installed"
    elif brew install "$pkg"; then
        echo "  [ok]   $pkg"
    else
        echo "  [FAIL] $pkg — will retry at end"
        BREW_FAILED_FORMULAE+=("$pkg")
    fi
}

# Install a brew cask, tracking failures without aborting the script.
brew_cask_install() {
    local cask="$1"
    if brew list --cask "$cask" &>/dev/null; then
        echo "  [skip] $cask already installed"
    elif brew install --cask "$cask"; then
        echo "  [ok]   $cask"
    else
        echo "  [FAIL] $cask — will retry at end"
        BREW_FAILED_CASKS+=("$cask")
    fi
}

setup_flutter() {
    if ! command -v flutter >/dev/null 2>&1; then
        echo "  [skip] flutter not found, skipping Flutter setup"
        return
    fi

    echo "--- Flutter setup ---"

    # Ensure cmdline-tools are available at the Android Studio SDK location.
    # Flutter looks for the SDK at ~/Library/Android/sdk on macOS; the brew-installed
    # cmdline-tools live elsewhere, so we symlink them in.
    local android_sdk="$HOME/Library/Android/sdk"
    local brew_cmdline_tools
    brew_cmdline_tools="$(brew --prefix)/share/android-commandlinetools/cmdline-tools"
    if [ -d "$brew_cmdline_tools" ] && [ ! -e "$android_sdk/cmdline-tools" ]; then
        mkdir -p "$android_sdk"
        ln -s "$brew_cmdline_tools" "$android_sdk/cmdline-tools"
        echo "  [ok]   linked cmdline-tools into $android_sdk"
    fi

    # Disable telemetry.
    flutter --disable-telemetry >/dev/null 2>&1 || true
    echo "  [ok]   telemetry disabled"

    # Accept Android SDK licences non-interactively.
    if [ -d "$android_sdk/cmdline-tools" ]; then
        yes | ANDROID_HOME="$android_sdk" flutter doctor --android-licenses >/dev/null 2>&1 || true
        echo "  [ok]   Android licenses accepted"
    else
        echo "  [warn] cmdline-tools not found — skipping license acceptance"
    fi

    flutter doctor || true
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
        # Pick up brew in PATH for Apple Silicon
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null || true)"
    fi
    echo "Updating Homebrew..."
    brew update

    # Add taps required by packages in the lists above.
    echo "Adding brew taps..."
    brew tap homebrew/cask-fonts 2>/dev/null || true
    brew tap azure/bicep 2>/dev/null || true

    BREW_FAILED_FORMULAE=()
    BREW_FAILED_CASKS=()

    echo "Installing formulae..."
    for pkg in "${BREW_PACKAGES[@]}"; do
        brew_install "$pkg"
    done

    echo "Installing casks..."
    for cask in "${BREW_CASKS[@]}"; do
        brew_cask_install "$cask"
    done

    if [ ${#BREW_FAILED_FORMULAE[@]} -gt 0 ] || [ ${#BREW_FAILED_CASKS[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  The following packages failed to install and need attention:"
        for pkg in "${BREW_FAILED_FORMULAE[@]}"; do
            echo "    brew install $pkg"
        done
        for cask in "${BREW_FAILED_CASKS[@]}"; do
            echo "    brew install --cask $cask"
        done
        echo ""
    fi

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

    # Ensure xcode-select points at the full Xcode app, not just the CLI tools.
    # Without this, `flutter doctor` reports "Unable to get list of installed Simulator runtimes".
    if ls /Applications/Xcode*.app >/dev/null 2>&1; then
        XCODE_PATH=$(ls -d /Applications/Xcode*.app 2>/dev/null | head -1)
        if [[ "$(xcode-select -p 2>/dev/null)" != "${XCODE_PATH}/Contents/Developer" ]]; then
            echo "Switching xcode-select to $XCODE_PATH..."
            sudo xcode-select --switch "${XCODE_PATH}/Contents/Developer"
        fi
    fi

    setup_flutter

    echo ""
    echo "========================================"
    echo "  macOS setup complete."
    echo ""
    echo "  Manual steps still required:"
    echo "  1. iOS Simulator: Open Xcode → Settings → Platforms → download iOS Simulator"
    echo "  2. Run ./configure.sh to set up Git, SSH, and private registries"
    echo "  3. Run ./stow.sh to symlink dotfiles into your home directory"
    echo "  4. Run ./verify.sh to confirm everything is in order"
    echo "========================================"
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

    # starship (not in apt)
    if ! command -v starship &> /dev/null; then
        echo "Installing starship..."
        curl -sS https://starship.rs/install.sh | sh -s -- --yes
    fi

    # Brave browser
    if ! command -v brave-browser &> /dev/null; then
        echo "Installing Brave..."
        curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
            | sudo dd of=/usr/share/keyrings/brave-browser-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
            | sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null
        sudo apt-get update
        sudo apt-get install -y brave-browser
    fi

    # Discord (.deb)
    if ! command -v discord &> /dev/null; then
        echo "Installing Discord..."
        curl -Lo /tmp/discord.deb "https://discord.com/api/download?platform=linux&format=deb"
        sudo dpkg -i /tmp/discord.deb || sudo apt-get install -yf
        rm -f /tmp/discord.deb
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
