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

selected_file=$(fd --type f --hidden --follow --exclude .git -j 1 . "$SEARCH_DIR" | \
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
