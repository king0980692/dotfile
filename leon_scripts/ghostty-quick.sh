#!/bin/sh
# ghostty-quick.sh <goto|lazygit|pi-bolt> [--toggle] — prepare Ghostty's (single) quick terminal
# for a mode. Without --toggle it does NOT show it; the caller sends f19, which
# Ghostty binds (global) to toggle_quick_terminal:
#   cmd+s in Ghostty -> Karabiner rule: this script, 30ms, f19 (fast path)
#   M-s in herdr-native (fallback when Karabiner is off): this script --toggle,
#   which sends f19 itself via osascript (~130-270ms).
# alt+space stays Ghostty's own global toggle (-> pi-bolt, the default mode).
#
# The mode reaches the new shell via $STATE/next ("<epoch> <mode>", read and
# removed by bash/.bashrc, ignored when older than 3s). The shell records
# $STATE/running ("<pid> <mode>"). A hidden quick terminal keeps its process,
# so one still alive in the *other* mode is killed here; otherwise the toggle
# would just re-show it. Same mode -> the toggle shows / hides it as usual.
mode=${1:-goto}
state="$HOME/.cache/ghostty-quick"
mkdir -p "$state"
printf '%s %s\n' "$(date +%s)" "$mode" > "$state/next"

if [ -r "$state/running" ] && read -r pid cur < "$state/running" &&
    [ "$cur" != "$mode" ] && kill -0 "$pid" 2>/dev/null; then
    pkill -TERM -P "$pid" 2>/dev/null
    kill -TERM "$pid" 2>/dev/null
    killed=1
fi

# --toggle: also send F19 here (no separate sleep/osascript in the caller).
# Only wait when an old-mode quick terminal was just killed, so it can close.
# (A CGEvent-posted F19 was not picked up by Ghostty's global:f19; Karabiner's
# virtual keyboard is, hence the Karabiner rule for the fast path.)
if [ "${2-}" = --toggle ]; then
    [ -n "${killed-}" ] && sleep 0.05
    osascript -e 'tell application "System Events" to key code 80'
fi
