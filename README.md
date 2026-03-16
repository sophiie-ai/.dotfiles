# Sophiie Engineering Dotfiles

Shared dotfiles and bootstrap script for the Sophiie engineering team. The goal is to get any new engineer from a fresh Mac to a fully working dev environment in a single command — same shell, same tools, same conventions across the team.

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
├── install.sh                          # Bootstrap everything
├── Brewfile                            # Homebrew packages
├── home/                               # Symlinked to ~ via GNU Stow
│   ├── .zshrc
│   ├── .p10k.zsh                       # Powerlevel10k theme (rainbow)
│   ├── .zshrc.local.example            # Template for local shell config
│   ├── .config/
│   │   ├── git/
│   │   │   ├── config                  # Shared git config
│   │   │   ├── config.local.example    # Template for local git identity
│   │   │   └── ignore                  # Global gitignore
│   │   └── tmux/
│   │       └── tmux.conf
├── CLAUDE.md
└── README.md
```

## Local Overrides (not checked in)

The install script will interactively set these up on first run. Example files are provided in the repo for reference.

| File | Purpose | Example |
|------|---------|---------|
| `~/.config/git/config.local` | Your name, email, GPG key | `home/.config/git/config.local.example` |
| `~/.zshrc.local` | Secrets, machine-specific PATH, etc. | `home/.zshrc.local.example` |

The install script prompts for your git name, email, and GPG key, then writes `config.local` for you. For shell secrets, it copies the example file so you just need to fill in the values.

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
