#!/bin/sh
# Toggle macOS system appearance (Dark <-> Light) and keep the terminals in sync.
#
#   toggle_theme.sh          flip the system appearance, then sync
#   toggle_theme.sh --sync   only sync to the current appearance (no flip)
#
# Ghostty needs no help: ghostty/config sets `theme = dark:...,light:...`, which
# it re-evaluates whenever the system appearance changes.
# Alacritty has no such setting, so we copy the matching palette over
# alacritty/theme.toml — alacritty.toml imports it and live-reloads on write.
#
# Bound to alt+F3 in karabiner (rule "option+F3 → toggle theme") and skhdrc.
# karabiner runs this from a daemon: HOME may be unset and PATH minimal, so
# default HOME and call the tools by absolute path. karabiner captures stderr
# into ~/.local/share/karabiner/log/console_user_server.log, so the trace below
# is what tells you whether a keypress reached the script at all.

set -eu

: "${HOME:=$(cd ~ 2>/dev/null && pwd)}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

echo "toggle_theme: invoked ($(/bin/date '+%H:%M:%S'))" >&2

dark_mode() {
    /usr/bin/osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode'
}

if [ "${1:-}" != "--sync" ]; then
    /usr/bin/osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to not dark mode'
fi

case "$(dark_mode)" in
    true) variant=dark ;;
    *)    variant=light ;;
esac

src="$CONFIG_DIR/alacritty/themes/$variant.toml"
if [ -f "$src" ]; then
    /bin/cp "$src" "$CONFIG_DIR/alacritty/theme.toml"
fi

echo "toggle_theme: now $variant" >&2
