# AGENTS.md

Dotfiles for this machine, managed with GNU stow.

## Structure

- `.zshrc` — Oh My Zsh + powerlevel10k prompt.
- `.config/hypr/` — Hyprland (Catppuccin Mocha). `hyprland.conf` is the main
  config; `hyprland.lua` and `hyprcolors.lua` hold the Lua/color logic.
- `.config/wezterm/` — WezTerm theme; derives its palette from
  `~/.cache/wal/colors.json` (pywal16), falls back to Catppuccin Mocha.

## Workflow

- Dotfiles live in `~/kb/dotfiles` and are symlinked into the home directory
  with `stow`:

  ```
  cd ~/kb/dotfiles && stow --target=$HOME .
  ```

- To add or remove a file from management, update this tree and re-run stow.
- `AGENTS.md` and `CLAUDE.md` are the same file — edit `AGENTS.md`, since
  `CLAUDE.md` is a symlink to it.
