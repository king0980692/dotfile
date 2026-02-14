# Dotfiles

Personal dotfile configs for bash + ble.sh + nvim + mise + tmux and more.

## What's Included

| Config | Description |
|---|---|
| `bash/` | `.bashrc`, ble.sh config, git completion, aliases, extract helper |
| `nvim/` | LazyVim-based Neovim config with plugins |
| `mise/` | Tool version manager config (35+ tools) |
| `tmux/` | tmux.conf + helper scripts, TPM auto-bootstrap |
| `leon_scripts/` | Custom fzf/tmux/mise utility scripts |
| `starship.toml` | Starship prompt config |
| `lazygit/` | Lazygit config |
| `yazi/` | Yazi file manager config |
| `git/` | Git global ignore |
| `.gitconfig` | Git config (delta pager, zdiff3 merge) |

### Tools managed by mise

> All installed automatically via `mise/config.toml`

neovim, tmux, fzf, starship, zoxide, atuin, ripgrep, fd, bat, delta,
lazygit, yazi, btop, bottom, dust, eza, difftastic, fx, jq, gum,
croc, cmake, node, bun, pnpm, rust, uv, claude-code, opencode,
aichat, usage, fastfetch, crush

## Quick Start

### Install on a new environment

**One-liner:**

```bash
bash <(curl -sL https://raw.githubusercontent.com/king0980692/dotfile/main/install.sh)
```

**Or manually:**

```bash
git clone https://github.com/king0980692/dotfile.git /tmp/dotfile
/tmp/dotfile/install.sh
rm -rf /tmp/dotfile
```

The script safely merges dotfiles into your existing `~/.config` without overwriting unrelated configs (e.g. other apps' settings).

Then restart your shell:

```bash
exec bash
```

In tmux, press `prefix + I` to install tmux plugins.

### What install.sh does

1. Clones the dotfile repo and merges into `~/.config` (existing configs untouched)
2. Installs **mise** → installs all 35+ CLI tools
3. Installs **ble.sh** (bash line editor)
4. Symlinks `~/.bashrc` → `~/.config/bash/.bashrc`
5. Symlinks `~/.gitconfig`
6. Installs **TPM** (tmux plugin manager)

## Erase Everything

```bash
~/.config/uninstall.sh
```

### What uninstall.sh does

1. Runs `mise implode` — removes all mise-managed tools
2. Removes ble.sh, tmux plugins
3. Removes symlinks, restores default `.bashrc`
4. Deletes all managed config dirs from `~/.config`
5. Cleans usage traces: `.bash_history`, nvim cache/state, atuin, zoxide, starship cache, bun, cargo/rustup
