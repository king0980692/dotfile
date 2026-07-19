#!/usr/bin/env bash
# herdr in-session SESSION housekeeping popup (bound to M-s, type = "popup").
#
# herdr disables nested herdr, so from INSIDE a running session you can NOT
# create or switch/attach sessions — those only work OUTSIDE herdr via the
# detach-loop (prefix+d to exit, then `ha`). What DOES work here are pure
# CLI/socket operations on OTHER sessions:
#
#   list   : herdr session list --json
#   stop   : herdr session stop   <name>     (running, not the current one)
#   delete : herdr session delete <name>     (not default / not current)
#   rename : stop + mv <dir> (no native API)  (not default / not current)
#
# The session you're attached to is detected via $HERDR_SOCKET_PATH and is
# protected from stop/delete/rename (doing so would kill this popup).
#
# Keys:  s: stop   x: delete   r: rename   /: search   q/Esc: quit
set -euo pipefail

self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# Name of the session this popup lives in (match by socket path).
current_session() {
  herdr session list --json 2>/dev/null \
    | jq -r --arg s "${HERDR_SOCKET_PATH:-}" '.sessions[]|select(.socket_path==$s)|.name' \
    | head -1
}

render() {
  local cur; cur="$(current_session)"
  herdr session list --json 2>/dev/null | jq -r --arg cur "$cur" '
    .sessions[]
    | [ .name,
        "\(.name)   \(if .running then "● running" else "○ stopped" end)\(if .default then "   (default)" else "" end)\(if .name==$cur then "   ← current" else "" end)"
      ] | @tsv'
}

preview() {                                   # $1 = session name
  local dir
  dir="$(herdr session list --json 2>/dev/null \
         | jq -r --arg n "$1" '.sessions[]|select(.name==$n)|.session_dir')"
  echo "session: $1"
  echo "dir:     $dir"
  echo
  if [ -f "$dir/session.json" ]; then
    echo "workspaces:"
    jq -r '.workspaces[] | "  ▸ \(.custom_name // .identity_cwd)   (\(.tabs|length) tab(s))"' \
       "$dir/session.json" 2>/dev/null || echo "  (unreadable snapshot)"
  else
    echo "(no session.json snapshot yet)"
  fi
}

ask() {                                       # $1 = prompt, $2 = default; echoes answer
  if command -v gum >/dev/null 2>&1; then
    gum input --prompt "$1 " --value "${2:-}" 0</dev/tty 2>/dev/tty || true
  else
    local a; read -r -p "$1 " -e -i "${2:-}" a </dev/tty || true; echo "$a"
  fi
}

# Refuse operations on the current or default session. $1 = name, $2 = verb.
guard() {
  local name="$1" verb="$2" cur; cur="$(current_session)"
  if [ -z "$name" ]; then echo "no session selected"; sleep 1; return 1; fi
  if [ "$name" = "$cur" ]; then
    echo "cannot $verb the CURRENT session ($name) from inside it"; sleep 1.5; return 1
  fi
  if [ "$name" = "default" ]; then
    echo "cannot $verb the default session"; sleep 1.5; return 1
  fi
  return 0
}

case "${1:-}" in
  --render)  render; exit 0 ;;
  --preview) preview "${2:-}"; exit 0 ;;

  --stop)
    name="${2:-}"; cur="$(current_session)"
    if [ -z "$name" ]; then echo "no session selected"; sleep 1
    elif [ "$name" = "$cur" ]; then echo "cannot stop the CURRENT session"; sleep 1.5
    else herdr session stop "$name" >/dev/null 2>&1 || { echo "stop failed"; sleep 1; }
    fi
    exec "$self" ;;

  --delete)
    name="${2:-}"
    if guard "$name" "delete"; then
      herdr session stop   "$name" >/dev/null 2>&1 || true
      herdr session delete "$name" >/dev/null 2>&1 || { echo "delete failed"; sleep 1; }
    fi
    exec "$self" ;;

  --rename)
    old="${2:-}"
    guard "$old" "rename" || exec "$self"
    new="$(ask "rename '$old' to:" "$old")"
    if [ -z "${new// /}" ] || [ "$new" = "$old" ]; then exec "$self"; fi
    info="$(herdr session list --json 2>/dev/null)"
    dir="$(jq -r --arg n "$old" '.sessions[]|select(.name==$n)|.session_dir' <<<"$info")"
    run="$(jq -r --arg n "$old" '.sessions[]|select(.name==$n)|.running'     <<<"$info")"
    [ "$run" = "true" ] && herdr session stop "$old" >/dev/null 2>&1 || true
    parent="$(dirname "$dir")"; base="$(basename "$dir")"
    if [ "$base" = "$old" ] && [ -n "$dir" ] && [ ! -e "$parent/$new" ]; then
      mv "$dir" "$parent/$new" && echo "renamed -> $new" || echo "rename failed"
    else
      echo "rename unsupported for this layout (dir='$dir'); skipped"; sleep 2
    fi
    sleep 0.5
    exec "$self" ;;
esac

# ---- interactive picker (search off by default, j/k navigate) ----
render | fzf \
  --delimiter='\t' --with-nth='2..' \
  --prompt='session ❯ ' --pointer='➤' \
  --reverse --cycle --height='100%' --border=rounded \
  --disabled --info=hidden \
  --header='s: stop   x: delete   r: rename   /: search   q: quit   (new/switch: prefix+d -> ha)' \
  --preview "$self --preview {1}" --preview-window='right,55%,wrap' \
  --bind 'j:down' --bind 'k:up' \
  --bind 'ctrl-j:down' --bind 'ctrl-k:up' \
  --bind 'ctrl-n:down' --bind 'ctrl-p:up' \
  --bind 'q:abort' \
  --bind 'change:clear-query' \
  --bind '/:transform:[[ {fzf:prompt} =~ ❯ ]] && echo "enable-search+unbind(j,k,change)+change-prompt(search> )" || echo "disable-search+clear-query+rebind(j,k,change)+change-prompt(session ❯ )"' \
  --bind "s:become($self --stop {1})" \
  --bind "x:become($self --delete {1})" \
  --bind "r:become($self --rename {1})" \
  >/dev/null 2>&1 || true
