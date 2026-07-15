#!/bin/bash
# Rename a tmux session using gum input

session_name="$1"

if [ -z "$session_name" ]; then
  exit 1
fi

new_name=$(gum input --value "$session_name" --char-limit 30)

if [ -n "$new_name" ] && [ "$new_name" != "$session_name" ]; then
  tmux rename-session -t "$session_name" "$new_name" 2>/dev/null
fi
