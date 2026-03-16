#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$DOTFILES_DIR/install.log"

# --- Helpers ---
info()  { printf "\033[1;34m[info]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[1;32m[ok]\033[0m    %s\n" "$1"; }
warn()  { printf "\033[1;33m[warn]\033[0m  %s\n" "$1"; }
err()   { printf "\033[1;31m[error]\033[0m %s\n" "$1"; }

log_and_run() {
  info "$1"
  shift
  if "$@" >> "$LOG_FILE" 2>&1; then
    ok "Done"
  else
    err "Failed — check $LOG_FILE"
    return 1
  fi
}

# --- Pre-flight ---
if [[ "$(uname)" != "Darwin" ]]; then
  err "This script is macOS-only"
  exit 1
fi

echo "" > "$LOG_FILE"
info "Sophiie Engineering Environment Setup"
info "Log: $LOG_FILE"
echo ""

# --- 1. Homebrew ---
if ! command -v brew &>/dev/null; then
  log_and_run "Installing Homebrew" \
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for the rest of this script
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
else
  ok "Homebrew already installed"
fi

# --- 2. Brew Bundle ---
log_and_run "Installing Homebrew packages" \
  brew bundle --file="$DOTFILES_DIR/Brewfile" --no-lock

# --- 3. Oh My Zsh ---
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  log_and_run "Installing Oh My Zsh" \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  ok "Oh My Zsh already installed"
fi

# --- 4. Powerlevel10k ---
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [[ ! -d "$P10K_DIR" ]]; then
  log_and_run "Installing Powerlevel10k" \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
  ok "Powerlevel10k already installed"
fi

# --- 5. zsh-autosuggestions ---
ZSH_AS_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
if [[ ! -d "$ZSH_AS_DIR" ]]; then
  log_and_run "Installing zsh-autosuggestions" \
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AS_DIR"
else
  ok "zsh-autosuggestions already installed"
fi

# --- 6. Global npm packages ---
info "Installing global npm packages"
npm_globals=(
  "claude-code"
  "@openai/codex"
  "graphite-cli"
  "turbo"
)
for pkg in "${npm_globals[@]}"; do
  if npm list -g "$pkg" &>/dev/null; then
    ok "$pkg already installed"
  else
    log_and_run "Installing $pkg" npm install -g "$pkg"
  fi
done

# --- 7. Stow dotfiles ---
info "Linking dotfiles with stow"
cd "$DOTFILES_DIR"

# Back up existing files that would conflict
backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
files_to_check=(".zshrc" ".config/git/config" ".config/git/ignore" ".config/tmux/tmux.conf")

for f in "${files_to_check[@]}"; do
  target="$HOME/$f"
  if [[ -f "$target" && ! -L "$target" ]]; then
    mkdir -p "$backup_dir/$(dirname "$f")"
    cp "$target" "$backup_dir/$f"
    rm "$target"
    warn "Backed up ~/$f to $backup_dir/$f"
  fi
done

# Ensure target directories exist
mkdir -p "$HOME/.config/git" "$HOME/.config/tmux"

stow -v -d "$DOTFILES_DIR" -t "$HOME" home >> "$LOG_FILE" 2>&1
ok "Dotfiles linked"

# --- 8. Local config reminder ---
echo ""
info "=== Setup Complete ==="
echo ""
warn "ACTION REQUIRED — Create your local config files (not checked in):"
echo ""
echo "  1. Git identity — ~/.config/git/config.local"
echo "     [user]"
echo "       name = Your Name"
echo "       email = you@sophiie.ai"
echo "       signingKey = YOUR_GPG_KEY_ID"
echo "     [gpg]"
echo "       program = /opt/homebrew/bin/gpg"
echo ""
echo "  2. Shell secrets — ~/.zshrc.local"
echo "     export PULUMI_CONFIG_PASSPHRASE=\"...\""
echo "     export SOME_OTHER_SECRET=\"...\""
echo ""
echo "  3. Powerlevel10k — run 'p10k configure' to set up your prompt"
echo ""
echo "  4. tmux plugins — open tmux and press prefix + I to install plugins"
echo ""
ok "Happy hacking"
