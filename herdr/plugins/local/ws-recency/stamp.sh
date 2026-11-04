#!/usr/bin/env bash
# workspace.focused hook: after WS_RECENCY_DWELL seconds, if that workspace is
# still focused, move it to the top of the M-s switcher's recency log. The
# dwell keeps workspaces you merely pass through (M-] M-] M-]) out of the MRU.
# Hooks run under a bare PATH, so add herdr's own dir and mise's shims for the
# switcher's herdr/jq/fzf dependency check.
set -u
export PATH="$(dirname "${HERDR_BIN_PATH:-/nonexistent/herdr}"):$HOME/.local/share/mise/shims:$PATH"
switcher="$HOME/.config/herdr/scripts/workspace_switcher.sh"

focused() {
  herdr workspace list 2>/dev/null \
    | jq -r '.result.workspaces[] | select(.focused) | .workspace_id' | head -1
}

ws="$(jq -r '.workspace_id // .params.workspace_id // .data.workspace_id // empty' \
        <<<"${HERDR_PLUGIN_EVENT_JSON:-}" 2>/dev/null || true)"
[ -n "$ws" ] || ws="$(focused)"
[ -n "$ws" ] || exit 0

sleep "${WS_RECENCY_DWELL:-2}"
now="$(focused)"
[ "$now" = "$ws" ] || exit 0
exec bash "$switcher" --stamp "$ws"
