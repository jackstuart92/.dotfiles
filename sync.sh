#!/usr/bin/env bash

set -euo pipefail

# Function to detect the operating system
detect_os() {
    case "$(uname -s)" in
        Darwin)
            echo "macos"
            ;;
        Linux)
            echo "linux"
            ;;
        *)
            echo "unsupported"
            ;;
    esac
}

# Add a cron job to sync the dotfiles repository
add_cron_job() {
    local cron_job="0 * * * * cd $HOME/.dotfiles && git pull --quiet"
    (crontab -l 2>/dev/null | grep -Fv "$cron_job"; echo "$cron_job") | crontab -
    echo "Cron job added to sync dotfiles every hour."
}

# Main function
main() {
    OS=$(detect_os)
    if [ "$OS" = "macos" ] || [ "$OS" = "linux" ]; then
        add_cron_job
    else
        echo "Unsupported OS for cron job setup."
        exit 1
    fi
}

main "$@"
