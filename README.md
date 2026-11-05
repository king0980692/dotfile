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
| `kak/` | Kakoune editor: herdr popup windowing via `herdr/plugins/local/kak-popup`, OSC 52 clipboard, fzf/yazi pickers |
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

**Requirements:** Linux or macOS on x86_64 or ARM64, with Git, curl, tar (including xz support), make and a C/C++ toolchain. On macOS, install Xcode Command Line Tools (`xcode-select --install`). Bash, Kakoune and nnn are built from source by pinned mise/asdf plugins; nnn requires ncurses headers and libraries. Individual tools or builds may not be available on every platform; the installer warns if any fail.

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

The script merges dotfiles into your existing `~/.config` without overwriting unrelated configs. **Back up first:** tracked files at the same paths and the shell/Git symlinks can be overwritten.

Then restart your shell. On Linux:

```bash
exec bash
```

On macOS, start mise-managed Bash (the system Bash 3.2 is too old for this configuration):

```bash
export PATH="$HOME/.local/bin:$PATH"
exec "$(mise where bash)/bin/bash"
```

For Bash login shells on macOS, add `[[ -f ~/.bashrc ]] && source ~/.bashrc` to your existing `~/.bash_profile`. The installer does not change your default shell or login profile.

In tmux, press `prefix + I` to install tmux plugins.

Yazi's third-party plugins and flavors are restored from `yazi/package.toml` by the installer. To restore them manually, run `mise exec -- ya pkg install`. After changing flavor packages or `yazi/theme-overrides.toml`, regenerate the checked-in themes with `~/.config/leon_scripts/yazi-theme-gen.sh`.

### Herdr sidebar

The customized sidebar source lives in [king0980692/herdr-sidebar](https://github.com/king0980692/herdr-sidebar), branch `leon`. `mise/config.toml` pins its Git commit and builds it with Cargo; update that revision to deploy newer changes. `herdr-sidebar/settings.json` holds portable preferences, while view selection, repository paths and other runtime data remain under the local Herdr state directory.

The installer registers the local manifest at `herdr/plugins/local/herdr-sidebar`; Herdr does not download or update the binary. If a sidebar is already registered, the installer leaves it untouched. After backing up any custom registration, switch manually with:

```bash
herdr plugin unlink herdr-sidebar
herdr plugin link "${XDG_CONFIG_HOME:-$HOME/.config}/herdr/plugins/local/herdr-sidebar" --enabled
```

The linked manifest uses `mise where` to locate the pinned binary. Install or update it with `mise install`; restart Herdr or reload its plugin registration after changes. Do not use the upstream plugin's update action, which can replace the customized build.

### Update notifications

Interactive Bash checks `origin/main` in the background, at most once per hour by default. On the next prompt after a check, it warns if the remote commit is not already in the local history. It never fetches, pulls, changes the working tree, or prompts for credentials. The notification is advisory: inspect local changes before syncing.

Set `DOTFILES_UPDATE_CHECK=0` before starting Bash to disable it, or set `DOTFILES_UPDATE_INTERVAL` to the check interval in seconds (prompt scheduling has a 60-second minimum). Offline or failed checks are silent and retried after the interval.

### Machine-specific settings

- Herdr commands use `XDG_CONFIG_HOME` (or `~/.config`) instead of a fixed username. Restart or reload the Herdr server after changing its config.
- The `tw-market-*` systemd user units are local-only: they depend on a particular TradingAgents checkout and are deliberately ignored by Git. Set them up separately on any machine that needs them.
- The generated Yazi themes refer to syntax themes under `~/.config/yazi`; a non-default `XDG_CONFIG_HOME` needs those paths adjusted.
- Bash, nnn and Kakoune are mise-managed source builds using third-party asdf plugins pinned in `mise/config.toml`; their compilers and system libraries must be available before `mise install`. On Linux, ensure ncurses development headers and `en_US.UTF-8` are available. Kakoune requires a C++20 compiler. ble.sh, TPM and Yazi packages are still installed by their own mechanisms.
- Older installations may still have a `~/.local/bin/kak` symlink to a previously extracted Debian package; remove that symlink if it shadows mise's Kakoune.

### What install.sh does

1. Clones the dotfile repo and merges into `~/.config` (existing configs untouched)
2. Installs **mise** → installs configured CLI tools and Yazi packages (availability varies by platform)
3. Installs **ble.sh** (bash line editor)
4. Builds **Bash**, **Kakoune** and **nnn** through mise plugins (requires a toolchain and system libraries)
5. Symlinks `~/.bashrc` → `~/.config/bash/.bashrc`
6. Symlinks `~/.gitconfig`
7. Installs **TPM** (tmux plugin manager)


## Coding agents

`agents/` holds the settings of Claude Code, Codex and pi that are worth sharing between machines. `agents/sync.sh` (run by `install.sh`, safe to re-run) puts them in place:

| In `agents/` | In `$HOME` | How |
|---|---|---|
| `claude/CLAUDE.md`, `RTK.md`, `statusline-command.sh` | `~/.claude/` | symlink |
| `claude/settings.base.json` | `~/.claude/settings.json` | merged: base + hooks this machine added (herdr's agent-state hook, always written with an absolute path) |
| `codex/config.base.toml` | `~/.codex/config.toml` | merged: base + this machine's trusted projects, hook trust hashes, MCP servers with local paths |
| `pi/settings.json`, `keybindings.json`, `extensions/claude-style-status.ts` | `~/.pi/agent/` | symlink |
| `skills/<name>` | `~/.claude/skills/`, `~/.codex/skills/` | symlink (one copy for both) |

Paths inside the shared files use `$HOME`, so they work on Linux and macOS. Edit the merged ones in `agents/` and re-run `agents/sync.sh`; `agents/sync.sh --check` lists anything out of place. Whatever a run replaces is backed up under `~/.local/state/agents-sync-backups/<time>/`.

Never in git: credentials (`.credentials.json`, `auth.json`), history and sessions, Codex `rules/` (per-machine approvals, which can contain secrets typed into a command), and the hook scripts rtk and herdr generate (`herdr integration install claude codex pi` recreates herdr's).

## Erase Everything

```bash
~/.config/uninstall.sh
```

### What uninstall.sh does

1. Runs `mise implode` — removes all mise-managed tools
2. Removes ble.sh, tmux plugins and any locally extracted legacy Kakoune
3. Removes symlinks, restores default `.bashrc`
4. Deletes all managed config dirs from `~/.config`
5. Cleans usage traces: `.bash_history`, nvim cache/state, atuin, zoxide, starship cache, bun, cargo/rustup
