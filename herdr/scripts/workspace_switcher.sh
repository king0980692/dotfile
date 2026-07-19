#!/usr/bin/env bash
# Live WORKSPACE switcher + manager for herdr — fzf overlay, the analog of your
# tmux session switcher. Runs inside herdr as a [[keys.command]] type="pane";
# every action is a socket-API call to the SAME server (not nested herdr).
#
#   list  : herdr workspace list
#   switch: herdr workspace focus  <id>
#   new   : herdr workspace create --label <name> --focus
#   delete: herdr workspace close  <id>
#   rename: herdr workspace rename <id> <label>
#
# Keys:  Enter/Click switch · n new · x delete · r rename · / search · q quit
set -euo pipefail

self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

render() {
  herdr workspace list 2>/dev/null | jq -r '
    .result.workspaces[]
    | [ .workspace_id,
        "\(.number)  \(.label)   \(.tab_count)t \(.pane_count)p   \(.agent_status)\(if .focused then "  ●" else "" end)"
      ] | @tsv'
}

preview() {                                   # $1 = workspace id
  herdr workspace list 2>/dev/null | jq -r --arg n "$1" '
    .result.workspaces[] | select(.workspace_id==$n)
    | "workspace: \(.label)\nid:        \(.workspace_id)\nnumber:    \(.number)\ntabs:      \(.tab_count)\npanes:     \(.pane_count)\nagent:     \(.agent_status)\nfocused:   \(.focused)"'
}

ask() {                                       # $1 prompt, $2 default -> echoes answer
  # Bind stdin AND the UI explicitly to the controlling tty; inside fzf's
  # become() the inherited stdin is not a usable tty, which silently breaks
  # gum/read and made "new" appear to do nothing.
  if command -v gum >/dev/null 2>&1; then
    gum input --prompt "$1 " --value "${2:-}" 0</dev/tty 2>/dev/tty || true
  else
    printf '%s ' "$1" >/dev/tty
    local a; IFS= read -r a </dev/tty || true; printf '%s' "$a"
  fi
}

case "${1:-}" in
  --render)  render; exit 0 ;;
  --preview) preview "${2:-}"; exit 0 ;;

  --new)
    name="$(ask 'new workspace label:' '')"
    if [ -n "${name// /}" ]; then
      if err="$(herdr workspace create --label "$name" --focus 2>&1)"; then
        exit 0                                # --focus already switched us there
      fi
      printf 'create failed:\n%s\n(press enter)\n' "$err" >/dev/tty
      read -r _ </dev/tty || true
    fi
    exec "$self" ;;

  --delete)
    id="${2:-}"
    # Refuse to delete the workspace this switcher pane lives in (would kill us).
    if [ -z "$id" ] || [ "$id" = "${HERDR_WORKSPACE_ID:-}" ]; then
      echo "cannot close the current workspace from here"; sleep 1
    else
      herdr workspace close "$id" >/dev/null 2>&1 || true
    fi
    exec "$self" ;;

  --rename)
    id="${2:-}"
    [ -z "$id" ] && exec "$self"
    old="$(herdr workspace list 2>/dev/null | jq -r --arg n "$id" '.result.workspaces[]|select(.workspace_id==$n)|.label')"
    new="$(ask "rename '$old' to:" "$old")"
    [ -n "${new// /}" ] && [ "$new" != "$old" ] && \
      herdr workspace rename "$id" "$new" >/dev/null 2>&1 || true
    exec "$self" ;;
esac

# ---- interactive picker (search off by default, j/k navigate) ----
# Live mode (WS_LIVE=1, set by the popup plugin): moving the cursor switches the
# workspace underneath in real time via fzf's `focus` event; Esc/q restores the
# workspace we started on. Pane mode leaves this OFF — switching away would hide
# the switcher pane itself.
live_binds=()
origin=""
if [ "${WS_LIVE:-}" = 1 ]; then
  origin="$(herdr workspace list 2>/dev/null | jq -r '.result.workspaces[]|select(.focused)|.workspace_id' | head -1)"
  live_binds+=(--bind 'focus:execute-silent(herdr workspace focus {1})')
fi

sel="$(render | fzf \
  --delimiter='\t' --with-nth='2..' \
  --prompt='workspace ❯ ' --pointer='➤' \
  --reverse --cycle --height='100%' --border=rounded \
  --disabled --info=hidden \
  --header='j/k: switch live   Enter: keep   n: new   x: delete   r: rename   /: search   q: cancel' \
  --preview "$self --preview {1}" --preview-window='right,45%,border-left,wrap' \
  "${live_binds[@]}" \
  --bind 'j:down' --bind 'k:up' \
  --bind 'ctrl-j:down' --bind 'ctrl-k:up' \
  --bind 'ctrl-n:down' --bind 'ctrl-p:up' \
  --bind 'left-click:accept' --bind 'q:abort' \
  --bind 'change:clear-query' \
  --bind '/:transform:[[ {fzf:prompt} =~ ❯ ]] && echo "enable-search+unbind(j,k,change)+change-prompt(search> )" || echo "disable-search+clear-query+rebind(j,k,change)+change-prompt(workspace ❯ )"' \
  --bind "ctrl-r:reload($self --render)" \
  --bind "n:become($self --new)" \
  --bind "x:become($self --delete {1})" \
  --bind "r:become($self --rename {1})" \
)" || {
  # Cancelled: in live mode we've been switching as we navigated — go back.
  [ -n "$origin" ] && herdr workspace focus "$origin"
  exit 0
}

id="${sel%%$'\t'*}"
[ -n "$id" ] && herdr workspace focus "$id"
