#!/usr/bin/env bash
# herdr SESSION switcher/manager (fzf), mirroring your tmux_session_switcher.sh.
#
# herdr sessions are separate server instances, so:
#   * switching is NOT in-place — it means "attach that session" (the outer
#     loop in herdr_sessions.sh does the attach; this script just prints the
#     chosen name on stdout).
#   * this script must run OUTSIDE herdr (nested herdr is disabled), i.e. from
#     the detach-loop launcher.
#
# Contract: print the session name to attach on stdout, or nothing to quit.
# Keys:  Enter/Click = switch   n = new   x = delete   r = rename   q/Esc = quit
set -euo pipefail

self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

list() {
  herdr session list --json 2>/dev/null | jq -r '
    .sessions[]
    | [ .name,
        "\(.name)   \(if .running then "● running" else "○ stopped" end)\(if .default then "   (default)" else "" end)"
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
  # Bind stdin AND the UI explicitly to the controlling tty; inside fzf's
  # become() the inherited stdin is not a usable tty, which silently breaks
  # gum/read and made "new" (and rename) appear to do nothing.
  if command -v gum >/dev/null 2>&1; then
    gum input --prompt "$1 " --value "${2:-}" 0</dev/tty 2>/dev/tty || true
  else
    printf '%s ' "$1" >/dev/tty
    local a; IFS= read -r a </dev/tty || true; printf '%s' "$a"
  fi
}

case "${1:-}" in
  --list)    list; exit 0 ;;
  --preview) preview "${2:-}"; exit 0 ;;

  --new)
    name="$(ask 'new session name:' '')"
    [ -n "${name// /}" ] && printf '%s\n' "$name"      # -> outer loop attaches it
    exit 0 ;;

  --delete)
    name="${2:-}"
    if [ "$name" = "default" ] || [ -z "$name" ]; then
      echo "cannot delete '$name'"; sleep 1
    else
      herdr session stop   "$name" >/dev/null 2>&1 || true
      herdr session delete "$name" >/dev/null 2>&1 || true
    fi
    exec "$self" ;;                                     # reload the switcher

  --rename)
    old="${2:-}"
    if [ "$old" = "default" ] || [ -z "$old" ]; then
      echo "cannot rename '$old'"; sleep 1; exec "$self"
    fi
    new="$(ask "rename '$old' to:" "$old")"
    if [ -z "${new// /}" ] || [ "$new" = "$old" ]; then exec "$self"; fi
    # No native rename API -> best-effort: move the session's state directory
    # while stopped. Self-guards: only if <parent>/<oldname> is the real layout.
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
    exec "$self" ;;
esac

# ---- interactive picker (search disabled, j/k navigate, like your tmux one) ----
sel="$(list | fzf \
  --delimiter='\t' --with-nth='2..' \
  --prompt='session ❯ ' --pointer='➤' \
  --reverse --cycle --height='100%' --border=rounded \
  --disabled --info=hidden \
  --header='Enter/Click: switch   n: new   x: delete   r: rename   /: search   q: quit' \
  --preview "$self --preview {1}" --preview-window='right,55%,wrap' \
  --bind 'j:down' --bind 'k:up' \
  --bind 'ctrl-j:down' --bind 'ctrl-k:up' \
  --bind 'ctrl-n:down' --bind 'ctrl-p:up' \
  --bind 'left-click:accept' --bind 'q:abort' \
  --bind 'change:clear-query' \
  --bind '/:transform:[[ {fzf:prompt} =~ ❯ ]] && echo "enable-search+unbind(j,k,change)+change-prompt(search> )" || echo "disable-search+clear-query+rebind(j,k,change)+change-prompt(session ❯ )"' \
  --bind "n:become($self --new)" \
  --bind "x:become($self --delete {1})" \
  --bind "r:become($self --rename {1})" \
)" || exit 0

name="${sel%%$'\t'*}"
[ -n "$name" ] && printf '%s\n' "$name"
