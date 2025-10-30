#### ─────────────────────────────────────────────────────────────────────
#### Powerlevel10k instant prompt (keep at the very top)
#### ─────────────────────────────────────────────────────────────────────
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

#### ─────────────────────────────────────────────────────────────────────
#### oh-my-zsh core
#### ─────────────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
# Keep your custom plugins/themes in your repo:
export ZSH_CUSTOM="$HOME/dotfiles/zsh/zsh_custom"

# Theme: Powerlevel10k
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins (add external ones to $ZSH_CUSTOM/plugins/)
plugins=(
  git
  kubectl
  poetry
  tldr
  fzf
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

#### ─────────────────────────────────────────────────────────────────────
#### Environment basics
#### ─────────────────────────────────────────────────────────────────────
# macOS Homebrew on Apple Silicon; harmless elsewhere.
case "$OSTYPE" in
  darwin*) export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH" ;;
esac

# User-local bin (pipx, etc.)
export PATH="$HOME/.local/bin:$PATH"

# Editor
export EDITOR="nvim"

#### ─────────────────────────────────────────────────────────────────────
#### asdf (unified runtime manager)
#### ─────────────────────────────────────────────────────────────────────
# Prefer Homebrew install on macOS; fall back to common paths on Linux/Arch.
if command -v brew >/dev/null 2>&1 && [ -f "$(brew --prefix)/opt/asdf/libexec/asdf.sh" ]; then
  . "$(brew --prefix)/opt/asdf/libexec/asdf.sh"
elif [ -f "/opt/asdf-vm/asdf.sh" ]; then
  . "/opt/asdf-vm/asdf.sh"
elif [ -f "$HOME/.asdf/asdf.sh" ]; then
  . "$HOME/.asdf/asdf.sh"
fi

#### ─────────────────────────────────────────────────────────────────────
#### Completions / QoL
#### ─────────────────────────────────────────────────────────────────────
# direnv
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# kubectl completion (in addition to plugin; keeps it fresh)
if command -v kubectl >/dev/null 2>&1; then
  source <(kubectl completion zsh)
fi

# fzf key bindings (macOS via brew, Arch via system path)
if command -v brew >/dev/null 2>&1 && [ -d "$(brew --prefix)/opt/fzf" ]; then
  source "$(brew --prefix)/opt/fzf/shell/key-bindings.zsh"
elif [ -f "/usr/share/fzf/key-bindings.zsh" ]; then
  source "/usr/share/fzf/key-bindings.zsh"
fi

# (Optional) Postgres 13 path on macOS if installed via Homebrew
if command -v brew >/dev/null 2>&1 && [ -d "$(brew --prefix postgresql@13 2>/dev/null)/bin" ]; then
  export PATH="$(brew --prefix postgresql@13)/bin:$PATH"
fi

#### ─────────────────────────────────────────────────────────────────────
#### Powerlevel10k config (leave at bottom)
#### ─────────────────────────────────────────────────────────────────────
[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
