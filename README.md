# Sophiie Engineering Dotfiles

Standard development environment for the Sophiie engineering team.

## What's Included

| Category | Tools |
|----------|-------|
| Shell | zsh, Oh My Zsh, Powerlevel10k, zsh-autosuggestions, direnv |
| Node.js | node (latest), pnpm, corepack |
| AI | claude-code, codex-cli |
| Git | git, gh (GitHub CLI), graphite-cli, git-lfs, gnupg |
| Search | ripgrep, fd, fzf |
| Terminal | tmux (with TPM, resurrect, continuum) |
| DX | bat, eza, jq, tree, stow |
| Infra | awscli, orbstack (Docker) |
| Build | turbo |

## Quick Start

```bash
git clone git@github.com:sophiie-ai/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
chmod +x install.sh
./install.sh
```

## Structure

```
.dotfiles/
├── install.sh              # Bootstrap everything
├── Brewfile                # Homebrew packages
├── home/                   # Symlinked to ~ via GNU Stow
│   ├── .zshrc
│   ├── .config/
│   │   ├── git/
│   │   │   ├── config      # Shared git config
│   │   │   └── ignore      # Global gitignore
│   │   └── tmux/
│   │       └── tmux.conf
├── CLAUDE.md
└── README.md
```

## Local Overrides (not checked in)

| File | Purpose |
|------|---------|
| `~/.config/git/config.local` | Your name, email, GPG key |
| `~/.zshrc.local` | Secrets, machine-specific PATH, etc. |
| `~/.p10k.zsh` | Powerlevel10k config (run `p10k configure`) |

## Adding a Package

```bash
# Add to Brewfile
echo 'brew "something"' >> Brewfile
brew bundle --file=Brewfile

# Commit
git add Brewfile && git commit -m "add something to Brewfile"
```

## Adding a Config File

Place it under `home/` mirroring the home directory structure, then re-stow:

```bash
# Example: add a new config
mkdir -p home/.config/newtool
echo "config here" > home/.config/newtool/config.toml

# Re-link
stow -v -d . -t ~ home
```
