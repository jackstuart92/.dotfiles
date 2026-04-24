#!/usr/bin/env bash
# Opt-in macOS system tweaks. Not auto-run by install.sh.
# Run manually: ./macos-defaults.sh

set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This script only runs on macOS."
    exit 1
fi

echo "Applying macOS defaults..."

# --- Finder ---
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# --- Keyboard ---
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# --- Screenshots ---
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location "$HOME/Screenshots"
defaults write com.apple.screencapture type -string png
defaults write com.apple.screencapture disable-shadow -bool true

# --- Dock ---
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock tilesize -int 42
defaults write com.apple.dock show-recents -bool false

# --- Trackpad ---
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true

# --- Network / USB cruft ---
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# --- Restart affected apps ---
killall Finder Dock SystemUIServer 2>/dev/null || true

echo "✅ macOS defaults applied. Some changes may require a logout/restart."
