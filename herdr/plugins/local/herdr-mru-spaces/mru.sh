#!/usr/bin/env bash
# MRU Spaces — herdr event hook for workspace.focused.
# Moves a workspace to the top of the sidebar only after you have DWELLED in it,
# so the Spaces list reads most-recently-USED, not most-recently-touched:
# clicking into a workspace and bouncing straight out does not reshuffle the
# list. The CLI has no `workspace move`, so the move goes over the socket
# ($HERDR_SOCKET_PATH) as a raw workspace.move request.
set -u

DWELL="${MRU_DWELL:-4}"   # seconds you must stay before the workspace is bumped

herdr_bin="${HERDR_BIN_PATH:-herdr}"

# The workspace this event is about. Field name probed defensively; falls back
# to whatever is focused right now if the payload carries no id.
ev="${HERDR_PLUGIN_EVENT_JSON:-}"
ev_ws="$(jq -r '.workspace_id // .params.workspace_id // .data.workspace_id // empty' \
          <<<"$ev" 2>/dev/null || true)"
if [ -z "$ev_ws" ]; then
  ev_ws="$("$herdr_bin" workspace list 2>/dev/null \
    | jq -r '.result.workspaces[] | select(.focused) | .workspace_id' | head -1)"
fi
[ -n "$ev_ws" ] || exit 0

sleep "$DWELL"

# Only bump if we are STILL in that workspace — a quick visit that already
# moved on gets handled by the destination's own event instead.
read -r now_ws now_index < <("$herdr_bin" workspace list 2>/dev/null | jq -r '
  .result.workspaces | to_entries[] | select(.value.focused)
  | "\(.value.workspace_id) \(.key)"' | head -1) || exit 0

[ "${now_ws:-}" = "$ev_ws" ] || { echo "skip: left $ev_ws before ${DWELL}s"; exit 0; }
[ "${now_index:-0}" = 0 ] && exit 0       # already on top

echo "bump: $ev_ws (was index $now_index) event=$ev"
WS_ID="$ev_ws" python3 - <<'PY' >/dev/null 2>&1
import json, os, socket
s = socket.socket(socket.AF_UNIX); s.settimeout(2)
s.connect(os.environ["HERDR_SOCKET_PATH"])
req = {"id": "mru-spaces", "method": "workspace.move",
       "params": {"workspace_id": os.environ["WS_ID"], "insert_index": 0}}
s.sendall(json.dumps(req).encode() + b"\n")
s.recv(4096)
PY
