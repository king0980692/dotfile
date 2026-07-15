#!/bin/bash

pane_path_input="$1"
pane_title="$2"
is_active="${3:-0}"
pane_width="${4:-80}"
pane_command="$5"

HOME="${HOME:-$(eval echo ~)}"
ELLIPSIS="..."
HOME_ICON="🏠"
ARROW=" ➤ "

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

normalize_path() {
    local path="$1"

    if [[ -z "$path" ]]; then
        return
    fi

    if [[ "$path" == ~* ]]; then
        path="${path/#~/$HOME}"
    fi

    if [[ "$path" == /* ]]; then
        if [[ -e "$path" ]]; then
            (cd "$(dirname "$path")" 2>/dev/null && printf '%s/%s' "$(pwd -P)" "$(basename "$path")") || printf '%s' "$path"
        else
            printf '%s' "$path"
        fi
        return
    fi

    local base="$pane_path_input"
    if [[ -n "$base" ]] && [[ -d "$base" ]]; then
        (cd "$base" 2>/dev/null && cd "$(dirname "$path")" 2>/dev/null && printf '%s/%s' "$(pwd -P)" "$(basename "$path")") || printf '%s' "$path"
    else
        printf '%s' "$path"
    fi
}

get_dir_icon() {
    case "$1" in
        .git|.github) printf '󰊢' ;;
        node_modules|dist|vendor|build) printf '󰉋' ;;
        src|public|documents|downloads|pictures|code|project|config|.config|tmux) printf '󰉋' ;;
        test|tests) printf '󰙨' ;;
        venv|env|.venv) printf '󰌠' ;;
        .*) printf '󰘓' ;;
        *) printf '󰉋' ;;
    esac
}

join_with_arrow() {
    local parts=("$@")
    local joined=""
    local part
    for part in "${parts[@]}"; do
        if [[ -z "$joined" ]]; then
            joined="$part"
        else
            joined+="$ARROW$part"
        fi
    done
    printf '%s' "$joined"
}

join_shortened_parts() {
    local max_parts="$1"
    shift
    local parts=("$@")
    local count="${#parts[@]}"

    if (( count <= max_parts )); then
        join_with_arrow "${parts[@]}"
        return
    fi

    if (( max_parts <= 2 )); then
        join_with_arrow "${parts[0]}" "$ELLIPSIS" "${parts[count-1]}"
        return
    fi

    local tail_count=$((max_parts - 2))
    local output=("${parts[0]}" "$ELLIPSIS")
    local start=$((count - tail_count))
    local i
    for ((i = start; i < count; i++)); do
        output+=("${parts[i]}")
    done
    join_with_arrow "${output[@]}"
}

join_with_slash() {
    local parts=("$@")
    local joined=""
    local part
    for part in "${parts[@]}"; do
        if [[ -z "$joined" ]]; then
            joined="$part"
        else
            joined+="/$part"
        fi
    done
    printf '%s' "$joined"
}

shorten_file_path() {
    local path="$1"
    local max_parts="$2"
    IFS='/' read -r -a parts <<< "$path"
    local count="${#parts[@]}"

    if (( count <= max_parts )); then
        printf '%s' "$path"
        return
    fi

    if (( max_parts <= 2 )); then
        printf '%s' "$(join_with_slash "${parts[0]}" "$ELLIPSIS" "${parts[count-1]}")"
        return
    fi

    local tail_count=$((max_parts - 2))
    local output=("${parts[0]}" "$ELLIPSIS")
    local start=$((count - tail_count))
    local i
    for ((i = start; i < count; i++)); do
        output+=("${parts[i]}")
    done
    printf '%s' "$(join_with_slash "${output[@]}")"
}

shorten_text() {
    local text="$1"
    local max_length="$2"
    local length=${#text}

    if (( length <= max_length )); then
        printf '%s' "$text"
        return
    fi

    if (( max_length <= 3 )); then
        printf '%s' "${text:0:max_length}"
        return
    fi

    printf '%s%s' "${text:0:max_length-3}" "$ELLIPSIS"
}

replace_home_prefix() {
    local path="$1"
    if [[ -n "$HOME" && "$path" == "$HOME"* ]]; then
        printf '~%s' "${path#"$HOME"}"
    else
        printf '%s' "$path"
    fi
}

format_directory_plain() {
    local source_path="$1"
    local normalized
    normalized="$source_path"
    if [[ -n "$normalized" ]] && [[ -d "$normalized" ]]; then
        normalized="$(cd "$normalized" 2>/dev/null && pwd -P)"
    fi
    normalized="${normalized:-$source_path}"
    normalized="$(replace_home_prefix "$normalized")"

    if [[ "$normalized" == "~" ]]; then
        printf '%s Home' "$HOME_ICON"
        return
    fi

    if [[ "$normalized" == "/" ]]; then
        printf '📁 Root'
        return
    fi

    IFS='/' read -r -a raw_parts <<< "$normalized"
    local parts=()
    local part
    for part in "${raw_parts[@]}"; do
        [[ -z "$part" ]] && continue
        if [[ "$part" == "~" ]]; then
            parts+=("Home")
        else
            parts+=("$part")
        fi
    done

    local count="${#parts[@]}"
    if (( count == 0 )); then
        printf '📁 %s' "$normalized"
        return
    fi

    local icon
    icon="$(get_dir_icon "${parts[count-1]}")"

    local max_parts=4
    if (( pane_width < 60 )); then
        max_parts=3
    fi
    if (( pane_width < 36 )); then
        max_parts=2
    fi

    printf '%s %s' "$icon" "$(join_shortened_parts "$max_parts" "${parts[@]}")"
}

parse_nvim_path_from_title() {
    local title
    title="$(trim "$pane_title")"

    case "$title" in
        nvim*) ;;
        *) return ;;
    esac

    local raw
    raw="$(trim "${title#nvim}")"

    if [[ "$raw" =~ ^(.*)[[:space:]]+(\+[0-9]+|\[\+\]|\[-\]|\+|-)$ ]]; then
        raw="${BASH_REMATCH[1]}"
    fi
    raw="$(trim "$raw")"

    [[ -n "$raw" ]] || return
    printf '%s' "$raw"
}

format_generic_title_plain() {
    local title
    title="$(trim "$pane_title")"
    [[ -n "$title" ]] || return

    case "$title" in
        nvim*) return ;;
    esac

    local command_lower="${pane_command,,}"
    local title_lower="${title,,}"
    local user_lower="${USER,,}"
    local pane_path_abs=""
    local pane_path_short=""
    local pane_path_name=""

    if [[ -n "$pane_path_input" && -d "$pane_path_input" ]]; then
        pane_path_abs="$(cd "$pane_path_input" 2>/dev/null && pwd -P)"
        pane_path_short="$(replace_home_prefix "$pane_path_abs")"
        pane_path_name="$(basename "$pane_path_abs")"
    fi

    if [[ -n "$command_lower" && "$title_lower" == "$command_lower" ]]; then
        return
    fi

    case "$title_lower" in
        bash|zsh|fish|sh|tmux) return ;;
    esac

    if [[ -n "$user_lower" && "$title_lower" == "$user_lower" ]]; then
        return
    fi

    if [[ -n "$pane_path_abs" ]]; then
        if [[ "$title" == "$pane_path_abs" || "$title" == "$pane_path_short" || "$title" == "$pane_path_name" ]]; then
            return
        fi
    fi

    local max_length=$((pane_width / 2))
    if (( max_length < 18 )); then
        max_length=18
    fi
    printf '%s' "$(shorten_text "$title" "$max_length")"
}

format_file_plain() {
    local raw_path
    raw_path="$(parse_nvim_path_from_title)"
    [[ -n "$raw_path" ]] || return

    local file_abs
    file_abs="$(normalize_path "$raw_path")"
    [[ -n "$file_abs" ]] || file_abs="$raw_path"

    local display_path="$file_abs"
    if [[ -n "$display_base_abs" && "$file_abs" == "$display_base_abs"/* ]]; then
        display_path="${file_abs#"$display_base_abs/"}"
    else
        display_path="$(replace_home_prefix "$file_abs")"
    fi

    local max_parts=3
    if (( pane_width < 55 )); then
        max_parts=2
    fi

    printf '%s' "$(shorten_file_path "$display_path" "$max_parts")"
}

resolve_file_abs() {
    local raw_path
    raw_path="$(parse_nvim_path_from_title)"
    [[ -n "$raw_path" ]] || return

    local file_abs
    file_abs="$(normalize_path "$raw_path")"
    [[ -n "$file_abs" ]] || file_abs="$raw_path"
    printf '%s' "$file_abs"
}

pane_abs=""
if [[ -n "$pane_path_input" ]] && [[ -d "$pane_path_input" ]]; then
    pane_abs="$(cd "$pane_path_input" 2>/dev/null && pwd -P)"
fi

file_abs="$(resolve_file_abs)"
title_plain="$(format_generic_title_plain)"

display_base_path="$pane_path_input"
if [[ -n "$file_abs" && -n "$pane_abs" && "$file_abs" != "$pane_abs"/* ]]; then
    display_base_path="$(dirname "$file_abs")"
fi

display_base_abs=""
if [[ -n "$display_base_path" && -d "$display_base_path" ]]; then
    display_base_abs="$(cd "$display_base_path" 2>/dev/null && pwd -P)"
fi

directory_plain="$(format_directory_plain "$display_base_path")"
file_plain="$(format_file_plain)"

if [[ "$is_active" == "1" ]]; then
    open_style='#[align=left][ #[fg=colour214,underscore,bold]'
    file_style='#[fg=colour214]'
    arrow_style='#[fg=colour214]'
    close_style='#[default]#[fg=colour214]'
else
    open_style='#[align=left][ #[fg=colour244]'
    file_style='#[fg=colour244]'
    arrow_style='#[fg=colour244]'
    close_style='#[default]#[fg=colour244]'
fi

printf '%s%s' "$open_style" "$directory_plain"
printf '%s ]' "$close_style"
if [[ -n "$file_plain" ]]; then
    printf '%s%s%s%s' "$arrow_style" "$ARROW" "$file_style" "$file_plain"
elif [[ -n "$title_plain" ]]; then
    printf '%s%s%s%s' "$arrow_style" "$ARROW" "$file_style" "$title_plain"
fi
printf '#[default]'
