#!/usr/bin/env bash
# herdr-assistant-resurrect — SAVE.
# Snapshot every running herdr agent pane + its assistant session id into a
# persistent file, so the sessions can be resumed after a herdr restart/reboot.
#
#   for each pane in `herdr agent list` (claude / opencode / codex):
#     herdr pane process-info -> agent pid / argv / cmdline / cwd
#     session id via tool-native sources (ported from tmux-assistant-resurrect)
#   -> ~/.config/herdr/resurrect/agents.json
#
# Run periodically (systemd timer) and/or manually. Read-only against herdr.
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

# --- per-tool session id extraction (pid, cmdline, cwd, herdr_pane) ---

get_claude_session() {   # $1 pane_id  $2 cmdline  $3 cwd
  local pane="$1" args="$2" cwd="$3" sid
  # 1) herdr SessionStart hook, keyed by HERDR_PANE_ID
  local hf="$STATE_DIR/pane-$(sanitize "$pane").json"
  [ -f "$hf" ] && sid="$(jq -r '.session_id // empty' "$hf" 2>/dev/null)" && [ -n "$sid" ] && { echo "$sid"; return; }
  # 2) tmux-assistant-resurrect claude-<pid>.json, newest matching cwd
  if [ -d "$TMUX_STATE_DIR" ]; then
    local f
    for f in $(ls -t "$TMUX_STATE_DIR"/claude-*.json 2>/dev/null); do
      [ "$(jq -r '.cwd // empty' "$f" 2>/dev/null)" = "$cwd" ] || continue
      sid="$(jq -r '.session_id // empty' "$f" 2>/dev/null)"; [ -n "$sid" ] && { echo "$sid"; return; }
    done
  fi
  # 3) --resume <id> / --resume=<id> in args
  sid="$(printf '%s' "$args" | sed -n 's/.*--resume[= ] *\([A-Za-z0-9_-]*\).*/\1/p')"
  [ -n "$sid" ] && echo "$sid"
}

get_opencode_session() { # $1 pid  $2 cmdline  $3 cwd
  local pid="$1" args="$2" cwd="$3" sid
  # 1) -s ses_...   2) --session[= ]ses_...
  sid="$(printf '%s' "$args" | sed -n 's/.*-s \(ses_[A-Za-z0-9_]*\).*/\1/p')";               [ -n "$sid" ] && { echo "$sid"; return; }
  sid="$(printf '%s' "$args" | sed -n 's/.*--session[= ] *\(ses_[A-Za-z0-9_]*\).*/\1/p')";   [ -n "$sid" ] && { echo "$sid"; return; }
  # 3) opencode.db: most recently updated session for this cwd
  local db="$HOME/.local/share/opencode/opencode.db"
  if [ -n "$cwd" ] && [ -f "$db" ] && command -v python3 >/dev/null 2>&1; then
    sid="$(python3 -c "
import sqlite3,sys
try:
    c=sqlite3.connect('file:'+sys.argv[1]+'?mode=ro',uri=True).cursor()
    c.execute('SELECT id FROM session WHERE directory=? ORDER BY time_updated DESC LIMIT 1',(sys.argv[2],))
    r=c.fetchone()
    print(r[0] if r else '')
except Exception: pass
" "$db" "$cwd" 2>/dev/null)"
    [ -n "$sid" ] && echo "$sid"
  fi
}

get_codex_session() {    # $1 pid  $2 cmdline
  local pid="$1" args="$2" sid
  # 1) ~/.codex/session-tags.jsonl keyed by pid
  local tags="$HOME/.codex/session-tags.jsonl"
  if [ -f "$tags" ]; then
    sid="$(grep "\"pid\": *${pid}[,}]" "$tags" 2>/dev/null | tail -1 | jq -r '.session // empty' 2>/dev/null)"
    [ -n "$sid" ] && { echo "$sid"; return; }
  fi
  # 2) `resume <id>` in args
  sid="$(printf '%s' "$args" | sed -n 's/.*resume  *\([A-Za-z0-9_-]*\).*/\1/p')"
  [ -n "$sid" ] && echo "$sid"
}

ws_json="$(herdr workspace list 2>/dev/null)"
entries='[]'

while IFS=$'\t' read -r pane agent ws tab; do
  [ -n "$pane" ] || continue

  pinfo="$(herdr pane process-info --pane "$pane" 2>/dev/null)"
  fp="$(printf '%s' "$pinfo" | jq -c --arg a "$agent" '.result.process_info.foreground_processes[]?|select(.name==$a)' 2>/dev/null | head -1)"
  [ -n "$fp" ] || fp="$(printf '%s' "$pinfo" | jq -c '.result.process_info.foreground_processes[0]?' 2>/dev/null)"
  cwd="$(printf '%s' "$fp"  | jq -r '.cwd // empty' 2>/dev/null)"
  pid="$(printf '%s' "$fp"  | jq -r '.pid // empty' 2>/dev/null)"
  cmd="$(printf '%s' "$fp"  | jq -r '.cmdline // empty' 2>/dev/null)"
  argv="$(printf '%s' "$fp" | jq -c '.argv // ["'"$agent"'"]' 2>/dev/null)"; [ -n "$argv" ] || argv="null"

  case "$agent" in
    claude)   sid="$(get_claude_session   "$pane" "$cmd" "$cwd")" ;;
    opencode) sid="$(get_opencode_session "$pid"  "$cmd" "$cwd")" ;;
    codex)    sid="$(get_codex_session    "$pid"  "$cmd")" ;;
    *)        sid="" ;;
  esac

  wlabel="$(printf '%s' "$ws_json" | jq -r --arg w "$ws" '.result.workspaces[]?|select(.workspace_id==$w)|.label // ""' 2>/dev/null)"

  entry="$(jq -n \
    --arg pane "$pane" --arg tool "$agent" --arg ws "$ws" --arg tab "$tab" \
    --arg wlabel "$wlabel" --arg ppub "${pane##*:}" --arg cwd "$cwd" \
    --argjson argv "$argv" --arg sid "${sid:-}" \
    '{pane:$pane, tool:$tool, workspace_id:$ws, workspace_label:$wlabel,
      tab_id:$tab, pane_public:$ppub, cwd:$cwd, argv:$argv, session_id:$sid}')"
  entries="$(printf '%s' "$entries" | jq --argjson e "$entry" '. + [$e]')"
done < <(herdr agent list 2>/dev/null | jq -r '.result.agents[]? | [.pane_id, .agent, .workspace_id, .tab_id] | @tsv' 2>/dev/null)

n="$(printf '%s' "$entries" | jq 'length')"
got="$(printf '%s' "$entries" | jq '[.[]|select(.session_id!="")]|length')"

# Don't clobber good pre-reboot data with an empty snapshot (see restore race).
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
