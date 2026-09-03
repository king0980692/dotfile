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

set -eu

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

dark_mode() {
    osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode'
}

if [ "${1:-}" != "--sync" ]; then
    osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to not dark mode'
fi

case "$(dark_mode)" in
    true) variant=dark ;;
    *)    variant=light ;;
esac

src="$CONFIG_DIR/alacritty/themes/$variant.toml"
[ -f "$src" ] && cp "$src" "$CONFIG_DIR/alacritty/theme.toml"
