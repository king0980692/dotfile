#!/bin/bash
# Delete a tmux session with confirmation using gum

session_name="$1"

if [ -z "$session_name" ]; then
  exit 1
fi

if gum confirm "Delete session '$session_name'?"; then
  tmux kill-session -t "$session_name" 2>/dev/null
fi
