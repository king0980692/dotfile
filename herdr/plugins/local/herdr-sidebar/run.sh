#!/bin/sh
# Resolve only an already-installed, mise-pinned sidebar. Never install on a focus event.
set -eu
if [ -x "$HOME/.local/bin/mise" ]; then mise_bin="$HOME/.local/bin/mise"
elif command -v mise >/dev/null 2>&1; then mise_bin=$(command -v mise)
elif [ -x "$HOME/.local/share/mise/bin/mise" ]; then mise_bin="$HOME/.local/share/mise/bin/mise"
else printf '%s\n' 'herdr-sidebar: mise is not installed' >&2; exit 127; fi
root=$("$mise_bin" --cd "$HOME" where github:king0980692/herdr-sidebar) || exit 1
exec "$root/bin/herdr-sidebar" "$@"
