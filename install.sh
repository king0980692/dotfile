#!/usr/bin/env bash
set -euo pipefail

DOTFILE_REPO="git@github.com:king0980692/dotfile.git"
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
    # If .config already exists, clone into temp and move .git + files in
    if [ -d "$XDG_CONFIG_HOME" ]; then
        tmpdir=$(mktemp -d)
        git clone "$DOTFILE_REPO" "$tmpdir"
        cp -r "$tmpdir/.git" "$XDG_CONFIG_HOME/.git"
        git -C "$XDG_CONFIG_HOME" checkout -- .
        rm -rf "$tmpdir"
    else
        git clone "$DOTFILE_REPO" "$XDG_CONFIG_HOME"
    fi
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
mise install --yes

# ── 4. Install ble.sh ──────────────────────────────────────────────
if [ ! -d "$BLESH_DIR" ]; then
    info "Installing ble.sh..."
    # Use mise-installed git/make
    tmpdir=$(mktemp -d)
    git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git "$tmpdir/ble.sh"
    make -C "$tmpdir/ble.sh" install PREFIX="$HOME/.local"
    rm -rf "$tmpdir"
else
    info "ble.sh already installed"
fi

# ── 5. Symlink .bashrc & .blerc ────────────────────────────────────
info "Symlinking shell configs..."
ln -sfn "$XDG_CONFIG_HOME/bash/.bashrc" "$HOME/.bashrc"

# Create .blerc if not present (points to config in repo)
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
