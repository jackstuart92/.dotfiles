# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific aliases and functions

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# --- Modern CLI tool integrations (guarded) ---
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
command -v bat >/dev/null && alias cat='bat --paging=never'
command -v eza >/dev/null && alias ls='eza' && alias ll='eza -lah --git'
command -v lazygit >/dev/null && alias lg='lazygit'

# Source local env file if it exists
if [ -f ~/.env ]; then
    source ~/.env
fi
