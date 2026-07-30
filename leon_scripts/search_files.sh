#!/usr/bin/env bash
# File search script using fd and fzf
# Usage: search_files.sh [directory]

set -e

# Check if fd and fzf are installed
if ! command -v fd &> /dev/null; then
    echo "Error: fd is not installed. Please install it first."
    exit 1
fi

if ! command -v fzf &> /dev/null; then
    echo "Error: fzf is not installed. Please install it first."
    exit 1
fi

# Set search directory (default to current directory)
SEARCH_DIR="${1:-.}"

# Check if directory exists
if [[ ! -d "$SEARCH_DIR" ]]; then
    echo "Error: Directory '$SEARCH_DIR' does not exist."
    exit 1
fi

# Run fd with fzf for interactive file selection
TERM_WIDTH=$(tput cols)
if [[ $TERM_WIDTH -lt 120 ]]; then
    PREVIEW_POS="down:60%:wrap"
else
    PREVIEW_POS="right:60%:wrap"
fi

selected_file=$(fd --type f --hidden --follow --no-ignore-vcs \
    --exclude .git --exclude node_modules --exclude .venv --exclude venv \
    --exclude __pycache__ --exclude .mypy_cache --exclude .pytest_cache --exclude .ruff_cache \
    --exclude target --exclude dist --exclude build --exclude .next --exclude .cache \
    . "$SEARCH_DIR" | \
    fzf --preview 'sleep 0.2 && bat --style=numbers --color=always --line-range :100 --paging=never {} 2>/dev/null || head -100 {}' \
        --preview-window="$PREVIEW_POS:hidden" \
        --bind 'f1:toggle-preview' \
        --height=80% \
        --reverse \
        --border \
        --prompt="Files > " \
        --header="F1: show preview | Ctrl-/: toggle wrap" \
        --bind 'ctrl-/:change-preview-window(wrap|nowrap)' \
        --bind 'ctrl-y:execute-silent(echo -n {+} | xclip -selection clipboard)' \
        --bind 'ctrl-e:execute(${EDITOR:-nvim} {} < /dev/tty > /dev/tty)' \
        --color='hl:yellow:underline,hl+:yellow:underline:reverse,fg+:bright-white,bg+:236,border:245')

# Print the selected path to stdout; the ble.sh Ctrl+T widget inserts it into
# the command line (no action menu). Nothing printed if the picker was aborted.
[[ -n "$selected_file" ]] && printf '%s\n' "$selected_file"
