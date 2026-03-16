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

# --- 1. Xcode Command Line Tools ---
if ! xcode-select -p &>/dev/null; then
  info "Installing Xcode Command Line Tools (required for git, compilers, etc.)"

  # Create the placeholder file that triggers a headless install via softwareupdate
  sudo touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

  CLT_PKG=$(softwareupdate --list 2>&1 \
    | grep -o 'Command Line Tools for Xcode-[0-9.]*' \
    | sort -V \
    | tail -1)

  if [[ -n "$CLT_PKG" ]]; then
    info "Found: $CLT_PKG"
    sudo softwareupdate --install "$CLT_PKG" --verbose
  else
    err "Could not find CLT package. Run 'xcode-select --install' manually and re-run."
    sudo rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    exit 1
  fi

  sudo rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

  # Verify
  if ! xcode-select -p &>/dev/null; then
    err "Xcode CLT installation failed. Please install manually and re-run."
    exit 1
  fi
  ok "Xcode Command Line Tools installed"
else
  ok "Xcode Command Line Tools already installed"
fi

# --- 2. Homebrew ---
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

# --- 3. Brew Bundle ---
log_and_run "Installing Homebrew packages" \
  brew bundle --file="$DOTFILES_DIR/Brewfile" --no-lock

# --- 4. Oh My Zsh ---
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  log_and_run "Installing Oh My Zsh" \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  ok "Oh My Zsh already installed"
fi

# --- 5. Powerlevel10k ---
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [[ ! -d "$P10K_DIR" ]]; then
  log_and_run "Installing Powerlevel10k" \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
  ok "Powerlevel10k already installed"
fi

# --- 6. zsh-autosuggestions ---
ZSH_AS_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
if [[ ! -d "$ZSH_AS_DIR" ]]; then
  log_and_run "Installing zsh-autosuggestions" \
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AS_DIR"
else
  ok "zsh-autosuggestions already installed"
fi

# --- 7. Global npm packages ---
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

# --- 8. Link dotfiles ---
info "Linking dotfiles"

HOME_DIR="$DOTFILES_DIR/home"
backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
backed_up=false

# Walk home/ and symlink each file to ~
while IFS= read -r -d '' src; do
  rel="${src#$HOME_DIR/}"
  target="$HOME/$rel"

  # Skip .example files — those are templates, not configs
  [[ "$rel" == *.example ]] && continue

  # Ensure parent directory exists
  mkdir -p "$(dirname "$target")"

  # Back up existing non-symlink files
  if [[ -f "$target" && ! -L "$target" ]]; then
    mkdir -p "$backup_dir/$(dirname "$rel")"
    cp "$target" "$backup_dir/$rel"
    rm "$target"
    warn "Backed up ~/$rel to $backup_dir/$rel"
    backed_up=true
  fi

  # Remove existing symlink (may point to old location)
  [[ -L "$target" ]] && rm "$target"

  ln -s "$src" "$target"
done < <(find "$HOME_DIR" -type f -print0)

if $backed_up; then
  info "Backups saved to $backup_dir"
fi
ok "Dotfiles linked"

# --- 9. Local config setup ---
echo ""
info "=== Local Configuration ==="
echo ""

# --- 9a. Git identity ---
GIT_LOCAL="$HOME/.config/git/config.local"
if [[ -f "$GIT_LOCAL" ]]; then
  ok "Git local config already exists at $GIT_LOCAL"
else
  info "Let's set up your git identity (stored in ~/.config/git/config.local)"
  echo ""

  read -rp "  Full name: " git_name
  read -rp "  Email (e.g. you@sophiie.ai): " git_email
  read -rp "  GPG signing key ID (leave blank to skip): " git_gpg_key

  mkdir -p "$HOME/.config/git"
  cat > "$GIT_LOCAL" <<GITEOF
[user]
	name = $git_name
	email = $git_email
GITEOF

  if [[ -n "$git_gpg_key" ]]; then
    cat >> "$GIT_LOCAL" <<GITEOF
	signingKey = $git_gpg_key

[gpg]
	program = /opt/homebrew/bin/gpg
GITEOF
  fi

  ok "Wrote $GIT_LOCAL"
fi

# --- 9b. Shell local config ---
ZSH_LOCAL="$HOME/.zshrc.local"
if [[ -f "$ZSH_LOCAL" ]]; then
  ok "Shell local config already exists at $ZSH_LOCAL"
else
  info "Creating ~/.zshrc.local from example"
  cp "$DOTFILES_DIR/home/.zshrc.local.example" "$ZSH_LOCAL"
  ok "Wrote $ZSH_LOCAL — edit it to add your secrets and machine-specific config"
fi

# --- 10. Remaining manual steps ---
echo ""
info "=== Setup Complete ==="
echo ""
echo "  Remaining manual steps:"
echo ""
echo "  1. Edit ~/.zshrc.local to add secrets (API keys, passphrases, etc.)"
echo "  2. Open tmux and press Ctrl-a + I to install plugins"
echo "  3. Restart your terminal or run: source ~/.zshrc"
echo ""
ok "Happy hacking"
