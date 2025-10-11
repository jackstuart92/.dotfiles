#!/usr/bin/env bash

set -euo pipefail

# --- Helper Functions ---
# Checks if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Configuration Functions ---

# Configure Git user name and email
configure_git() {
    echo "--- Git Configuration ---"
    read -rp "Enter your Git name: " git_name
    read -rp "Enter your Git email: " git_email

    local gitconfig_local="git/.gitconfig.local"

    # Create local gitconfig if it doesn't exist
    if [ ! -f "$gitconfig_local" ]; then
        cp git/.gitconfig.template "$gitconfig_local"
    fi

    # Update the local gitconfig file
    cat > "$gitconfig_local" << EOL
[user]
    name = $git_name
    email = $git_email
EOL

    echo "✅ Git configured in $gitconfig_local"
    echo
}

# Configure SSH for GitHub
configure_ssh_github() {
    echo "--- GitHub SSH Configuration ---"
    
    # Determine GitHub host
    local github_host
    read -rp "Are you configuring for GitHub.com or a GitHub Enterprise server? (com/enterprise): " choice
    if [[ "$choice" =~ ^[Ee] ]]; then
        read -rp "Enter your GitHub Enterprise hostname (e.g., github.my-company.com): " github_host
    else
        github_host="github.com"
    fi
    echo "Configuring for host: $github_host"
    echo

    if ! command_exists ssh-keygen; then
        echo "⚠️ 'ssh-keygen' command not found. Please install OpenSSH and try again."
        return 1
    fi

    # Check for an existing SSH key
    local ssh_key_path="$HOME/.ssh/id_ed25519"
    if [ -f "$ssh_key_path" ]; then
        echo "✅ Found existing SSH key: $ssh_key_path"
    else
        echo "No ED25519 SSH key found. Let's generate a new one."
        read -rp "Enter the email address associated with your GitHub account: " github_email
        if [ -z "$github_email" ]; then
            echo "⚠️ Email cannot be empty. Skipping SSH key generation."
            return 1
        fi
        
        # Generate a new SSH key without a passphrase for automation
        mkdir -p "$HOME/.ssh"
        ssh-keygen -t ed25519 -C "$github_email" -f "$ssh_key_path" -N ""
        echo "✅ New SSH key generated at $ssh_key_path"
    fi

    echo
    echo "Please add the following public key to your GitHub account."
    echo "1. Go to https://$github_host/settings/keys"
    echo "2. Click 'New SSH key'"
    echo "3. Paste the key below into the 'Key' field and give it a title."
    echo "--- SSH Public Key ---"
    cat "${ssh_key_path}.pub"
    echo "----------------------"
    echo
    echo "🔒 If your organization requires SSO, you must authorize this key."
    echo "After adding the key, find it in your list of SSH keys and click 'Configure SSO' or 'Authorize'."
    echo
    
    read -rp "Press [Enter] once you have added and (if necessary) authorized the key."

    echo "Testing the SSH connection to $github_host..."
    ssh -o StrictHostKeyChecking=no -T "git@$github_host"
}

# Configure NPM for a private registry
configure_npm() {
    echo "--- NPM Private Registry ---"
    read -rp "Enter your private NPM registry URL (e.g., https://registry.my-company.com): " npm_registry
    read -rp "Enter the scope for this registry (e.g., @my-scope): " npm_scope
    read -rp "Enter your NPM auth token (will be stored in shell/env.template): " npm_token

    # Add registry config to .npmrc
    echo "$npm_scope:registry=$npm_registry" >> npm/.npmrc
    
    # Clean up URL for token config (remove https://)
    local cleaned_url
    cleaned_url=$(echo "$npm_registry" | sed 's|https?://||')
    echo "//$cleaned_url/:_authToken=\${NPM_TOKEN}" >> npm/.npmrc

    # Add token to env file
    echo "export NPM_TOKEN=\"$npm_token\"" >> shell/.env
    
    echo "✅ NPM configured in npm/.npmrc and shell/.env"
    echo
}

# Configure Pip for a private registry
configure_pip() {
    echo "--- Pip Private Registry ---"
    read -rp "Enter your private Pip registry index URL: " pip_registry

    sed -i.bak "s|; extra-index-url = .*|extra-index-url = $pip_registry|" pip/.pip/pip.conf && rm pip/.pip/pip.conf.bak

    echo "✅ Pip configured in pip/.pip/pip.conf"
    echo
}

# Configure Docker for a private registry
configure_docker() {
    echo "--- Docker Private Registry ---"
    if ! command_exists base64 || ! command_exists jq; then
        echo "⚠️ 'base64' and 'jq' are required for this step. Please install them and re-run."
        return 1
    fi

    read -rp "Enter your private Docker registry URL (e.g., https://docker.my-company.com): " docker_registry
    read -rp "Enter your Docker username: " docker_user
    read -rsp "Enter your Docker password/token: " docker_pass
    echo

    local auth_token
    auth_token=$(echo -n "$docker_user:$docker_pass" | base64)

    # Use jq to update the config.json
    jq --arg registry "$docker_registry" --arg token "$auth_token" \
        '.auths[$registry] = { "auth": $token }' \
        docker/.docker/config.json > docker/.docker/config.json.tmp && \
        mv docker/.docker/config.json.tmp docker/.docker/config.json

    echo "✅ Docker configured in docker/.docker/config.json"
    echo
}

# Configure Go for private modules
configure_go() {
    echo "--- Go Private Modules ---"
    read -rp "Enter your GOPRIVATE path (e.g., *.my-company.com, leave blank to skip): " goprivate
    
    # Add GOPRIVATE to env file if provided
    if [[ -n "$goprivate" ]]; then
        echo "export GOPRIVATE=\"$goprivate\"" >> shell/.env
        echo "✅ GOPRIVATE set in shell/.env"
    fi

    read -rp "Does your Go proxy require git authentication? (y/n): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        read -rp "Enter the git host for your Go modules (e.g., private.repo.com): " go_git_host
        read -rsp "Enter your personal access token for Go modules: " go_token
        echo

        if [[ -n "$go_git_host" ]] && [[ -n "$go_token" ]]; then
            local gitconfig_local="git/.gitconfig.local"
            # Create local gitconfig if it doesn't exist, to be safe
            if [ ! -f "$gitconfig_local" ]; then
                cp git/.gitconfig.template "$gitconfig_local"
            fi
            
            # Append the url."insteadOf" config to the local gitconfig
            {
                echo ""
                echo "[url \"https://oauth2:$go_token@$go_git_host\"]"
                echo "    insteadOf = https://$go_git_host"
            } >> "$gitconfig_local"

            echo "✅ Git configured for Go private modules in $gitconfig_local"
        else
            echo "⚠️ Skipping Go auth configuration, host or token was empty."
        fi
    fi
    echo "✅ Go configuration step complete."
    echo
}


# --- Main Execution ---
main() {
    echo "Starting interactive dotfiles configuration..."
    echo "Leave any prompt blank to skip that configuration."
    echo

    read -rp "Configure Git? (y/n): " choice
    [[ "$choice" =~ ^[Yy]$ ]] && configure_git

    read -rp "Configure SSH for GitHub? (y/n): " choice
    [[ "$choice" =~ ^[Yy]$ ]] && configure_ssh_github

    read -rp "Do you want to configure private registries/repositories? (y/n): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        echo
        read -rp "Configure NPM for a private registry? (y/n): " npm_choice
        [[ "$npm_choice" =~ ^[Yy]$ ]] && configure_npm
        
        read -rp "Configure Pip for a private registry? (y/n): " pip_choice
        [[ "$pip_choice" =~ ^[Yy]$ ]] && configure_pip

        read -rp "Configure Docker for a private registry? (y/n): " docker_choice
        [[ "$docker_choice" =~ ^[Yy]$ ]] && configure_docker
        
        read -rp "Configure Go for private modules? (y/n): " go_choice
        [[ "$go_choice" =~ ^[Yy]$ ]] && configure_go
    fi

    echo "🎉 Configuration complete!"
    echo "Remember to run './stow.sh' to apply your new configurations."
}

main "$@"
