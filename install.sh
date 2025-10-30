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
          *arch*) echo "arch" ;;
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

# ---------- Arch Linux ----------
pacman_sync() {
  blue "Sync pacman db & full upgrade"
  sudo pacman -Syu --noconfirm
}

ensure_build_tools_arch() {
  blue "Ensuring base-devel, git, curl, certs"
  sudo pacman -S --needed --noconfirm base-devel git curl ca-certificates
}

pacman_install_list() {
  local list_file="$1"
  [ -f "$list_file" ] || return 0
  blue "Installing pacman packages: $(basename "$list_file")"
  sudo pacman -S --needed --noconfirm $(grep -vE '^\s*#' "$list_file" | tr '\n' ' ')
}

ensure_yay() {
  if has yay; then return 0; fi
  blue "Installing yay (AUR helper)"
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  git -C "$tmp" clone https://aur.archlinux.org/yay-bin.git
  ( cd "$tmp/yay-bin" && makepkg -si --noconfirm )
}

aur_install_list() {
  local list_file="$1"
  [ -f "$list_file" ] || return 0
  ensure_yay
  blue "Installing AUR packages: $(basename "$list_file")"
  yay -S --needed --noconfirm $(grep -vE '^\s*#' "$list_file" | tr '\n' ' ')
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

  # NodeJS keyring (first-time only)
  bash -c '${ASDF_DATA_DIR:=$HOME/.asdf}/plugins/nodejs/bin/import-release-team-keyring' || true

  # Install from ~/.tool-versions if present
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
    arch)
      pacman_sync
      ensure_build_tools_arch
      pacman_install_list "$REPO/arch/pacman-packages.txt"
      aur_install_list    "$REPO/arch/aur-packages.txt"
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
