#!/usr/bin/env bash
# Claude Code SessionStart hook for herdr-assistant-resurrect.
#
# Records the running Claude session keyed by HERDR_PANE_ID, so the periodic
# save script can map "this herdr pane" -> "this Claude session id" with zero PID
# guessing (Claude re-execs on resume, so PID-keyed state is unreliable).
#
# No-op outside herdr. Must never break Claude: always exits 0.
#
# Install: added to ~/.claude/settings.json under hooks.SessionStart alongside
# the tmux one. State dir is ephemeral (cleared on reboot) — the save script
# copies what it needs into the persistent ~/.config/herdr/resurrect/agents.json.

input="$(cat 2>/dev/null)"

{
  [ -n "${HERDR_PANE_ID:-}" ] || exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  sid="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
  [ -n "$sid" ] || exit 0

  dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/herdr-resurrect"
  mkdir -p -m 0700 "$dir" 2>/dev/null || exit 0
  key="${HERDR_PANE_ID//[^A-Za-z0-9]/_}"

  printf '%s' "$input" | jq \
    --arg tool     "claude" \
    --arg pane     "${HERDR_PANE_ID:-}" \
    --arg tab      "${HERDR_TAB_ID:-}" \
    --arg ws       "${HERDR_WORKSPACE_ID:-}" \
    --arg ts       "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{tool:$tool, session_id:.session_id, cwd:.cwd, source:.source,
      herdr_pane:$pane, herdr_tab:$tab, herdr_workspace:$ws, ts:$ts}' \
    > "$dir/pane-$key.json" 2>/dev/null
} >/dev/null 2>&1

exit 0
