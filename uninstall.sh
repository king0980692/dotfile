#!/usr/bin/env bash
set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }

echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   Dotfile & Environment Cleanup Script   ║"
echo "  ╚══════════════════════════════════════════╝"
echo ""
echo "  This will remove:"
echo "    - mise and all tools installed by it"
echo "    - ble.sh"
echo "    - tmux plugins"
echo "    - Shell config symlinks (.bashrc, .blerc, .gitconfig)"
echo "    - Dotfile repo from $XDG_CONFIG_HOME"
echo "    - Shell history and cache traces"
echo ""
read -rp "  Are you sure? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ── 1. Remove mise and all tools ───────────────────────────────────
if command -v mise &>/dev/null || [ -x "$HOME/.local/bin/mise" ]; then
    info "Removing mise-installed tools..."
    "$HOME/.local/bin/mise" implode --yes 2>/dev/null || true
fi
rm -rf "$HOME/.local/share/mise" "$HOME/.local/bin/mise"

# ── 2. Remove ble.sh ──────────────────────────────────────────────
info "Removing ble.sh..."
rm -rf "$HOME/.local/share/blesh"
rm -rf "$HOME/ble-nightly"

# ── 3. Remove tmux plugins ────────────────────────────────────────
info "Removing tmux plugins..."
rm -rf "$XDG_CONFIG_HOME/tmux/plugins"

# ── 4. Remove symlinks ────────────────────────────────────────────
info "Removing symlinks..."
[ -L "$HOME/.bashrc" ]    && rm -f "$HOME/.bashrc"
[ -L "$HOME/.gitconfig" ] && rm -f "$HOME/.gitconfig"
rm -f "$HOME/.blerc"

# Restore default .bashrc
if [ -f /etc/skel/.bashrc ]; then
    cp /etc/skel/.bashrc "$HOME/.bashrc"
    info "Restored default .bashrc from /etc/skel"
fi

# ── 5. Remove dotfile configs ─────────────────────────────────────
info "Removing dotfile config directories..."
MANAGED_DIRS=(bash nvim mise tmux leon_scripts lazygit yazi git)
for dir in "${MANAGED_DIRS[@]}"; do
    rm -rf "${XDG_CONFIG_HOME:?}/$dir"
done
rm -f "$XDG_CONFIG_HOME/.gitconfig"
rm -f "$XDG_CONFIG_HOME/starship.toml"
rm -f "$XDG_CONFIG_HOME/.gitignore"
rm -rf "$XDG_CONFIG_HOME/.git"

# ── 6. Clean usage traces ─────────────────────────────────────────
info "Cleaning usage traces..."
rm -f  "$HOME/.bash_history"
rm -rf "$HOME/.cache/nvim"
rm -rf "$HOME/.local/share/nvim"
rm -rf "$HOME/.local/state/nvim"
rm -rf "$HOME/.cache/mise"
rm -rf "$HOME/.local/share/atuin"
rm -rf "$HOME/.local/share/zoxide"
rm -rf "$HOME/.cache/starship"
# Clean bun
rm -rf "$HOME/.bun"

# Clean cargo/rust (installed by mise)
rm -rf "$HOME/.cargo" "$HOME/.rustup"

info ""
info "========================================="
info " Cleanup complete!"
info "========================================="
info ""
info " Your environment has been wiped clean."
info " Restart your shell: exec bash"
info ""
