#!/usr/bin/env bash
# On pane.closed: any tab whose remaining panes are ALL herdr-sidebar panes
# (Explorer / Source Control, identified by their metadata tokens) gets those
# panes closed, which closes the tab like closing its last real pane would.
# Hook commands run under a bare PATH, so call herdr via $HERDR_BIN_PATH.
herdr="${HERDR_BIN_PATH:-herdr}"

"$herdr" pane list | /usr/bin/python3 -c '
import json, sys
SIDEBAR = ("herdr-sidebar-explorer", "herdr-sidebar-git")
tabs = {}
for p in json.load(sys.stdin)["result"]["panes"]:
    tabs.setdefault(p["tab_id"], []).append(p)
for panes in tabs.values():
    if all(any(t in (p.get("tokens") or {}) for t in SIDEBAR) for p in panes):
        for p in panes:
            print(p["pane_id"])
' | while read -r pane; do
    "$herdr" pane close "$pane"
done
