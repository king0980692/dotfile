#!/usr/bin/env bash
set -euo pipefail

DOTFILE_REPO="https://github.com/king0980692/dotfile.git"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BLESH_DIR="$HOME/.local/share/blesh"

info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
error() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*"; exit 1; }

# ── Tier ───────────────────────────────────────────────────────────
#   install.sh [--tier max|medium]
# max    (leon, the main dev machine): agent settings are symlinked into the
#        dotfiles, program repos (~/src/herdr-sidebar, ~/src/herdr-goto) live
#        here and releases are cut here.
# medium (e.g. the Mac): same tools and dotfiles, may commit dotfile fixes, but
#        agent settings are copied and program repos are not checked out.
# minimal machines do not run this script; they use
#        herdr/scripts/install-goto.sh (herdr-goto + its alt+s binding only).
# The tier is remembered in $TIER_FILE and read by agents/sync.sh.
TIER_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/tier"
tier=$(cat "$TIER_FILE" 2>/dev/null || echo max)
while [ $# -gt 0 ]; do
    case "$1" in
        --tier) tier="${2:-}"; shift 2 || shift ;;
        --tier=*) tier="${1#--tier=}"; shift ;;
        *) error "Unknown argument: $1 (usage: install.sh [--tier max|medium])" ;;
    esac
done
case "$tier" in
    max|medium) ;;
    minimal) error "minimal tier: run herdr/scripts/install-goto.sh instead of install.sh" ;;
    *) error "Unknown tier: $tier (max or medium)" ;;
esac
mkdir -p "$(dirname "$TIER_FILE")"
printf '%s\n' "$tier" > "$TIER_FILE"
info "Tier: $tier"

# ── 0. Platform prerequisites ─────────────────────────────────────
os=$(uname -s)
case "$os" in
    Darwin)
        # The system Bash is sufficient to bootstrap mise; mise installs Bash 5.
        info "macOS detected; source-built tools require Xcode Command Line Tools."
        ;;
    Linux)
        if ! locale -a 2>/dev/null | grep -qi 'en_US[._-]utf[-_]*8'; then
            warn "en_US.UTF-8 locale is unavailable. Generate it with your distribution's locale tools."
        fi
        ;;
    *) error "Unsupported operating system: $os (supported: macOS and Linux)." ;;
esac
for tool in git curl tar make; do
    command -v "$tool" >/dev/null 2>&1 || error "Required command not found: $tool"
done

# ── 1. Clone dotfiles ──────────────────────────────────────────────
if [ -d "$XDG_CONFIG_HOME/.git" ]; then
    info "Dotfile repo already cloned, pulling latest..."
    git -C "$XDG_CONFIG_HOME" pull --ff-only
else
    info "Cloning dotfiles into $XDG_CONFIG_HOME..."
    tmpdir=$(mktemp -d)
    git clone "$DOTFILE_REPO" "$tmpdir"

    # Merge into existing ~/.config without overwriting unrelated files
    mkdir -p "$XDG_CONFIG_HOME"
    cp -r "$tmpdir/.git" "$XDG_CONFIG_HOME/.git"
    # Copy only tracked dotfiles (preserving symlinks with -a)
    git -C "$tmpdir" ls-files | while IFS= read -r f; do
        mkdir -p "$XDG_CONFIG_HOME/$(dirname "$f")"
        cp -a "$tmpdir/$f" "$XDG_CONFIG_HOME/$f"
    done
    rm -rf "$tmpdir"
    info "Dotfiles merged into existing $XDG_CONFIG_HOME (other configs untouched)"
fi

# ── 2. Install mise (tool version manager) ─────────────────────────
if ! command -v mise &>/dev/null && [ ! -x "$HOME/.local/bin/mise" ]; then
    info "Installing mise..."
    curl https://mise.run | sh
else
    info "mise already installed"
fi
export PATH="$HOME/.local/bin:$PATH"

# ── 3. GitHub token for mise (avoids rate limiting) ────────────────
if [ -z "${MISE_GITHUB_TOKEN:-${GITHUB_TOKEN:-}}" ]; then
    warn "No GitHub token found. mise may hit rate limits."
    warn "Create one at: https://github.com/settings/tokens (no scopes needed)"
    if [ -t 0 ]; then
        read -rsp "  Paste your GitHub token (or press Enter to skip): " gh_token
        printf '\n'
        if [ -n "$gh_token" ]; then
            export MISE_GITHUB_TOKEN="$gh_token"
        fi
        unset gh_token
    else
        warn "No interactive input available; continuing without a token."
    fi
else
    export MISE_GITHUB_TOKEN="${MISE_GITHUB_TOKEN:-$GITHUB_TOKEN}"
fi

# ── 4. Install all tools via mise ──────────────────────────────────
info "Installing tools from mise config..."
mise install --yes || warn "Some tools failed to install (may be rate-limited). Run 'mise install' again later."

# Restore third-party Yazi plugins and flavors from the tracked package lock.
info "Installing Yazi packages..."
mise exec -- ya pkg install || warn "Yazi packages failed to install. Run 'mise exec -- ya pkg install' again later."

# Register the local manifest; mise, not Herdr, supplies the sidebar binary.
# Never silently replace a plugin already registered by the user.
if herdr_bin=$(mise which herdr 2>/dev/null) && sidebar_plugins=$("$herdr_bin" plugin list 2>/dev/null); then
    if printf '%s\n' "$sidebar_plugins" | grep -q '^- herdr-sidebar '; then
        info "herdr-sidebar already registered; leaving its existing registration unchanged."
        warn "To use the mise-managed sidebar, unlink the old registration and link $XDG_CONFIG_HOME/herdr/plugins/local/herdr-sidebar."
    else
        "$herdr_bin" plugin link "$XDG_CONFIG_HOME/herdr/plugins/local/herdr-sidebar" --enabled \
            || warn "Could not register the sidebar manifest; link it manually with herdr plugin link."
    fi
else
    warn "Could not list Herdr plugins; register the sidebar manifest manually after installing Herdr."
fi

# ── 4. Install ble.sh (prebuilt nightly, no make required) ────────
if [ ! -d "$BLESH_DIR" ]; then
    info "Installing ble.sh..."
    tmpdir=$(mktemp -d)
    curl -L https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz \
        | tar xJf - -C "$tmpdir"
    mkdir -p "$HOME/.local/share/blesh"
    cp -r "$tmpdir"/ble-nightly/* "$HOME/.local/share/blesh/"
    rm -rf "$tmpdir"
else
    info "ble.sh already installed"
fi

# ── 5. Symlink .bashrc & .blerc ────────────────────────────────────
info "Symlinking shell configs..."
ln -sfn "$XDG_CONFIG_HOME/bash/.bashrc" "$HOME/.bashrc"

ln -sfn "$XDG_CONFIG_HOME/bash/.blerc" "$HOME/.blerc"

# ── 6. Symlink .gitconfig ──────────────────────────────────────────
if [ -f "$XDG_CONFIG_HOME/.gitconfig" ]; then
    info "Symlinking .gitconfig..."
    ln -sfn "$XDG_CONFIG_HOME/.gitconfig" "$HOME/.gitconfig"
fi

# ── 7. Install tmux plugins (TPM) ─────────────────────────────────
if [ ! -d "$XDG_CONFIG_HOME/tmux/plugins/tpm" ]; then
    info "Installing TPM (tmux plugin manager)..."
    git clone https://github.com/tmux-plugins/tpm "$XDG_CONFIG_HOME/tmux/plugins/tpm"
fi

# ── 8. Coding agents (Claude Code, Codex, pi) ──────────────────────
# Shared settings, skills and the pi status extension, linked or merged into
# $HOME (agents/sync.sh explains which and why). Credentials never move.
info "Linking (max) or copying (medium) coding-agent settings..."
"$XDG_CONFIG_HOME/agents/sync.sh" || warn "agents/sync.sh reported a problem; re-run it after fixing."
# The herdr hooks each agent calls are generated per machine (absolute paths).
if herdr_bin=$(mise which herdr 2>/dev/null); then
    for agent in claude codex pi; do
        "$herdr_bin" integration install "$agent" >/dev/null 2>&1 \
            || warn "herdr integration install $agent failed; run it once that agent is installed."
    done
fi

info ""
info "========================================="
info " Installation complete!"
info "========================================="
info ""
if [ "$os" = Darwin ]; then
    info " Start mise-managed Bash: exec \"$(mise where bash)/bin/bash\""
    info " For login shells, source ~/.bashrc from ~/.bash_profile."
else
    info " Restart your shell or run:  exec bash"
fi
info ""
info " In tmux, press prefix + I to install tmux plugins."
info ""
