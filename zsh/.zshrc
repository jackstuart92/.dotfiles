# =============================================================================
# zsh configuration
# =============================================================================

# --- History ---
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS       # don't record a command run immediately after itself
setopt HIST_IGNORE_SPACE      # don't record commands starting with a space
setopt SHARE_HISTORY          # share history across sessions
setopt EXTENDED_HISTORY       # record timestamp

# --- Completion ---
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # case-insensitive completion

# --- Key bindings ---
bindkey -e                         # emacs key bindings (Home/End/arrows work correctly)
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# --- NVM ---
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# --- Pyenv ---
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# --- Jenv ---
command -v jenv >/dev/null && eval "$(jenv init -)"

# --- Modern CLI replacements ---
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
command -v bat     >/dev/null && alias cat='bat --paging=never'
command -v eza     >/dev/null && alias ls='eza' && alias ll='eza -lah --git' && alias lt='eza -lah --git --sort=newest'
command -v lazygit >/dev/null && alias lg='lazygit'

# --- Android SDK ---
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# --- Source local env (tokens, private config) ---
[ -f ~/.env ] && source ~/.env

# --- Starship prompt ---
command -v starship >/dev/null && eval "$(starship init zsh)"

# Print a blank line before each prompt except the very first
# Also sets the Ghostty window title when inside a Claude-managed worktree
_newline_before_prompt=false
precmd() {
  if $_newline_before_prompt; then
    echo
  else
    _newline_before_prompt=true
  fi

  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null)
  if [[ "$branch" == */* ]]; then
    local title
    title=$(echo "$branch" | tr '/' '\n' | paste -sd ': ')
    echo -ne "\033]0;${title}\007"
  else
    echo -ne "\033]0;\007"
  fi
}

# --- Brew package management ---
brewup() {
  brew update && brew upgrade && brew cleanup
  date +%s > "$HOME/.brew_last_update"
  echo "Done! Packages updated."
}

brewcheck() {
  echo "Checking for outdated packages..."
  brew update --quiet
  local outdated
  outdated=$(brew outdated)
  if [[ -z "$outdated" ]]; then
    echo "All packages up to date."
  else
    echo "Outdated packages:"
    echo "$outdated"
  fi
}

# Weekly reminder on shell start (timestamp check only — no network calls)
_brew_reminder() {
  local stamp="$HOME/.brew_last_update"
  local threshold=$((60 * 60 * 24 * 7))
  local now
  now=$(date +%s)

  if [[ ! -f "$stamp" ]]; then
    echo "brew: no update on record — run \`brewup\` to update your packages"
    return
  fi

  local last age days
  last=$(cat "$stamp")
  age=$((now - last))

  if [[ $age -gt $threshold ]]; then
    days=$((age / 86400))
    echo "brew: last updated ${days}d ago — run \`brewup\` to update"
  fi
}
_brew_reminder
