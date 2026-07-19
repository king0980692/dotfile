#!/usr/bin/env bash
# herdr session detach-loop launcher.
#
# Launch herdr THROUGH this instead of bare `herdr`. It shows the fzf session
# switcher; you pick/create a session and it attaches. When you DETACH the
# herdr client (your prefix+d), control returns here and the switcher pops back
# up — the same feel as tmux's switch-client, adapted to herdr's separate-server
# session model.
#
#   alias hs='~/.config/herdr/scripts/herdr_sessions.sh'
set -euo pipefail

sw="$(cd "$(dirname "$0")" && pwd)/session_switcher.sh"

while true; do
  name="$("$sw")" || break          # Esc/q -> empty/non-zero -> quit the loop
  [ -n "${name// /}" ] || break
  # Attach (or create) the chosen session. Blocks until you detach it.
  herdr --session "$name"
done
