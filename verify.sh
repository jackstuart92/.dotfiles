#!/usr/bin/env bash

# Verify that everything install.sh is supposed to set up is actually in place.
# Exits 0 if all checks pass, 1 if any fail.

set -uo pipefail

PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
RESET='\033[0m'

ok()   { echo -e "  ${GREEN}[✓]${RESET} $1"; (( PASS++ )) || true; }
fail() { echo -e "  ${RED}[✗]${RESET} $1"; (( FAIL++ )) || true; }
info() { echo -e "  ${YELLOW}[!]${RESET} $1"; }
header() { echo ""; echo "=== $1 ==="; }

# --- Brew formulae ---

BREW_PACKAGES=(
    "git"
    "gh"
    "stow"
    "wget"
    "openssl"
    "jq"
    "yq"
    "go"
    "go-task"
    "gradle"
    "maven"
    "jenv"
    "nvm"
    "python@3.12"
    "pyenv"
    "pyenv-virtualenv"
    "podman"
    "neovim"
    "awscli"
    "aws-sam-cli"
    "azure-cli"
    "azure/bicep/bicep"
    "cocoapods"
    "ios-deploy"
    "mas"
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
)

BREW_CASKS=(
    "google-cloud-sdk"
    "flutter"
    "android-studio"
    "docker"
    "font-meslo-lg-nerd-font"
    "ghostty"
    "google-chrome"
    "visual-studio-code"
)

header "Homebrew"
if command -v brew &>/dev/null; then
    ok "brew installed ($(brew --version | head -1))"
else
    fail "brew not found — nothing else can be checked"
    exit 1
fi

header "Brew formulae"
for pkg in "${BREW_PACKAGES[@]}"; do
    if brew list --formula "$pkg" &>/dev/null; then
        ok "$pkg"
    else
        fail "$pkg"
    fi
done

header "Brew casks"
for cask in "${BREW_CASKS[@]}"; do
    if brew list --cask "$cask" &>/dev/null; then
        ok "$cask"
    else
        fail "$cask"
    fi
done

header "Shell"
if command -v starship &>/dev/null; then
    ok "starship installed ($(starship --version))"
else
    fail "starship not found"
fi

if [ -f "$HOME/.config/starship.toml" ]; then
    ok "starship config present (~/.config/starship.toml)"
else
    fail "starship config not found — run ./stow.sh"
fi

header "Xcode"
if ls /Applications/Xcode*.app &>/dev/null; then
    XCODE_PATH=$(ls -d /Applications/Xcode*.app 2>/dev/null | head -1)
    ok "Xcode installed ($XCODE_PATH)"

    ACTIVE=$(xcode-select -p 2>/dev/null)
    if [[ "$ACTIVE" == "${XCODE_PATH}/Contents/Developer" ]]; then
        ok "xcode-select points at full Xcode ($ACTIVE)"
    else
        fail "xcode-select points at '$ACTIVE' (expected '${XCODE_PATH}/Contents/Developer')"
        info "Fix: sudo xcode-select --switch '${XCODE_PATH}/Contents/Developer'"
    fi

    # Xcode 15+ no longer bundles simulator runtimes — they must be downloaded separately.
    RUNTIME_COUNT=$(xcrun simctl list runtimes 2>/dev/null | grep -c "iOS\|watchOS\|tvOS\|visionOS" || true)
    if [ "$RUNTIME_COUNT" -gt 0 ]; then
        ok "Simulator runtimes installed ($RUNTIME_COUNT found)"
    else
        fail "No simulator runtimes installed"
        info "Fix: Open Xcode → Settings → Platforms and download iOS Simulator"
    fi
else
    fail "Xcode.app not found in /Applications"
    info "Install via: mas install 497799835"
fi

header "Android"
ANDROID_SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
if [ -d "$ANDROID_SDK" ]; then
    ok "Android SDK found at $ANDROID_SDK"
else
    fail "Android SDK not found (expected $ANDROID_SDK)"
    info "Fix: Open Android Studio and complete the setup wizard to install the SDK"
fi

header "Rosetta 2 (Apple Silicon)"
if [[ "$(uname -m)" == "arm64" ]]; then
    if /usr/bin/pgrep -q oahd; then
        ok "Rosetta 2 running"
    elif arch -x86_64 true &>/dev/null; then
        ok "Rosetta 2 installed"
    else
        fail "Rosetta 2 not installed"
        info "Fix: sudo softwareupdate --install-rosetta --agree-to-license"
    fi
else
    info "Intel Mac — Rosetta 2 not applicable"
fi

header "Flutter doctor"
if command -v flutter &>/dev/null; then
    echo ""
    flutter doctor 2>&1 | sed 's/^/  /'
else
    fail "flutter not found in PATH"
fi

# --- Summary ---

echo ""
echo "=============================="
echo -e "  ${GREEN}Passed: $PASS${RESET}   ${RED}Failed: $FAIL${RESET}"
echo "=============================="
echo ""

[ "$FAIL" -eq 0 ]
