#!/bin/bash

# Display file being edited in nvim from pane_title
pane_tty="$1"
pane_title="$2"
pane_path_input="$3"

# Ensure HOME is set
HOME="${HOME:-$(eval echo ~)}"

MAX_FILE_LENGTH=45
ELLIPSIS="…"

shorten_path() {
    local path="$1"
    local length=${#path}
    IFS='/' read -ra parts <<< "$path"
    local count=${#parts[@]}

    if (( length <= MAX_FILE_LENGTH || count <= 3 )); then
        echo "$path"
    else
        local first="${parts[0]}"
        local second_last="${parts[count-2]}"
        local last="${parts[count-1]}"
        echo "${first}/${ELLIPSIS}/${second_last}/${last}"
    fi
}

normalize_path() {
    local base="$1"
    local target="$2"
    [[ -z "$target" ]] && return

    if [[ "$target" == ~* ]]; then
        target="${target/#~/$HOME}"
    fi

    if [[ "$target" == /* ]]; then
        python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$target" 2>/dev/null || echo "$target"
    else
        python3 - "$base" "$target" <<'PY' 2>/dev/null
import os, sys
base, target = sys.argv[1], sys.argv[2]
base = base or os.getcwd()
print(os.path.realpath(os.path.join(base, target)))
PY
    fi
}

# Get real path of current pane directory
pane_path=""
if [[ -n "$pane_path_input" ]]; then
    pane_path=$(cd "$pane_path_input" 2>/dev/null && pwd -P)
    # Remove trailing slash if any
    pane_path="${pane_path%/}"
fi

# Check if nvim is running and pane_title contains a file path
if ps -o comm= -t "$pane_tty" 2>/dev/null | grep -qi "nvim" && [[ -n "$pane_title" ]]; then
    file_path=$(echo "$pane_title" | sed 's/^nvim[[:space:]]*//; s/[[:space:]]*+[0-9]*$//' | sed 's/[[:space:]]*$//')

    if [[ -n "$file_path" ]]; then
        file_abs=$(normalize_path "$pane_path" "$file_path")
        # Remove trailing slash if any
        file_abs="${file_abs%/}"
        display_path="$file_abs"

        if [[ -n "$pane_path" && -n "$file_abs" ]]; then
            filename=$(basename "$file_abs")

            # Method 1: Check if file exists in current directory (most reliable)
            if [[ -f "$pane_path/$filename" ]]; then
                # Verify it's the same file by comparing real paths
                file_real=$(cd "$(dirname "$file_abs")" 2>/dev/null && pwd -P)/"$filename"
                pane_file_real="$pane_path/$filename"
                if [[ "$file_real" == "$pane_file_real" ]]; then
                    display_path="$filename"
                else
                    display_path="${file_abs/#$HOME/~}"
                fi
            # Method 2: Check if file is in subdirectory
            elif [[ "$file_abs" == "$pane_path/"* ]]; then
                display_path="${file_abs#"$pane_path/"}"
            else
                # File is outside current directory
                display_path="${file_abs/#$HOME/~}"
            fi
        else
            display_path="${file_abs/#$HOME/~}"
        fi

        display_path=$(shorten_path "$display_path")
        echo -n "#[fg=colour224] ➢ #[fg=colour224]$display_path#[fg=colour224] "
    fi
fi
