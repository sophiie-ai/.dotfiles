#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$DOTFILES_DIR/install.log"

# --- Sophiie Brand Colors (ANSI 256) ---
# Primary blue: #36A5E1 → 38;5;74
# Navy:         #182037 → 38;5;17
# Success:      #22C55E → 38;5;41
# Warning:      #F59E0B → 38;5;214
# Error:        #EF4444 → 38;5;196
BLUE="\033[38;5;74m"
NAVY="\033[38;5;17m"
GREEN="\033[38;5;41m"
YELLOW="\033[38;5;214m"
RED="\033[38;5;196m"
DIM="\033[2m"
BOLD="\033[1m"
RESET="\033[0m"

# --- Spinner with live output ---
SPINNER_PID=""
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPINNER_STATUS_FILE=""
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)

spinner_start() {
  local msg="$1"
  SPINNER_STATUS_FILE=$(mktemp)
  (
    local i=0
    while true; do
      local status=""
      if [[ -f "$SPINNER_STATUS_FILE" ]]; then
        status=$(tail -1 "$SPINNER_STATUS_FILE" 2>/dev/null | tr -d '\r' | sed 's/^[[:space:]]*//' || true)
      fi

      local line
      if [[ -n "$status" ]]; then
        line=$(printf "  ${BLUE}${SPINNER_FRAMES[$i]}${RESET} %s ${DIM}› %s${RESET}" "$msg" "$status")
      else
        line=$(printf "  ${BLUE}${SPINNER_FRAMES[$i]}${RESET} %s" "$msg")
      fi

      # Truncate to terminal width
      printf "\r\033[K%s" "${line:0:$TERM_WIDTH}"

      i=$(( (i + 1) % ${#SPINNER_FRAMES[@]} ))
      sleep 0.08
    done
  ) &
  SPINNER_PID=$!
}

spinner_stop() {
  if [[ -n "$SPINNER_PID" ]]; then
    kill "$SPINNER_PID" 2>/dev/null
    wait "$SPINNER_PID" 2>/dev/null || true
    SPINNER_PID=""
    printf "\r\033[K"
  fi
  if [[ -n "$SPINNER_STATUS_FILE" ]]; then
    rm -f "$SPINNER_STATUS_FILE"
    SPINNER_STATUS_FILE=""
  fi
}

# Clean up spinner on exit
trap 'spinner_stop' EXIT

# --- Helpers ---
info()    { printf "  ${BLUE}${BOLD}▸${RESET} %s\n" "$1"; }
ok()      { printf "  ${GREEN}✓${RESET} %s\n" "$1"; }
warn()    { printf "  ${YELLOW}⚠${RESET} %s\n" "$1"; }
err()     { printf "  ${RED}✗${RESET} %s\n" "$1"; }
section() { echo ""; printf "  ${BLUE}${BOLD}━━━ %s ━━━${RESET}\n" "$1"; echo ""; }

run_with_spinner() {
  local msg="$1"
  shift
  spinner_start "$msg"
  # Pipe all output to both the log file and the spinner status file
  if "$@" > >(tee -a "$LOG_FILE" >> "$SPINNER_STATUS_FILE") 2>&1; then
    spinner_stop
    ok "$msg"
  else
    spinner_stop
    err "$msg — check $LOG_FILE"
    return 1
  fi
}

# --- Pre-flight ---
if [[ "$(uname)" != "Darwin" ]]; then
  err "This script is macOS-only"
  exit 1
fi

echo "" > "$LOG_FILE"
echo ""
printf "  ${BLUE}${BOLD}╔═══════════════════════════════════════╗${RESET}\n"
printf "  ${BLUE}${BOLD}║${RESET}   ${BOLD}Sophiie${RESET} ${DIM}Engineering Environment${RESET}    ${BLUE}${BOLD}║${RESET}\n"
printf "  ${BLUE}${BOLD}╚═══════════════════════════════════════╝${RESET}\n"
echo ""
printf "  ${DIM}Log: %s${RESET}\n" "$LOG_FILE"

# --- Sudo: ask once, keep alive ---
section "Privileges"
info "Some steps require admin privileges. You'll be asked for your password once."
sudo -v
# Keep sudo alive in the background until the script finishes
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
ok "Sudo cached"

# --- 1. Xcode Command Line Tools ---
section "Xcode Command Line Tools"
if ! xcode-select -p &>/dev/null; then
  # Create the placeholder file that triggers a headless install via softwareupdate
  sudo touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

  spinner_start "Searching for CLT package"
  CLT_PKG=$(softwareupdate --list 2>&1 \
    | grep -o 'Command Line Tools for Xcode-[0-9.]*' \
    | sort -V \
    | tail -1)
  spinner_stop

  if [[ -n "$CLT_PKG" ]]; then
    info "Found: $CLT_PKG"
    run_with_spinner "Installing Xcode CLT" \
      sudo softwareupdate --install "$CLT_PKG"
  else
    err "Could not find CLT package. Run 'xcode-select --install' manually and re-run."
    sudo rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    exit 1
  fi

  sudo rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

  if ! xcode-select -p &>/dev/null; then
    err "Xcode CLT installation failed. Please install manually and re-run."
    exit 1
  fi
  ok "Xcode Command Line Tools installed"
else
  ok "Xcode Command Line Tools already installed"
fi

# --- 2. Homebrew ---
section "Homebrew"
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >> "$LOG_FILE" 2>&1
  ok "Homebrew installed"

  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
else
  ok "Homebrew already installed"
fi

# --- 3. Brew Bundle ---
run_with_spinner "Installing Homebrew packages" \
  brew bundle --file="$DOTFILES_DIR/Brewfile"

# --- 4. Oh My Zsh ---
section "Shell"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  run_with_spinner "Installing Oh My Zsh" \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  ok "Oh My Zsh already installed"
fi

# --- 5. Powerlevel10k ---
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [[ ! -d "$P10K_DIR" ]]; then
  run_with_spinner "Installing Powerlevel10k" \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
  ok "Powerlevel10k already installed"
fi

# --- 6. zsh-autosuggestions ---
ZSH_AS_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
if [[ ! -d "$ZSH_AS_DIR" ]]; then
  run_with_spinner "Installing zsh-autosuggestions" \
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AS_DIR"
else
  ok "zsh-autosuggestions already installed"
fi

# --- 7. Global npm packages ---
section "npm globals"
npm_globals=(
  "claude-code"
  "@openai/codex"
  "graphite-cli"
  "turbo"
)
for pkg in "${npm_globals[@]}"; do
  if npm list -g "$pkg" &>/dev/null; then
    ok "$pkg"
  else
    run_with_spinner "Installing $pkg" npm install -g "$pkg"
  fi
done

# --- 8. Link dotfiles ---
section "Dotfiles"

HOME_DIR="$DOTFILES_DIR/home"
backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
backed_up=false

while IFS= read -r -d '' src; do
  rel="${src#$HOME_DIR/}"
  target="$HOME/$rel"

  [[ "$rel" == *.example ]] && continue

  mkdir -p "$(dirname "$target")"

  if [[ -f "$target" && ! -L "$target" ]]; then
    mkdir -p "$backup_dir/$(dirname "$rel")"
    cp "$target" "$backup_dir/$rel"
    rm "$target"
    warn "Backed up ~/$rel"
    backed_up=true
  fi

  [[ -L "$target" ]] && rm "$target"

  ln -s "$src" "$target"
done < <(find "$HOME_DIR" -type f -print0)

if $backed_up; then
  info "Backups saved to $backup_dir"
fi
ok "Dotfiles linked"

# --- 9. Local config setup ---
section "Local Configuration"

# --- 9a. Git identity ---
GIT_LOCAL="$HOME/.config/git/config.local"
if [[ -f "$GIT_LOCAL" ]]; then
  ok "Git local config already exists"
else
  info "Let's set up your git identity (stored in ~/.config/git/config.local)"
  echo ""

  read -rp "    Full name: " git_name
  read -rp "    Email (e.g. you@sophiie.ai): " git_email
  read -rp "    GPG signing key ID (blank to skip): " git_gpg_key

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

  echo ""
  ok "Wrote $GIT_LOCAL"
fi

# --- 9b. Shell local config ---
ZSH_LOCAL="$HOME/.zshrc.local"
if [[ -f "$ZSH_LOCAL" ]]; then
  ok "Shell local config already exists"
else
  cp "$DOTFILES_DIR/home/.zshrc.local.example" "$ZSH_LOCAL"
  ok "Created ~/.zshrc.local — edit to add your secrets"
fi

# --- 10. Done ---
echo ""
printf "  ${GREEN}${BOLD}╔═══════════════════════════════════════╗${RESET}\n"
printf "  ${GREEN}${BOLD}║${RESET}          ${BOLD}Setup Complete${RESET} ${GREEN}✓${RESET}             ${GREEN}${BOLD}║${RESET}\n"
printf "  ${GREEN}${BOLD}╚═══════════════════════════════════════╝${RESET}\n"
echo ""
printf "  ${DIM}Remaining manual steps:${RESET}\n"
echo ""
printf "    ${BLUE}1.${RESET} Edit ${BOLD}~/.zshrc.local${RESET} to add secrets\n"
printf "    ${BLUE}2.${RESET} Open tmux and press ${BOLD}Ctrl-a + I${RESET} to install plugins\n"
printf "    ${BLUE}3.${RESET} Restart your terminal or run: ${BOLD}source ~/.zshrc${RESET}\n"
echo ""
printf "  ${DIM}Happy hacking${RESET} ${BLUE}◆${RESET}\n"
echo ""
