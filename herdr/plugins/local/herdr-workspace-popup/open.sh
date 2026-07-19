#!/usr/bin/env bash
# Summon the workspace switcher as a floating popup pane. Invoked by the
# plugin action `open-workspace-popup` (bound to M-s in herdr config.toml).
set -uo pipefail
herdr_bin="${HERDR_BIN_PATH:-herdr}"
exec "$herdr_bin" plugin pane open \
  --plugin herdr-workspace-popup \
  --entrypoint workspace-switcher \
  --placement popup \
  --width 50% \
  --height 50% \
  --focus
