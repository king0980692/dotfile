#!/usr/bin/env bash

set -eu

current_session="$(tmux display-message -p '#S')"
[ "$current_session" = "popup" ] || exit 0

source_pane="$(tmux display-message -p '#{pane_id}')"
pane_path="$(tmux display-message -p '#{pane_current_path}')"
window_name="$(tmux display-message -p '#W')"
session_windows="$(tmux display-message -p '#{session_windows}')"
window_panes="$(tmux display-message -p '#{window_panes}')"

default_name="$(basename "$(tmux display-message -p '#{pane_current_path}')")"
default_name="${default_name:-session}"
error_message=""

while :; do
    printf '\033[2J\033[H'
    printf 'Extract the current popup pane into a named tmux session.\n\n'

    if [ -n "$error_message" ]; then
        printf 'Error: %s\n\n' "$error_message"
    fi

    session_name="$(gum input --prompt 'Session name> ' --value "$default_name" --placeholder 'session-name')" || exit 0

    if [ -z "$session_name" ]; then
        error_message="Session name cannot be empty."
        continue
    fi

    if [ "$session_name" = "popup" ]; then
        error_message="Choose a name other than popup."
        continue
    fi

    if [[ ! "$session_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
        error_message="Use only letters, numbers, dot, underscore, or dash."
        continue
    fi

    if tmux has-session -t "=$session_name" 2>/dev/null; then
        error_message="Session '$session_name' already exists."
        continue
    fi

    if [ "$session_windows" = "1" ] && [ "$window_panes" = "1" ]; then
        tmux new-window -d -t popup:99 -n popup -c "$pane_path"
    fi

    tmux new-session -d -s "$session_name" -c "$pane_path"
    tmux break-pane -d -s "$source_pane" -t "$session_name":99
    tmux kill-window -t "$session_name":1

    if [ -n "$window_name" ] && [ "$window_name" != "bash" ]; then
        tmux rename-window -t "$session_name":1 "$window_name"
    fi

    tmux display-message "Created session '$session_name' from popup pane"
    exit 0
done
