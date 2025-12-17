#!/usr/bin/env bash
set -euo pipefail

REPO="${REPO:-$HOME/dotfiles}"

blue() { printf "\n\033[1;34m▶ %s\033[0m\n" "$*"; }
has()  { command -v "$1" >/dev/null 2>&1; }

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)
      if [ -r /etc/os-release ]; then
        . /etc/os-release
        case "${ID:-}${ID_LIKE:-}" in
          *ubuntu*|*debian*) echo "ubuntu" ;;
          *)      echo "linux" ;;
        esac
      else
        echo "linux"
      fi
      ;;
    *) echo "unknown" ;;
  esac
}

# ---------- macOS ----------
install_xcode_clt_macos() {
  if ! xcode-select -p >/dev/null 2>&1; then
    blue "Installing Xcode Command Line Tools"
    xcode-select --install || true
    until xcode-select -p >/dev/null 2>&1; do sleep 5; done
  fi
}

install_homebrew_macos() {
  if ! has brew; then
    blue "Installing Homebrew (macOS)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
    # shellcheck disable=SC1091
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
}

brew_bundle_if() {
  local file="$1"
  if [ -f "$file" ] && has brew; then
    blue "brew bundle --file $file"
    brew bundle --file="$file"
  fi
}

run_macos_defaults() {
  if [ -f "$REPO/macos/macos-defaults.sh" ]; then
    blue "Applying macOS defaults"
    bash "$REPO/macos/macos-defaults.sh"
  fi
}

# ---------- Ubuntu/Debian ----------
apt_update_upgrade() {
  blue "Updating apt cache & upgrading packages"
  sudo apt update
  sudo apt upgrade -y
}

ensure_build_tools_ubuntu() {
  blue "Ensuring build-essential, git, curl, certs"
  sudo apt install -y build-essential git curl ca-certificates
}

apt_install_list() {
  local list_file="$1"
  [ -f "$list_file" ] || return 0
  blue "Installing apt packages: $(basename "$list_file")"
  sudo apt install -y $(grep -vE '^\s*#' "$list_file" | tr '\n' ' ')
}

ensure_snap() {
  if has snap; then return 0; fi
  blue "Installing snapd"
  sudo apt install -y snapd
}

snap_install_list() {
  local list_file="$1"
  [ -f "$list_file" ] || return 0
  ensure_snap
  blue "Installing snap packages: $(basename "$list_file")"
  while IFS= read -r line; do
    [[ "$line" =~ ^\s*# ]] || [[ -z "$line" ]] && continue
    sudo snap install $line
  done < "$list_file"
}

install_starship_ubuntu() {
  if ! has starship; then
    blue "Installing starship prompt"
    curl -sS https://starship.rs/install.sh | sh -s -- -y
  fi
}

install_nerd_font_ubuntu() {
  local font_dir="$HOME/.local/share/fonts"
  if [ ! -f "$font_dir/FiraCodeNerdFont-Regular.ttf" ]; then
    blue "Installing FiraCode Nerd Font"
    mkdir -p "$font_dir"
    local tmp; tmp="$(mktemp -d)"
    curl -fLo "$tmp/FiraCode.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
    unzip -q "$tmp/FiraCode.zip" -d "$font_dir"
    rm -rf "$tmp"
    fc-cache -fv
  fi
}

# ---------- Shared ----------
pull_submodules_if_any() {
  if [ -d "$REPO/.git" ] && [ -f "$REPO/.gitmodules" ]; then
    blue "Initializing git submodules"
    git -C "$REPO" submodule update --init --recursive
  fi
}

install_ohmyzsh() {
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    blue "Installing oh-my-zsh"
    RUNZSH=no CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
}

link_dotfiles() {
  blue "Linking .zshrc"
  ln -sf "$REPO/zsh/.zshrc" "$HOME/.zshrc"
  ln -sf "$REPO/.gitconfig" "$HOME/.gitconfig"
  
  mkdir -p "$HOME/.config"
  ln -sf "$REPO/zsh/starship.toml" "$HOME/.config/starship.toml"
}

ensure_default_shell_zsh() {
  if has zsh; then
    local zpath; zpath="$(command -v zsh)"
    if [ "${SHELL:-}" != "$zpath" ]; then
      blue "Changing default shell to $zpath"
      chsh -s "$zpath" || echo "Could not change shell automatically; set it manually."
    fi
  fi
}

asdf_init() {
  if ! command -v asdf >/dev/null 2>&1; then
    blue "asdf not on PATH yet (will be after a new shell). Trying common locations…"
    # Try sourcing known locations for this session:
    if has brew && [ -f "$(brew --prefix)/opt/asdf/libexec/asdf.sh" ]; then
      # shellcheck disable=SC1091
      . "$(brew --prefix)/opt/asdf/libexec/asdf.sh"
    elif [ -f "/opt/asdf-vm/asdf.sh" ]; then
      # shellcheck disable=SC1091
      . "/opt/asdf-vm/asdf.sh"
    elif [ -f "$HOME/.asdf/asdf.sh" ]; then
      # shellcheck disable=SC1091
      . "$HOME/.asdf/asdf.sh"
    fi
  fi
  if ! command -v asdf >/dev/null 2>&1; then
    echo "asdf still not available; open a new terminal and run 'asdf install' later."
    return 0
  fi

  blue "Installing asdf plugins (idempotent)"
  add() { asdf plugin add "$1" "$2" 2>/dev/null || true; }

  add nodejs    https://github.com/asdf-vm/asdf-nodejs.git
  add python    https://github.com/asdf-community/asdf-python.git
  add rust      https://github.com/asdf-community/asdf-rust.git
  add golang    https://github.com/asdf-community/asdf-golang.git
  add ruby      https://github.com/asdf-vm/asdf-ruby.git

  # NodeJS keyring (first-time only)
  bash -c '${ASDF_DATA_DIR:=$HOME/.asdf}/plugins/nodejs/bin/import-release-team-keyring' || true

  # Install from .tool-versions in repo if present
  if [ -f "$REPO/.tool-versions" ]; then
    blue "Copying .tool-versions from repo to $HOME"
    cp "$REPO/.tool-versions" "$HOME/.tool-versions"
  fi
  
  if [ -f "$HOME/.tool-versions" ]; then
    blue "asdf install (from ~/.tool-versions)"
    asdf install
    # Optional: enable Corepack for Yarn/Pnpm
    if command -v node >/dev/null 2>&1; then corepack enable || true; fi
  fi
}

main() {
  local os; os="$(detect_os)"
  blue "Detected OS: $os"

  case "$os" in
    macos)
      install_xcode_clt_macos
      install_homebrew_macos
      brew_bundle_if "$REPO/Brewfile.macos"
      run_macos_defaults
      ;;
    ubuntu)
      apt_update_upgrade
      ensure_build_tools_ubuntu
      apt_install_list "$REPO/ubuntu/apt-packages.txt"
      snap_install_list "$REPO/ubuntu/snap-packages.txt"
      install_starship_ubuntu
      install_nerd_font_ubuntu
      ;;
    *) echo "Unsupported/untested OS for this script."; exit 1 ;;
  esac

  pull_submodules_if_any
  install_ohmyzsh
  link_dotfiles
  ensure_default_shell_zsh
  asdf_init

  blue "All set. Open a new terminal or run: exec zsh"
}

main "$@"
