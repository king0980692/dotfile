#!/bin/sh
# Tab-bar status entry ([ui] tab_bar_right): how many agents need you, e.g.
#   ! 1 wait · ✓ 2 done
# blocked = waiting for your input, done = finished and not yet looked at.
# Prints nothing when nothing needs attention, so herdr hides the entry.
# Runs under herdr's bare /bin/sh -lc, where mise's jq is not on PATH, so
# parse with the system python3 and call herdr through $HERDR_BIN_PATH.
"${HERDR_BIN_PATH:-herdr}" agent list 2>/dev/null | /usr/bin/python3 -c '
import json, sys
try:
    agents = json.load(sys.stdin)["result"]["agents"]
except Exception:
    sys.exit(0)
count = lambda s: sum(a.get("agent_status") == s for a in agents)
parts = []
if count("blocked"): parts.append("! %d wait" % count("blocked"))
if count("done"):    parts.append("✓ %d done" % count("done"))
print(" · ".join(parts))
'
