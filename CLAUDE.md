# Sophiie Dotfiles

This is the shared engineering dotfiles repo for Sophiie.

## Structure
- `install.sh` — bootstrap script (brew, oh-my-zsh, stow, npm globals)
- `Brewfile` — all Homebrew packages
- `home/` — config files symlinked to `~` via GNU Stow
- Local/secret config goes in `~/.zshrc.local` and `~/.config/git/config.local` (NOT in this repo)

## Rules
- Never commit secrets, API keys, or passwords
- Keep the Brewfile alphabetically sorted within sections
- Test `install.sh` changes on a clean-ish machine before merging
- The `.zshrc` sources `~/.zshrc.local` for machine-specific overrides
- The git config includes `~/.config/git/config.local` for identity
