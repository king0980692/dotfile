#!/bin/sh
# Toggle macOS system appearance between Dark and Light.
# Bound to physical cmd+F3 via karabiner (option+F3 rule) and alt-f3 in skhdrc.

osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to not dark mode'
