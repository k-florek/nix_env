# Path Update - Preserve Original Path
ORIGINAL_PATH="$PATH"

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export NIXENV="$HOME/nix_env"

# Source oh-my-zsh configuration
source $NIXENV/zsh-config

# Restore Path
export PATH="$ORIGINAL_PATH"

# Home bin
export PATH=$HOME/bin:$PATH

### Autogen Content Below ###

