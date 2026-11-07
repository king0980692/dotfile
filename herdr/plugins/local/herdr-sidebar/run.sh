#!/bin/sh
# Prefer this machine's local build; fall back to mise on other machines.
local_bin="$HOME/herdr-sidebar/plugins/herdr-sidebar/target/release/herdr-sidebar"
if [ -x "$local_bin" ]; then
    exec "$local_bin" "$@"
fi
# Resolve the pinned mise-managed sidebar even when the Herdr server has a
# minimal PATH (for example when launched outside an interactive shell).
if command -v mise >/dev/null 2>&1; then
    mise_bin=$(command -v mise)
elif [ -x "$HOME/.local/bin/mise" ]; then
    mise_bin="$HOME/.local/bin/mise"
else
    printf '%s\n' 'herdr-sidebar: mise not found' >&2
    exit 127
fi
# Unlike `mise exec`, `mise where` never installs unrelated missing tools on
# a focus event. The configured revision must already be installed.
root=$("$mise_bin" where cargo:king0980692/herdr-sidebar) || exit 1
exec "$root/bin/herdr-sidebar" "$@"
