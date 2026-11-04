#!/usr/bin/env python3
"""
Read ~/.claude/projects/**/*.jsonl and output today's Claude API cost
for the tmux status bar.
"""
import os
import json
from datetime import datetime, timezone

PROJECTS_DIR = os.path.expanduser("~/.claude/projects")
TODAY = datetime.now(timezone.utc).date()

# Claude Sonnet 4.x pricing (per token)
PRICE = {
    "input":          3.00  / 1_000_000,
    "cache_creation": 3.75  / 1_000_000,
    "cache_read":     0.30  / 1_000_000,
    "output":        15.00  / 1_000_000,
}

total_cost  = 0.0
total_in    = 0
total_out   = 0

try:
    for project in os.scandir(PROJECTS_DIR):
        if not project.is_dir():
            continue
        for entry in os.scandir(project.path):
            if not entry.name.endswith(".jsonl"):
                continue
            # Skip files not touched today (fast path)
            mtime = datetime.fromtimestamp(entry.stat().st_mtime, tz=timezone.utc).date()
            if mtime < TODAY:
                continue
            with open(entry.path) as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        obj = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if obj.get("type") != "assistant":
                        continue
                    ts = obj.get("timestamp", "")
                    if not ts:
                        continue
                    entry_date = datetime.fromisoformat(
                        ts.replace("Z", "+00:00")
                    ).date()
                    if entry_date != TODAY:
                        continue
                    usage = obj.get("message", {}).get("usage", {})
                    if not usage:
                        continue
                    inp  = usage.get("input_tokens", 0)
                    cc   = usage.get("cache_creation_input_tokens", 0)
                    cr   = usage.get("cache_read_input_tokens", 0)
                    out  = usage.get("output_tokens", 0)
                    total_in  += inp + cc + cr
                    total_out += out
                    total_cost += (
                        inp  * PRICE["input"] +
                        cc   * PRICE["cache_creation"] +
                        cr   * PRICE["cache_read"] +
                        out  * PRICE["output"]
                    )
except Exception:
    print("--")
    raise SystemExit

if total_cost == 0 and total_in == 0:
    print("$0")
else:
    tok_k = (total_in + total_out) / 1000
    if tok_k >= 1:
        print(f"${total_cost:.2f} {tok_k:.0f}k tok")
    else:
        print(f"${total_cost:.3f}")
