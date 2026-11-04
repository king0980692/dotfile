#!/usr/bin/env bash
# scp-back.sh <path>... — print the scp command that pulls <path>s back to the
# machine the current ssh session came from. Used by the yazi `scp-back` plugin,
# which puts the result on that machine's clipboard via OSC 52.
#
# No per-client setup: the target is read from SSH_CONNECTION
# ("client_ip client_port server_ip server_port"). server_ip:server_port is the
# address the client itself used to reach this box, so it can scp back through
# it — over Tailscale that is this machine's 100.x address, from the Windows
# host it is 127.0.0.1 (WSL localhost forwarding). It would only be wrong behind
# a NAT port-proxy, which is not how anyone connects here.
#
# Exits 1 with no output when there is no ssh session to send back to.

set -u

# Inside herdr (or tmux) a pane inherits the *server's* environment, captured
# when the server started, so a later ssh login never shows up in it. The
# attached client holds the real terminal, so read SSH_CONNECTION from that.
# With several ssh clients attached, take the most recently started one.
origin() {
  if [ -n "${SSH_CONNECTION:-}" ]; then
    printf '%s\n' "$SSH_CONNECTION"
    return 0
  fi
  local p conn start best='' best_start=-1
  for p in $(pgrep -x herdr 2>/dev/null) $(pgrep -x tmux 2>/dev/null); do
    conn=$(tr '\0' '\n' <"/proc/$p/environ" 2>/dev/null | sed -n 's/^SSH_CONNECTION=//p')
    [ -n "$conn" ] || continue
    start=$(awk '{print $22}' "/proc/$p/stat" 2>/dev/null) || continue # starttime
    if [ "${start:-0}" -gt "$best_start" ]; then
      best_start=$start
      best=$conn
    fi
  done
  [ -n "$best" ] && printf '%s\n' "$best"
}

# Single-quote for the shell the command gets pasted into ('\'' for a quote).
q() {
  local s=$1
  s=${s//\'/\'\\\'\'}
  printf "'%s'" "$s"
}

[ $# -gt 0 ] || exit 1
conn=$(origin) && [ -n "$conn" ] || exit 1
read -r _ _ host port _ <<<"$conn"
[ -n "${host:-}" ] || exit 1
case $host in *:*) host="[$host]" ;; esac # IPv6 needs brackets in scp targets

cmd="scp -r"
[ "${port:-22}" = 22 ] || cmd+=" -P $port"
for f in "$@"; do
  cmd+=" ${USER}@${host}:$(q "$(realpath -- "$f")")"
done
printf '%s .\n' "$cmd"
