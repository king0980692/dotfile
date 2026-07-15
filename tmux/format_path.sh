#!/bin/bash

# Shorten path with icons for tmux pane border format
# Usage: format_path.sh "/full/path/to/directory"

PATH_INPUT="${1:-.}"
IS_ACTIVE="${3:-0}"
MAX_LENGTH=45
HOME_ICON="🏠"
ELLIPSIS="…"
ARROW_GRAY=" #[fg=colour220]➤#[fg=colour240] "
ARROW_COLOR=" #[fg=colour220]➤#[fg=colour214] "

# Icon mapping for specific directories
declare -A ICONS
ICONS[".git"]="⚙️"
ICONS[".github"]="🐙"
ICONS["node_modules"]="📦"
ICONS["src"]="💻"
ICONS["dist"]="📦"
ICONS["build"]="🔨"
ICONS["test"]="🧪"
ICONS["tests"]="🧪"
ICONS["config"]="🔨"
ICONS[".config"]="🔨"
ICONS["documents"]="📄"
ICONS["downloads"]="⬇️"
ICONS["pictures"]="🖼️"
ICONS["code"]="💾"
ICONS["project"]="📂"
ICONS[".local"]="⚙️"
ICONS["venv"]="🐍"
ICONS["env"]="🔧"
ICONS["vendor"]="📦"
ICONS["public"]="🌐"
ICONS["tmux"]="📦"

get_icon() {
    local name="$1"
    
    if [[ -n "${ICONS[$name]}" ]]; then
        echo "${ICONS[$name]}"
    elif [[ "$name" == .* ]]; then
        echo "🔒"  # dot file/folder
    else
        echo "📁"  # default folder
    fi
}

# Normalize path
PATH_DISPLAY="$(cd "$PATH_INPUT" 2>/dev/null && pwd)" || PATH_INPUT
PATH_DISPLAY="${PATH_DISPLAY/#$HOME/~}"

# Handle root and home
if [[ "$PATH_DISPLAY" == "~" ]]; then
    echo "$HOME_ICON Home"
    exit 0
elif [[ "$PATH_DISPLAY" == "/" ]]; then
    echo "📁 Root"
    exit 0
fi

# Split path into components
IFS='/' read -ra COMPONENTS <<< "$PATH_DISPLAY"

# Count non-empty components
NON_EMPTY=0
for c in "${COMPONENTS[@]}"; do
    [[ -n "$c" ]] && ((NON_EMPTY++))
done

# Get icon for last component (the actual directory)
LAST_COMPONENT="${COMPONENTS[-1]}"
DIR_ICON=$(get_icon "$LAST_COMPONENT")

# Build path without icons
declare -a PATH_PARTS
for COMPONENT in "${COMPONENTS[@]}"; do
    [[ -z "$COMPONENT" ]] && continue

    if [[ "$COMPONENT" == "~" ]]; then
        # Skip "Home" when path has more than 3 components
        if [[ $NON_EMPTY -gt 3 ]]; then
            continue
        fi
        PATH_PARTS+=("Home")
    else
        PATH_PARTS+=("$COMPONENT")
    fi
done

# Join with arrow separator
FORMATTED="$DIR_ICON #[fg=colour240]"
for i in "${!PATH_PARTS[@]}"; do
    if [[ $i -gt 0 && $i -ne ${#PATH_PARTS[@]}-1 ]]; then
        FORMATTED="$FORMATTED$ARROW_GRAY"
    elif [[ $i -eq ${#PATH_PARTS[@]}-1 ]]; then
        FORMATTED="$FORMATTED$ARROW_COLOR"
    fi
    FORMATTED="$FORMATTED${PATH_PARTS[$i]}"
done

# Shorten if too long: keep first 1 and last 2 components
if [[ ${#FORMATTED} -gt $MAX_LENGTH ]] && [[ ${#PATH_PARTS[@]} -gt 3 ]]; then
    FORMATTED="$DIR_ICON #[fg=colour240]${PATH_PARTS[0]}$ARROW_GRAY $ELLIPSIS$ARROW_GRAY${PATH_PARTS[-2]}$ARROW_COLOR${PATH_PARTS[-1]}"
fi

# File display is handled by cur_cmd.sh, so we only output the directory path here
if [[ "$IS_ACTIVE" == "1" ]]; then
    printf "#[align=right][ #[underscore,bold]%s#[default]\n" "#[fg=colour213]$FORMATTED#[fg=green]#[default] ]"
else
    echo "#[align=right][ #[fg=colour214]$FORMATTED#[fg=green] ]"
fi
