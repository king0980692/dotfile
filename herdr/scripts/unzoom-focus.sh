#!/usr/bin/env bash
# Unzoom (if zoomed) then focus a neighbouring pane. Bound to Alt+h/j/k/l so
# directional navigation in a zoomed pane first restores the tiled layout instead
# of moving while staying zoomed. `zoom --off` is a no-op when not zoomed.
#
# PATH bootstrap: herdr runs custom commands without the interactive shell's
# PATH, so `herdr` may not resolve — add its mise install dir explicitly.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/installs/herdr/latest:$PATH"
herdr pane zoom --off --current >/dev/null 2>&1
exec herdr pane focus --direction "${1:?direction required}" --current
