#!/usr/bin/env bash
# pane.agent_status_changed hook: note the time against the pane's workspace,
# for the M-s switcher's LAST column. Hooks run under a bare PATH (see stamp.sh).
set -u
export PATH="$(dirname "${HERDR_BIN_PATH:-/nonexistent/herdr}"):$HOME/.local/share/mise/shims:$PATH"
ws="$(jq -r '.data.workspace_id // .workspace_id
             // ((.data.pane_id // .pane_id // "") | split(":")[0])
             | select(. != "")' <<<"${HERDR_PLUGIN_EVENT_JSON:-}" 2>/dev/null || true)"
[ -n "$ws" ] || exit 0
exec bash "$HOME/.config/herdr/scripts/workspace_switcher.sh" --touch "$ws"
