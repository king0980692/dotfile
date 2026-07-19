#!/usr/bin/env bash
# herdr-assistant-resurrect — RESTORE probe, called from ~/.bashrc.
#
# On a herdr pane that was just restored after a reboot, if this pane matches a
# saved agent session (agents.json) print `RESUME <shell-quoted argv>` on stdout
# and the caller execs it. Prints nothing otherwise. Never resumes twice for the
# same pane in the same boot (marker lives in XDG_RUNTIME_DIR, which the OS wipes
# on reboot, so it self-resets each boot).
#
# Disable entirely with HERDR_NO_RESURRECT=1.
set -uo pipefail

[ -n "${HERDR_ENV:-}" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
[ -z "${HERDR_NO_RESURRECT:-}" ] || exit 0

AGENTS="$HOME/.config/herdr/resurrect/agents.json"
[ -f "$AGENTS" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v herdr >/dev/null 2>&1 || exit 0

# per-boot, per-pane guard (RUNTIME dir is cleared on reboot -> resets each boot)
mdir="${XDG_RUNTIME_DIR:-/tmp}/herdr-resurrect/restored"
mkdir -p "$mdir" 2>/dev/null || exit 0
marker="$mdir/$(printf '%s' "$HERDR_PANE_ID" | tr -c 'A-Za-z0-9' '_')"
[ -e "$marker" ] && exit 0

# cheap bail: any saved agent with a session id at all?
[ "$(jq '[.agents[]?|select(.session_id!="")]|length' "$AGENTS" 2>/dev/null)" -gt 0 ] 2>/dev/null || { touch "$marker" 2>/dev/null; exit 0; }

# identify this pane: workspace label + public pane number + cwd
wlabel="$(herdr workspace list 2>/dev/null | jq -r --arg w "${HERDR_WORKSPACE_ID:-}" '.result.workspaces[]?|select(.workspace_id==$w)|.label // ""' 2>/dev/null)"
ppub="${HERDR_PANE_ID##*:}"

entry="$(jq -c --arg wl "$wlabel" --arg pp "$ppub" --arg cwd "$PWD" '
  .agents[]?
  | select(.workspace_label==$wl and .pane_public==$pp and .cwd==$cwd and .session_id!="")
' "$AGENTS" 2>/dev/null | head -1)"

# mark handled regardless, so we never re-probe this pane this boot
touch "$marker" 2>/dev/null
[ -n "$entry" ] || exit 0

# only claude for now
[ "$(printf '%s' "$entry" | jq -r '.tool')" = "claude" ] || exit 0

# reconstruct argv with `--resume <session_id>` and emit shell-quoted
cmd="$(printf '%s' "$entry" | jq -r '
  .session_id as $sid
  | (.argv // ["claude"]) as $a
  | ($a | index("--resume")) as $i
  | (if $i == null then $a + ["--resume", $sid]
     else $a[0:$i+1] + [$sid] + $a[$i+1:] end)
  | @sh')"
[ -n "$cmd" ] && printf 'RESUME %s\n' "$cmd"
