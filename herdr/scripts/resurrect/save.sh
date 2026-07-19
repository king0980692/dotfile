#!/usr/bin/env bash
# herdr-assistant-resurrect — SAVE.
# Snapshot every running herdr agent pane + its assistant session id into a
# persistent file, so the sessions can be resumed after a herdr restart/reboot.
#
#   for each pane in `herdr agent list`:
#     herdr pane process-info -> agent pid / argv / cwd
#     session id <- herdr SessionStart hook state (keyed by HERDR_PANE_ID),
#                   falling back to the tmux-assistant-resurrect state (by cwd)
#   -> ~/.config/herdr/resurrect/agents.json
#
# Run periodically (timer/loop) and/or manually. Read-only against herdr.
set -uo pipefail

# Run from anywhere (systemd/cron don't source bashrc, so mise PATH is absent).
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/installs/herdr/latest:$HOME/.local/share/mise/installs/jq/latest:$PATH"

OUT="$HOME/.config/herdr/resurrect/agents.json"
mkdir -p "$(dirname "$OUT")"
STATE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/herdr-resurrect"
TMUX_STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/tmux-assistant-resurrect"

command -v herdr >/dev/null 2>&1 || { echo "herdr not found" >&2; exit 1; }
command -v jq    >/dev/null 2>&1 || { echo "jq not found" >&2; exit 1; }

sanitize() { printf '%s' "$1" | tr -c 'A-Za-z0-9' '_'; }

ws_json="$(herdr workspace list 2>/dev/null)"
entries='[]'

while IFS=$'\t' read -r pane agent ws tab; do
  [ -n "$pane" ] || continue

  pinfo="$(herdr pane process-info --pane "$pane" 2>/dev/null)"
  cwd="$(printf '%s' "$pinfo"  | jq -r --arg a "$agent" '.result.process_info.foreground_processes[]?|select(.name==$a)|.cwd'  2>/dev/null | head -1)"
  argv="$(printf '%s' "$pinfo" | jq -c --arg a "$agent" '.result.process_info.foreground_processes[]?|select(.name==$a)|.argv' 2>/dev/null | head -1)"
  [ -n "$argv" ] || argv="null"

  # --- session id ---
  sid=""; src=""
  hf="$STATE_DIR/pane-$(sanitize "$pane").json"
  if [ -f "$hf" ]; then
    sid="$(jq -r '.session_id // empty' "$hf" 2>/dev/null)"
    [ -n "$sid" ] && src="herdr-hook"
  fi
  if [ -z "$sid" ] && [ "$agent" = "claude" ] && [ -d "$TMUX_STATE_DIR" ]; then
    for f in $(ls -t "$TMUX_STATE_DIR"/claude-*.json 2>/dev/null); do
      [ "$(jq -r '.cwd // empty' "$f" 2>/dev/null)" = "$cwd" ] || continue
      sid="$(jq -r '.session_id // empty' "$f" 2>/dev/null)"
      [ -n "$sid" ] && { src="tmux-hook-cwd"; break; }
    done
  fi

  wlabel="$(printf '%s' "$ws_json" | jq -r --arg w "$ws" '.result.workspaces[]?|select(.workspace_id==$w)|.label // ""' 2>/dev/null)"

  entry="$(jq -n \
    --arg pane "$pane" --arg tool "$agent" --arg ws "$ws" --arg tab "$tab" \
    --arg wlabel "$wlabel" --arg ppub "${pane##*:}" --arg cwd "$cwd" \
    --argjson argv "$argv" --arg sid "$sid" --arg src "$src" \
    '{pane:$pane, tool:$tool, workspace_id:$ws, workspace_label:$wlabel,
      tab_id:$tab, pane_public:$ppub, cwd:$cwd, argv:$argv,
      session_id:$sid, sid_source:$src}')"
  entries="$(printf '%s' "$entries" | jq --argjson e "$entry" '. + [$e]')"
done < <(herdr agent list 2>/dev/null | jq -r '.result.agents[]? | [.pane_id, .agent, .workspace_id, .tab_id] | @tsv' 2>/dev/null)

n="$(printf '%s' "$entries" | jq 'length')"
got="$(printf '%s' "$entries" | jq '[.[]|select(.session_id!="")]|length')"

# Don't clobber good pre-reboot data with an empty snapshot. Right after a
# reboot the restored panes are still plain shells (no agent detected yet), so a
# save that runs before they resume would otherwise wipe the resume list. If the
# new snapshot has no session ids but the existing file does, keep the old one.
if [ "$got" -eq 0 ] && [ -f "$OUT" ]; then
  oldgot="$(jq '[.agents[]?|select(.session_id!="")]|length' "$OUT" 2>/dev/null || echo 0)"
  if [ "${oldgot:-0}" -gt 0 ]; then
    echo "no live agent sessions; preserving existing $OUT ($oldgot pending)"
    exit 0
  fi
fi

jq -n --argjson agents "$entries" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{version:1, saved_at:$ts, agents:$agents}' > "$OUT"
echo "saved $n agent pane(s), $got with session id -> $OUT"
