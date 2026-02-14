#!/usr/bin/env bash
set -euo pipefail

DOTFILE_REPO="https://github.com/king0980692/dotfile.git"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BLESH_DIR="$HOME/.local/share/blesh"

info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
error() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*"; exit 1; }

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

# ── 3. Install all tools via mise ──────────────────────────────────
info "Installing tools from mise config..."
mise install --yes || warn "Some tools failed to install (may be rate-limited). Run 'mise install' again later."

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

# Create .blerc if not present
if [ ! -f "$HOME/.blerc" ]; then
    cat > "$HOME/.blerc" << 'BLERC'

########################
# Setting prompt colors
########################

get_color() { tput setaf "$1"; }

COL_USER="${color4:-$(get_color 12)}"
COL_HOST="${color6:-$(get_color 5)}"
COL_PATH="${color2:-$(get_color 11)}"
COL_ROOT="${color1:-$(get_color 1)}"
COL_RESET="$(tput sgr0)"

bleopt prompt_ps1_final=
bleopt prompt_ps1_transient=

function ble/prompt/backslash:my/vim-mode {
  bleopt keymap_vi_mode_update_prompt:=1
  case $_ble_decode_keymap in
    (vi_[on]map) ble/prompt/print '(cmd)' ;;
    (vi_imap)    ble/prompt/print '(ins)' ;;
    (vi_smap)    ble/prompt/print '(sel)' ;;
    (vi_xmap)    ble/prompt/print '(vis)' ;;
  esac
}
BLERC
fi

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

info ""
info "========================================="
info " Installation complete!"
info "========================================="
info ""
info " Restart your shell or run:  exec bash"
info ""
info " In tmux, press prefix + I to install tmux plugins."
info ""
