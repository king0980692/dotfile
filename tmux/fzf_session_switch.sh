#!/bin/bash

# Session switcher in a persistent popup window
# Displays list of available tmux sessions and switches to selected one

# Use fzf to select a session
selected_session=$(tmux list-sessions -F '#{session_name}' | fzf --preview 'tmux capture-pane -t {} -p' --preview-window=right:50%)

# If a session was selected, switch to it in the parent client
if [ -n "$selected_session" ]; then
    if [ -n "$PARENT_CLIENT" ]; then
        tmux switch-client -t "$selected_session" -c "$PARENT_CLIENT"
    else
        tmux switch-client -t "$selected_session"
    fi
fi

# Keep the popup window open for further interactions
# User can press M-a again to open a new selector, or use other tmux commands
bash
