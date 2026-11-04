#!/usr/bin/env bash
# smart-open.sh — open paths with the handler that suits where the user is
# actually sitting, not where the files happen to live.
#
#   local WSL   -> hand it to Windows (explorer.exe + wslpath); file
#                  associations are Windows' problem
#   over ssh    -> stay inside the terminal (timg / $EDITOR / $PAGER); popping a
#                  window on the WSL host would open it on a machine nobody is
#                  looking at
#   plain linux -> xdg-open, detached
#
# Why not just test $SSH_CONNECTION: inside herdr (or tmux) a pane inherits the
# *server's* environment, captured when the server first started, so a later ssh
# login is completely invisible to it. Verified on this box: the herdr server's
# /proc/<pid>/environ has no SSH_* at all. The attached client process is the one
# holding the real terminal, so ask that instead.
#
# SMART_OPEN_DRY=1 prints the handler it would use and exits, for testing.

set -u

die() { printf 'smart-open: %s\n' "$*" >&2; exit 1; }
# yazi opens these with block=true; a handler that exits at once would flash by.
# Any single byte ends the wait, not a full line: yazi hands the tty over still
# in raw mode (-icrnl -icanon -echo, seen in stty -a from inside an opener), so
# Enter arrives as a bare \r and `read -r` would wait for a \n forever.
# Leftover bytes of a multi-byte key are drained after.
pause() {
  [ -t 0 ] || return 0
  printf '\n[press any key]'
  read -rsn1 _ || true
  while read -rsn1 -t 0.05 _; do :; done
  printf '\n'
}
dry() { [ -n "${SMART_OPEN_DRY:-}" ]; }
act() {
  if dry; then printf '%s\n' "$*"; return 0; fi
  return 1
}

is_wsl() {
  [ -n "${WSL_DISTRO_NAME:-}" ] && return 0
  grep -qi microsoft /proc/version 2>/dev/null
}

# Is the terminal we are being viewed through on the other end of an ssh hop?
is_remote() {
  [ -n "${SSH_CONNECTION:-}${SSH_CLIENT:-}" ] && return 0
  local p
  for p in $(pgrep -x herdr 2>/dev/null) $(pgrep -x tmux 2>/dev/null); do
    [ -r "/proc/$p/environ" ] || continue
    grep -qz '^SSH_CONNECTION=' "/proc/$p/environ" 2>/dev/null && return 0
  done
  return 1
}

win_open() {
  local target=$1 exp c
  # wslview (from wslu) honours the Windows default-app association and takes a
  # Linux path as-is. explorer.exe is the fallback: always present, but it is
  # really "show in File Explorer", so the association is less faithful.
  if command -v wslview >/dev/null 2>&1; then
    act "windows: wslview $target" && return 0
    wslview "$target" >/dev/null 2>&1
    return 0
  fi
  exp=$(command -v explorer.exe 2>/dev/null)
  if [ -z "$exp" ]; then
    # explorer.exe is only on PATH when the Windows PATH is inherited
    for c in /mnt/c/Windows/explorer.exe /mnt/c/WINDOWS/explorer.exe; do
      [ -x "$c" ] && exp=$c && break
    done
  fi
  [ -n "$exp" ] || die "explorer.exe not found"
  act "windows: $exp $target" && return 0
  "$exp" "$(wslpath -w "$target" 2>/dev/null || printf '%s' "$target")" >/dev/null 2>&1
  return 0 # explorer.exe exits nonzero even on success
}

term_open() {
  local f=$1 mime
  if [ -d "$f" ]; then
    act "terminal: show path $f" && return 0
    printf '%s\n' "$f"; pause; return 0
  fi
  mime=$(file -bL --mime-type -- "$f" 2>/dev/null)
  case $mime in
  image/*)
    command -v timg >/dev/null 2>&1 || die "no terminal image viewer (install timg)"
    act "terminal: timg $f" && return 0
    timg -- "$f"; pause
    # timg draws with kitty graphics here (herdr advertises it), and kitty images
    # are a layer above the text: yazi repainting its cells does not remove them,
    # so every `o` would stack another picture on the screen. Delete them all.
    printf '\e_Ga=d\e\\'
    ;;
  video/*|audio/*)
    command -v mpv >/dev/null 2>&1 || die "no terminal player for $mime (install mpv)"
    act "terminal: mpv $f" && return 0
    mpv --vo=tct -- "$f"
    ;;
  text/*|application/json|application/xml|application/javascript|inode/x-empty)
    act "terminal: ${EDITOR:-nvim} $f" && return 0
    "${EDITOR:-nvim}" -- "$f"
    ;;
  *)
    act "terminal: ${PAGER:-less} $f" && return 0
    "${PAGER:-less}" -- "$f"
    ;;
  esac
}

gui_open() {
  local f=$1
  command -v xdg-open >/dev/null 2>&1 || die "no xdg-open"
  act "xdg: $f" && return 0
  setsid xdg-open "$f" >/dev/null 2>&1 &
  return 0
}

[ $# -gt 0 ] || set -- .

for target in "$@"; do
  [ -e "$target" ] || die "no such path: $target"
  if is_remote; then
    term_open "$target"
  elif is_wsl; then
    win_open "$target"
  else
    gui_open "$target"
  fi
done
