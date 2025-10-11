#!/usr/bin/env bash

set -uo pipefail

# --- Test Runner Globals ---
FAILURES=0
CURRENT_OS=""

# --- Color Definitions ---
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'

# --- Test Helpers ---

# Detects the current operating system.
detect_os() {
    case "$(uname -s)" in
        Darwin) CURRENT_OS="macos" ;;
        Linux)
            if [ -f /etc/os-release ] && grep -q 'ID=ubuntu' /etc/os-release; then
                CURRENT_OS="ubuntu"
            else
                CURRENT_OS="linux" # Generic Linux
            fi
            ;;
        *) CURRENT_OS="unsupported" ;;
    esac
}

# Checks if a given command is available in the PATH.
check_command() {
    local cmd="$1"
    printf "Checking for command: %-25s" "$cmd"

    if command -v "$cmd" &> /dev/null; then
        printf "${COLOR_GREEN}[PASS]${COLOR_RESET}\n"
    else
        printf "${COLOR_RED}[FAIL]${COLOR_RESET} -> Not found in PATH\n"
        ((FAILURES++))
    fi
}

# Checks if a symlink exists and points to the correct source file.
check_symlink() {
    local target_in_home="$1"
    local source_in_dotfiles="$2"
    local test_name="~/${target_in_home}"
    local target_path="$HOME/$target_in_home"
    local expected_source_path="$HOME/.dotfiles/$source_in_dotfiles"

    printf "Checking symlink: %-27s" "$test_name"

    if [ ! -L "$target_path" ]; then
        if [ -e "$target_path" ]; then
            printf "${COLOR_RED}[FAIL]${COLOR_RESET} -> Not a symlink\n"
        else
            printf "${COLOR_RED}[FAIL]${COLOR_RESET} -> Missing\n"
        fi
        ((FAILURES++))
        return
    fi

    # Use readlink -f to get the canonical path of the file the link points to.
    # This is more robust than the custom canonical_path function.
    local actual_canonical_path
    actual_canonical_path=$(readlink -f "$target_path")

    if [ "$actual_canonical_path" != "$expected_source_path" ]; then
        printf "${COLOR_RED}[FAIL]${COLOR_RESET} -> Points to wrong location\n"
        echo "  - Expected: $expected_source_path"
        echo "  - Actual:   $actual_canonical_path"
        ((FAILURES++))
        return
    fi

    printf "${COLOR_GREEN}[PASS]${COLOR_RESET}\n"
}

# --- Test Suites ---

run_symlink_tests() {
    echo "--- Testing Symlinks ---"
    check_symlink ".gitconfig" "git/.gitconfig"
    check_symlink ".gitignore_global" "git/.gitignore_global"
    check_symlink ".zshrc" "zsh/.zshrc"
    check_symlink ".bashrc" "shell/.bashrc"
    check_symlink ".bash_profile" "shell/.bash_profile"
    check_symlink ".npmrc" "npm/.npmrc"
    check_symlink ".pip/pip.conf" "pip/.pip/pip.conf"
    check_symlink ".docker/config.json" "docker/config.json"
    check_symlink ".copilot-instructions" "copilot/.copilot-instructions"
}

run_software_tests() {
    echo ""
    echo "--- Testing Software Installations (OS: $CURRENT_OS) ---"

    # --- Cross-platform tools ---
    echo "Testing common core tools..."
    check_command "git"
    check_command "go"
    check_command "gradle"
    check_command "jq"
    check_command "mvn"
    check_command "openssl"
    check_command "podman"
    check_command "python3"
    check_command "stow"
    check_command "wget"
    check_command "nvim"
    check_command "task"

    echo ""
    echo "Testing environment managers..."
    # NVM and Pyenv are special; they are shell functions, not direct commands.
    # We check if the expected directories exist as a proxy.
    if [ -d "$HOME/.nvm" ]; then
        printf "Checking for nvm (directory): %-19s${COLOR_GREEN}[PASS]${COLOR_RESET}\n"
    else
        printf "Checking for nvm (directory): %-19s${COLOR_RED}[FAIL]${COLOR_RESET} -> Missing ~/.nvm\n"
        ((FAILURES++))
    fi
    if [ -d "$HOME/.pyenv" ]; then
        printf "Checking for pyenv (directory): %-18s${COLOR_GREEN}[PASS]${COLOR_RESET}\n"
    else
        printf "Checking for pyenv (directory): %-18s${COLOR_RED}[FAIL]${COLOR_RESET} -> Missing ~/.pyenv\n"
        ((FAILURES++))
    fi


    # --- OS-specific tools ---
    if [ "$CURRENT_OS" = "macos" ]; then
        echo ""
        echo "Testing macOS-specific tools..."
        check_command "brew"
        check_command "yq"
        check_command "code"
    elif [ "$CURRENT_OS" = "ubuntu" ]; then
        echo ""
        echo "Testing Ubuntu-specific tools..."
        check_command "curl"
        check_command "gcc"
        check_command "make"
    fi
}

# --- Main Test Execution ---
main() {
    echo "--- Running Dotfiles Environment Sanity Tests ---"
    detect_os

    if [ ! -d "$HOME/.dotfiles" ]; then
        echo -e "${COLOR_RED}CRITICAL: ~/.dotfiles directory not found. Cannot run tests.${COLOR_RESET}"
        exit 1
    fi
    
    run_symlink_tests
    run_software_tests

    echo ""
    echo "-------------------------------------------------"
    if [ "$FAILURES" -eq 0 ]; then
        echo -e "${COLOR_GREEN}🎉 All tests passed successfully! Your environment is ready.${COLOR_RESET}"
        exit 0
    else
        echo -e "${COLOR_RED}🔥 $FAILURES test(s) failed. Please review the output above.${COLOR_RESET}"
        exit 1
    fi
}

main "$@"
