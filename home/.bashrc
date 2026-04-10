# OPENSPEC:START
# OpenSpec shell completions configuration
if [ -d "/home/pat/.local/share/bash-completion/completions" ]; then
  for f in "/home/pat/.local/share/bash-completion/completions"/*; do
    [ -f "$f" ] && . "$f"
  done
fi
# OPENSPEC:END

# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source ~/.local/share/omarchy/default/bash/rc

unset -f n
# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
v() { if [ "$#" -eq 0 ]; then nvim .; else nvim "$@"; fi; }

unalias lsa
unalias ls
alias l='eza -lh --group-directories-first --icons=auto'
alias la='l -a'
alias lt='eza --tree --level=2 --long --icons --git'
alias lta='lt -a'
alias c=clear
alias cat=bat


# fzf-grep: Interactive search of file contents using ripgrep
# Usage: fg [initial_query]
fzg() {
  local initial_query="$1"
  RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case"

  FZF_DEFAULT_COMMAND="$RG_PREFIX '$initial_query'" \
    fzf --bind "change:reload:$RG_PREFIX {q} || true" \
        --ansi --disabled --query "$initial_query" \
        --height=80% --layout=reverse \
        --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' \
        --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
        --bind "enter:execute(echo {1}:{2} | xargs -o \$EDITOR)"
}
export DATABASE_PASSWORD="pat"
export PATH="/home/pat/my_scripts:$PATH"

# Created by `pipx` on 2026-01-02 23:58:04
export PATH="$PATH:/home/pat/.local/bin"

eval "$(register-python-argcomplete pipx)"

export PATH="$HOME/google-cloud-sdk/bin:$PATH"

# . "$HOME/.local/share/../bin/env"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/pat/google-cloud-sdk/path.bash.inc' ]; then . '/home/pat/google-cloud-sdk/path.bash.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/pat/google-cloud-sdk/completion.bash.inc' ]; then . '/home/pat/google-cloud-sdk/completion.bash.inc'; fi

# OpenClaw Completion
source "/home/pat/.openclaw/completions/openclaw.bash"

eval "$(thefuck --alias)"

# Source secrets from .env (not tracked by git)
[ -f "$HOME/.env" ] && source "$HOME/.env"
export OPENSPEC_TELEMETRY=0
alias ccc="claude --dangerously-skip-permissions"
export PATH="$HOME/.cargo/bin:$PATH"

export ACTIVE_BRANCH=""
