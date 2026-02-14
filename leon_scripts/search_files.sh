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
selected_file=$(fd --type f --hidden --follow --exclude .git . "$SEARCH_DIR" | \
    fzf --preview 'bat --style=numbers --color=always --line-range :500 {} 2> /dev/null || cat {}' \
        --preview-window=right:40%:nowrap \
        --height=50% \
        --border \
        --prompt="Search Files > " \
        --header="F1: toggle preivew" \
        --bind 'f1:toggle-preview' \
        --bind 'ctrl-/:toggle-preview' \
        --bind 'ctrl-y:execute-silent(echo -n {+} | xclip -selection clipboard)' \
        --bind 'ctrl-e:execute(${EDITOR:-vim} {} < /dev/tty > /dev/tty)' \
        --color='hl:yellow,hl+:bright-yellow,fg+:bright-white,bg+:236,border:240')

# If a file was selected, print its path
if [[ -n "$selected_file" ]]; then
    action=$(printf "open with nvim\nprint\ncopy to clipboard\n" | \
        fzf --prompt="File Action > " \
            --preview 'echo '\
            --border \
            --preview-window 'left:20%:noborder' \
            --height=6 \
            --reverse \
            --info=hidden \
            --disabled \
            --cycle \
            --pointer="➤" \
            --no-input \
            --header "" \
            --layout=reverse || echo "open with nvim")
    case "$action" in
        "open with nvim")
            "${EDITOR:-nvim}" "$selected_file"
            ;;
        "copy to clipboard")
            if command -v xclip > /dev/null; then
                printf '%s' "$selected_file" | xclip -selection clipboard
                printf 'Copied to clipboard: %s\n' "$selected_file"
            else
                printf 'xclip not found; printing path instead.\n'
                printf '%s\n' "$selected_file"
            fi
            ;;
        *)
            printf '%s\n' "$selected_file"
            ;;
    esac
fi
