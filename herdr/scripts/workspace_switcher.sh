#!/usr/bin/env bash
# WORKSPACE switcher + manager for herdr — the analog of the tmux session
# switcher. Runs inside herdr as a [[keys.command]] (M-s uses type="popup");
# every action is a socket-API call to the SAME server, not a nested herdr.
#
#   list  : herdr workspace list
#   switch: herdr workspace focus  <id>
#   new   : herdr workspace create --label <name> --focus
#   delete: herdr workspace close  <id>
#   rename: herdr workspace rename <id> <label>
#
#   Enter / click   switch and close the popup
#   C-n C-j / ↓     down          C-p C-k / ↑   up
#   M-n new · M-x delete · M-r rename · C-r reload · Esc/C-c cancel
#
# Switching happens ONLY on Enter. An earlier version previewed by focusing the
# workspace under the cursor via fzf's `focus` event, but that event also fires
# when filtering changes which line is selected — so every keystroke switched
# workspace. Moving the cursor now only moves the cursor.
set -euo pipefail

self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

for dep in herdr jq fzf; do
  command -v "$dep" >/dev/null 2>&1 || { echo "workspace_switcher: missing $dep" >&2; exit 1; }
done

ws_list() { herdr workspace list 2>/dev/null; }

# Where to return to when the picker is cancelled. Captured once and carried
# across the re-execs that new/delete/rename do (become() replaces this
# process), because live preview will have moved the focus away by then.
if [ -z "${WS_ORIGIN:-}" ]; then
  WS_ORIGIN="$(herdr workspace list 2>/dev/null | jq -r '.result.workspaces[]|select(.focused)|.workspace_id' | head -1)"
  export WS_ORIGIN
fi

# Most-recently-used ordering. herdr itself has no notion of it: workspace list
# carries no timestamp and always comes back in `number` order, and
# agent_panel_sort only takes "spaces"/"priority". So keep our own log.
# It is stamped on every switch, on every launch of this switcher, and by the
# leon.ws-recency plugin whenever you dwell in a workspace however you got
# there (M-[ / M-], prefix+N, the sidebar).
RECENCY="${XDG_CACHE_HOME:-$HOME/.cache}/herdr/workspace-recency"
# "<workspace id> <epoch>" of the last agent status change, written by the same
# plugin (pane.agent_status_changed), for the LAST column. Visits are left out
# on purpose: they already drive the MRU order, and counting them made an
# agent idle for hours read "now" just because you looked at it.
ACTIVITY="${XDG_CACHE_HOME:-$HOME/.cache}/herdr/workspace-activity"

touch_ws() {                                  # $1 = workspace id -> active now
  [ -n "${1:-}" ] || return 0
  mkdir -p "${ACTIVITY%/*}" 2>/dev/null || return 0
  local tmp
  tmp="$(mktemp "${ACTIVITY}.XXXXXX")" || return 0
  { printf '%s %s\n' "$1" "$(date +%s)"
    [ -f "$ACTIVITY" ] && awk -v id="$1" '$1 != id' "$ACTIVITY"; true; } \
    | head -200 >"$tmp" 2>/dev/null || true
  mv -f "$tmp" "$ACTIVITY" 2>/dev/null || rm -f "$tmp"
}

stamp() {                                     # $1 = workspace id -> most recent
  [ -n "${1:-}" ] || return 0
  mkdir -p "${RECENCY%/*}" 2>/dev/null || return 0
  local tmp
  tmp="$(mktemp "${RECENCY}.XXXXXX")" || return 0
  # The trailing `true` matters: on the first run there is no file yet, so the
  # `[ -f ] &&` leaves the group with a non-zero status, and under `set -e` with
  # pipefail that killed the whole switcher before fzf ever started.
  { printf '%s\n' "$1"; [ -f "$RECENCY" ] && grep -vxF -- "$1" "$RECENCY"; true; } \
    | head -200 >"$tmp" 2>/dev/null || true
  mv -f "$tmp" "$RECENCY" 2>/dev/null || rm -f "$tmp"
}

render() {                                    # $1 = label width, $2 = task width
  local w=${1:-22} tw=${2:-30} tmp
  # Every agent in the workspace, ordered blocked > working > done > rest, so
  # the list can show one glyph per agent instead of just the busiest one.
  tmp="$(mktemp)" || return 0
  # The task text prefers what the agent (or a user hook) reported through
  # `herdr pane report-metadata`: --display-agent replaces the name, and a
  # --state-label for the current state / --title beat the terminal title.
  # Truncated here rather than in awk: mawk counts bytes, which cut CJK text
  # mid-character. Wide (CJK / fullwidth) characters count as two cells.
  herdr agent list 2>/dev/null | jq -r --argjson tw "$tw" '
    def cells: if (. >= 4352 and . <= 4447) or (. >= 11904 and . <= 42191)
                  or (. >= 44032 and . <= 55203) or (. >= 63744 and . <= 64255)
                  or (. >= 65280 and . <= 65376) or (. >= 65504 and . <= 65510)
               then 2 else 1 end;
    def fit($n): explode as $c
      | if ($c | map(cells) | add // 0) <= $n then .
        else reduce $c[] as $x ({out: [], w: 0};
               if .w + ($x | cells) <= $n - 1 then .out += [$x] | .w += ($x | cells) else . end)
             | (.out | implode) + "…" end;
    .result.agents[]
    | [ .workspace_id,
        (if .agent_status=="blocked" then 0 elif .agent_status=="working" then 1
          elif .agent_status=="done" then 2 else 3 end),
        .agent_status,
        ({"claude": "C", "codex": "X", "pi": "π", "omp": "Ω", "opencode": "O"}[.agent]
         // (.agent // "?" | .[0:1] | ascii_upcase)),
        ("\(.display_agent // .agent)  \(.state_labels[.agent_status] // .title // .terminal_title_stripped // "")"
         | gsub("[\t\n]"; " ") | fit($tw)) ] | @tsv' \
    | sort -t"$(printf '\t')" -k1,1 -k2,2n >"$tmp"

  # Order: workspaces that need you (blocked = waiting for your input, then
  # done) on top, everything else most-recently-used. While the picker is open
  # WS_ORDER freezes the order it opened with, so the 2s status refresh never
  # moves a row out from under the cursor.
  ws_list | jq -r '
    .result.workspaces[]
    | [ .workspace_id, .number, .label, .tab_count, .pane_count, (.focused|tostring),
        (.agent_status // "") ]
    | @tsv' \
  | awk -F'\t' -v rec="$RECENCY" -v act="$ACTIVITY" -v frozen="${WS_ORDER:-}" \
        -v now="$(date +%s)" -v w="$w" -v tw="$tw" -v agents="$tmp" '
      BEGIN {
        n = 0; while ((getline id < rec) > 0) if (!(id in rank)) rank[id] = ++n
        f = 0; if (frozen != "") while ((getline id < frozen) > 0) if (!(id in fixed)) fixed[id] = ++f
        while ((getline line < act) > 0) { split(line, a, " "); if (!(a[1] in seen)) { seen[a[1]] = a[2] } }
        while ((getline line < agents) > 0) {
          # One letter per agent (C claude, X codex, π pi, Ω omp, O opencode),
          # coloured by its state, so every agent in the workspace shows.
          split(line, a, "\t")
          st = a[3]
          col = (st == "blocked") ? "1;7;31" : (st == "working") ? "1;32" \
              : (st == "done")    ? "1;36"   : "2"
          strip[a[1]] = strip[a[1]] "\033[" col "m" a[4] "\033[0m"; count[a[1]]++
          if (!(a[1] in task)) task[a[1]] = a[5]      # highest priority wins
        }
      }
      function pad(id,   s, k) {                      # glyphs are multi-byte; pad by cells
        s = strip[id]; for (k = count[id]; k < 5; k++) s = s " "
        return s
      }
      function age(id,   d) {
        if (!(id in seen)) return ""
        d = now - seen[id]
        return d < 60 ? "now" : d < 3600 ? int(d / 60) "m" : d < 86400 ? int(d / 3600) "h" : int(d / 86400) "d"
      }
      {
        t = task[$1]
        # Workspace rollup state as a word, so it reads at a glance; one waiting
        # for you also gets its label in red.
        st = $7; name = "\033[1m"; group = 2
        if (st == "blocked")      { badge = "\033[1;7;31m! WAIT \033[0m"; name = "\033[1;31m"; group = 0 }
        else if (st == "done")    { badge = "\033[1;36m✓ done \033[0m"; group = 1 }
        else if (st == "working") badge = "\033[32m▶ run  \033[0m"
        else if (st == "idle")    badge = "\033[2m· idle \033[0m"
        else                      badge = "       "
        line = sprintf("\033[2m%3d\033[0m %s %s%-*.*s\033[0m \033[2m%4s\033[0m %s \033[2m%s\033[0m",
                       $2, badge, name, w, w, $3, age($1), pad($1), t)
        # Never-visited workspaces keep herdr number order, after the known ones.
        pos = ($1 in rank) ? rank[$1] : n + 1 + $2
        if (frozen != "") key = ($1 in fixed) ? fixed[$1] : f + 1 + $2   # new ones go last
        else              key = group * 100000 + pos
        printf "%09d\t%s\t%s\n", key, $1, line
      }' | sort -n | cut -f2-
  rm -f "$tmp"
}

header() {                                    # $1 = label width
  printf 'HDR\t\033[2m%3s %-7s %-*s %4s %-5s %s\033[0m\n' \
    '#' 'STATE' "${1:-22}" 'WORKSPACE' 'LAST' 'AGENTS' 'TASK'
}

summary() {                                   # " 1 waiting · 2 done · 1 running · 20 idle "
  ws_list | jq -r '
    [.result.workspaces[].agent_status] as $s
    | [ ["blocked", "waiting"], ["done", "done"], ["working", "running"], ["idle", "idle"] ]
    | map(. as [$k, $name] | ($s | map(select(. == $k)) | length) as $c
          | select($c > 0) | "\($c) \($name)")
    | " " + (if length > 0 then join(" · ") else "no agents" end) + " "'
}

# Tab preview: where the workspace is, what every agent in it is doing, and
# the latest output of the agent that most needs you.
preview() {                                   # $1 = workspace id
  local id=${1:-} panes agents ws cwd branch pane
  [ -n "$id" ] || return 0
  ws="$(ws_list | jq -c --arg id "$id" '.result.workspaces[] | select(.workspace_id == $id)')"
  panes="$(herdr pane list 2>/dev/null | jq -c --arg id "$id" '[.result.panes[] | select(.workspace_id == $id)]')"
  agents="$(herdr agent list 2>/dev/null | jq -c --arg id "$id" '[.result.agents[] | select(.workspace_id == $id)]
    | sort_by(if .agent_status=="blocked" then 0 elif .agent_status=="done" then 1
              elif .agent_status=="working" then 2 else 3 end)')"
  # The workspace's folder: its focused non-sidebar pane, else any pane.
  cwd="$(jq -r '(map(select(.focused and (.label // "") != "Sidebar")) + .)[0]
                | .foreground_cwd // .cwd // empty' <<<"$panes")"
  branch="$(git -C "$cwd" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null || true)"

  jq -r '"\u001b[1m\(.label)\u001b[0m  \u001b[2m#\(.number) · \(.tab_count) tabs · \(.pane_count) panes\u001b[0m"' <<<"$ws"
  printf '\033[2m%s\033[0m' "${cwd/#$HOME/\~}"
  [ -n "$branch" ] && printf '  \033[35m %s\033[0m' "$branch"
  printf '\n\n'
  jq -r '.[] | (if .agent_status=="blocked" then "\u001b[31m! wait\u001b[0m"
                elif .agent_status=="done" then "\u001b[36m✓ done\u001b[0m"
                elif .agent_status=="working" then "\u001b[32m▶ run \u001b[0m"
                else "\u001b[2m· \(.agent_status)\u001b[0m" end)
              + "  \u001b[1m\(.display_agent // .agent)\u001b[0m  \(.state_labels[.agent_status] // .title // .terminal_title_stripped // "")"' \
    <<<"$agents"

  pane="$(jq -r '.[0].pane_id // empty' <<<"$agents")"
  if [ -n "$pane" ]; then
    if [ -n "$(attention_pane "$id")" ]; then
      printf '\n\033[2m── latest output · %s · \033[0;1mEnter jumps here\033[0;2m ──\033[0m\n' "$pane"
    else
      printf '\n\033[2m── latest output · %s ──\033[0m\n' "$pane"
    fi
    herdr pane read "$pane" --source recent --lines "${FZF_PREVIEW_LINES:-30}" --format ansi 2>/dev/null \
      | tail -n "$(( ${FZF_PREVIEW_LINES:-30} - $(jq length <<<"$agents") - 5 ))"
  fi
}

# Exiting does not take the floating popup with it, so close it explicitly.
# There is no CLI for this; popup.close is socket-only and answers
# "popup_not_open" when the switcher was started in a plain pane instead.
close_popup() {
  [ -n "${HERDR_SOCKET_PATH:-}" ] || return 0
  python3 - <<'PY' >/dev/null 2>&1 || true
import json, os, socket
s = socket.socket(socket.AF_UNIX); s.settimeout(2)
s.connect(os.environ["HERDR_SOCKET_PATH"])
s.sendall(json.dumps({"id": "ws-switcher", "method": "popup.close", "params": {}}).encode() + b"\n")
s.recv(4096)
PY
}

# The pane that needs you in a workspace: its first waiting (blocked) agent,
# else a finished one you have not looked at yet (done = unseen in herdr).
attention_pane() {                            # $1 = workspace id -> pane id or ""
  herdr agent list 2>/dev/null | jq -r --arg id "$1" '
    [.result.agents[] | select(.workspace_id == $id)
     | select(.agent_status == "blocked" or .agent_status == "done")]
    | sort_by(if .agent_status == "blocked" then 0 else 1 end) | .[0].pane_id // empty'
}

# Enter lands on the pane that needs you, not just the workspace: `agent
# focus` switches workspace and tab too, and marks a done agent as seen so it
# leaves the attention block.
switch_to() {                                 # $1 = workspace id
  [ -n "${1:-}" ] || return 0
  local pane
  pane="$(attention_pane "$1")"
  if [ -z "$pane" ] || ! herdr agent focus "$pane" >/dev/null 2>&1; then
    herdr workspace focus "$1" >/dev/null 2>&1 || true
  fi
  stamp "$1"
  close_popup
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
  --render)  render "${2:-22}" "${3:-30}"; exit 0 ;;

  # Called by the leon.ws-recency plugin on workspace.focused, so a workspace
  # reached any way at all (M-[ / M-], prefix+N, the sidebar) counts as used.
  --stamp)   stamp "${2:-}"; exit 0 ;;
  --touch)   touch_ws "${2:-}"; exit 0 ;;    # pane.agent_status_changed, same plugin
  --summary) summary; exit 0 ;;
  --preview) preview "${2:-}"; exit 0 ;;
  # ^R: re-sort now (attention + MRU) and freeze that as the new order.
  --reorder)
    out="$(WS_ORDER='' render "${2:-22}" "${3:-30}")"
    [ -n "${WS_ORDER:-}" ] && cut -f1 <<<"$out" >"$WS_ORDER"
    printf '%s\n' "$out"; exit 0 ;;

  --new)
    name="$(ask 'new workspace label:' '')"
    if [ -n "${name// /}" ]; then
      if err="$(herdr workspace create --label "$name" --cwd "$HOME" --focus 2>&1)"; then
        close_popup                           # --focus already switched us there
        exit 0
      fi
      printf 'create failed:\n%s\n(press enter)\n' "$err" >/dev/tty
      read -r _ </dev/tty || true
    fi
    exec "$self" ;;

  --delete)
    id="${2:-}"
    # Closing the workspace this switcher is running in would take it with it.
    if [ -z "$id" ]; then
      :
    elif [ "$id" = "${HERDR_WORKSPACE_ID:-}" ]; then
      printf 'refusing to close the workspace this switcher is running in\n(press enter)\n' >/dev/tty
      read -r _ </dev/tty || true
    else
      herdr workspace close "$id" >/dev/null 2>&1 || true
    fi
    exec "$self" ;;

  --rename)
    id="${2:-}"
    [ -z "$id" ] && exec "$self"
    old="$(ws_list | jq -r --arg n "$id" '.result.workspaces[]|select(.workspace_id==$n)|.label')"
    new="$(ask "rename '$old' to:" "$old")"
    if [ -n "${new// /}" ] && [ "$new" != "$old" ]; then
      herdr workspace rename "$id" "$new" >/dev/null 2>&1 || true
    fi
    exec "$self" ;;
esac

# ---- interactive picker -----------------------------------------------------
# Whatever is focused when the switcher opens became recent however you got
# there, so record it before rendering.
stamp "$(ws_list | jq -r '.result.workspaces[]|select(.focused)|.workspace_id' | head -1)"

# Layout in the same shape as the mise widget (leon_scripts/mise-search-fzf.sh):
# full style, labelled borders, column header inline in the list, keys in the
# footer, details in a right-hand preview. Colours are plain ANSI numbers so
# they follow the terminal's light/dark palette.
layout=(--style full --padding 1,2 --border-label ' workspace ')
label_w=22
read -r term_lines term_cols < <(stty size </dev/tty 2>/dev/null || echo "24 80")
task_w=$(( ${term_cols:-80} - label_w - 36 ))          # 其餘欄位與框線佔用
[ "$task_w" -lt 0 ] && task_w=0
if [ "${term_lines:-0}" -lt 20 ] || [ "${term_cols:-0}" -lt 80 ]; then
  layout=(--style full)                                # 太小就不留內距
  label_w=16; task_w=0
fi

# The cursor starts on the workspace you were in before (MRU #2), wherever the
# attention block put it, so Enter stays an alt-tab back to it.
# Live preview is OFF by default: the popup does not follow the workspace it
# switches to — it stays where it was opened — so previewing leaves you looking
# at a window that no longer belongs to the workspace under the cursor.
#
# It still works if you want it (WS_LIVE=1): switching is bound to the movement
# keys themselves, never to fzf's `focus` event, because that one also fires
# when filtering changes the selected line — which is what made every keystroke
# switch workspace. Opening never switches (pos() is not a movement) and
# cancelling restores WS_ORIGIN.
live_binds=()
if [ "${WS_LIVE:-0}" = 1 ]; then
  live='execute-silent(herdr workspace focus {1})'
  for pair in 'down:down' 'up:up' 'ctrl-j:down' 'ctrl-k:up' 'ctrl-n:down' 'ctrl-p:up' \
              'page-down:page-down' 'page-up:page-up' 'home:first' 'end:last' \
              'scroll-up:up' 'scroll-down:down'; do
    live_binds+=(--bind "${pair}+${live}")
  done
else
  live_binds=(--bind 'ctrl-j:down' --bind 'ctrl-k:up'
              --bind 'ctrl-n:down' --bind 'ctrl-p:up')
fi

# Sort once and freeze it (WS_ORDER) for this popup; ^R re-sorts on demand.
WS_ORDER="$(mktemp)"; export WS_ORDER
trap 'rm -f "$WS_ORDER"' EXIT
list="$("$self" --reorder "$label_w" "$task_w")"
prev="$(sed -n 2p "$RECENCY" 2>/dev/null || true)"
cur_pos="$(cut -f1 <<<"$list" | grep -nxF -- "${prev:-none}" | cut -d: -f1 || true)"
[ -n "$cur_pos" ] || cur_pos=1

# Statuses change while the picker is open, so refresh the list and the
# summary every 2s (order stays frozen). fzf exports FZF_PORT to its child
# processes; when fzf exits the POST fails and the loop ends with it.
refresh='while sleep 2; do curl -fs -XPOST "localhost:$FZF_PORT" -d "reload('"$self"' --render '"$label_w"' '"$task_w"')+transform-list-label('"$self"' --summary)" >/dev/null || break; done &'

sel="$( { header "$label_w"; printf '%s\n' "$list"; } | fzf \
  --delimiter='\t' --with-nth='2..' \
  --listen 0 --bind "start:pos($cur_pos)+execute-silent($refresh)" \
  --ansi --reverse --cycle --height='100%' --sync \
  "${layout[@]}" \
  --header-lines 1 --header-lines-border inline \
  --input-label ' 搜尋 ' --ghost 'workspace / agent / task' \
  --list-label "$(summary)" \
  --preview "$self --preview {1}" \
  --preview-window 'right,55%,hidden,nowrap,border-left' \
  --preview-label ' preview ' \
  --bind 'tab:toggle-preview' \
  --footer-border inline \
  --footer 'Enter 切換  Tab 預覽  ^N/^P 移動  ^R 重排  M-n 新增  M-r 改名  M-x 刪除  Esc' \
  --pointer='▶' --highlight-line \
  "${live_binds[@]}" \
  --bind 'left-click:accept' \
  --bind "ctrl-r:reload($self --reorder $label_w $task_w)+transform-list-label($self --summary)" \
  --bind "alt-n:become($self --new)" \
  --bind "alt-x:become($self --delete {1})" \
  --bind "alt-r:become($self --rename {1})" \
  --color 'border:8,label:6' \
  --color 'input-border:8,input-label:6,query:-1,ghost:8' \
  --color 'list-border:8,list-label:6,scrollbar:8' \
  --color 'footer-border:8,footer:8' \
  --color 'current-bg:8,pointer:6,gutter:-1,info:8' \
)" || {
  # Only live preview can have moved us; without it there is nothing to undo.
  if [ "${WS_LIVE:-0}" = 1 ] && [ -n "${WS_ORIGIN:-}" ]; then
    herdr workspace focus "$WS_ORIGIN" >/dev/null 2>&1
  fi
  close_popup
  exit 0
}

switch_to "${sel%%$'\t'*}"
