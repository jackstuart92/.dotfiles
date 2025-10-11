#!/usr/bin/env bash

set -uo pipefail

# --- Determine the correct home directory for WSL ---
# The $HOME variable in WSL can sometimes point to the Windows user profile (/mnt/c/Users/...).
# We explicitly find the correct Linux home directory from /etc/passwd to be safe.
WSL_HOME=$(getent passwd "$USER" | cut -d: -f6)

if [ -z "$WSL_HOME" ]; then
    echo "❌ Could not determine the correct WSL home directory for user '$USER'. Exiting."
    exit 1
fi

# --- Determine the absolute path to the dotfiles directory ---
# This is more robust than `cd` as it allows us to explicitly tell Stow where to find the packages.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

echo "--- Stow Configuration ---"
echo "📦 Stow (source) directory: $SCRIPT_DIR"
echo "🎯 Target (home) directory: $WSL_HOME"
echo "--------------------------"

SHOW_STOW_BUGS=false
if [[ "${1:-}" == "--verbose-stow-bugs" ]]; then
    echo "🐛 Verbose stow bug reporting enabled."
    SHOW_STOW_BUGS=true
    shift
fi

BUGS_DETECTED=false

STOW_PACKAGES=(
    git
    zsh
    shell
    npm
    pip
    docker
    copilot
)

# --- Pre-Stow checks and backups ---
# Before running stow, check for conflicting files in the target directory.
# Back up any conflicting files to avoid data loss.
for pkg in "${STOW_PACKAGES[@]}"; do
    # A dry run of stow will exit with 1 if it detects conflicts. We use `|| true` to prevent the script from exiting.
    stow_precheck_output=$(stow --dir="$SCRIPT_DIR" --target="$WSL_HOME" --no --verbose --ignore=".aws" --ignore=".azure" "${pkg}" 2>&1 || true)

    # Check for bugs, but don't print them yet.
    if echo "$stow_precheck_output" | grep -q 'BUG in find_stowed_path'; then
        BUGS_DETECTED=true
    fi

    conflicts=$(echo "$stow_precheck_output" \
        | grep 'existing target is neither a link nor a directory' \
        | sed -e 's/.*neither a link nor a directory: //' || true)

    if [ -n "$conflicts" ]; then
        echo "$conflicts" | while read -r conflict; do
            if [ -e "$WSL_HOME/$conflict" ]; then
                BACKUP_FILE="$WSL_HOME/${conflict}.bak.$(date +%F-%T)"
                echo "⚠️  Conflict detected: '$conflict' exists. Backing up to '$BACKUP_FILE'"
                mv "$WSL_HOME/$conflict" "$BACKUP_FILE"
            fi
        done
    fi
done

# Stow dotfiles to the correct WSL home directory.
# -d (--dir) explicitly sets the directory where the packages are located.
# -t (--target) sets the destination directory for the symlinks.
# --no-folding is more robust for WSL/NTFS environments.
# Crucially, we temporarily set HOME=$WSL_HOME for the command's execution.
# This overrides any incorrect environment variables that Stow might be using internally.
stow_final_output=$(HOME="$WSL_HOME" stow --dir="$SCRIPT_DIR" --target="$WSL_HOME" --verbose --no-folding --restow --ignore=".aws" --ignore=".azure" "${STOW_PACKAGES[@]}" 2>&1 || true)

# Check for bugs in the final output
if echo "$stow_final_output" | grep -q 'BUG in find_stowed_path'; then
    BUGS_DETECTED=true
fi

# Print the output, filtering bug messages if the flag is not set
if [ "$SHOW_STOW_BUGS" = true ]; then
    echo "$stow_final_output"
else
    echo "$stow_final_output" | grep -v 'BUG in find_stowed_path'
fi


echo "✅ Dotfiles stowed successfully to $WSL_HOME"

if [ "$BUGS_DETECTED" = true ] && [ "$SHOW_STOW_BUGS" = false ]; then
    echo "ℹ️  (Note: Harmless stow BUG messages were detected and suppressed. Run with --verbose-stow-bugs to see them.)"
fi
