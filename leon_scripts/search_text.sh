#!/usr/bin/env bash

# Controlling Ripgrep search and fzf search simultaneously

for cmd in rg fzf bat; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is not installed. Run 'mise install' first." >&2
        exit 1
    fi
done

export TEMP=$(mktemp -u)
trap 'rm -f "$TEMP"' EXIT

INITIAL_QUERY="${*:-}"

# Determine preview window position based on terminal width
TERM_WIDTH=$(tput cols)
if [[ $TERM_WIDTH -lt 120 ]]; then
    PREVIEW_POS="down:70%,border-line,+{2}+3/3,~3"
else
    PREVIEW_POS="right:80%,border-line,+{2}+3/3,~3"
fi

TRANSFORMER='
  rg_pat={q:1}      # The first word is passed to ripgrep
  fzf_pat={q:2..}   # The rest are passed to fzf

  if ! [[ -r "$TEMP" ]] || [[ $rg_pat != $(cat "$TEMP") ]]; then
    echo "$rg_pat" > "$TEMP"
    printf "reload:sleep 0.1; rg --column --line-number --no-heading --color=always --smart-case -- %q || true" "$rg_pat"
  fi
  echo "+search:$fzf_pat"
'

OPEN_EDITOR_SCRIPT=$(cat <<'EOF'
entries=("$@")
if [ ${#entries[@]} -eq 0 ]; then
  exit 0
fi

args=()
for entry in "${entries[@]}"; do
  IFS=: read -r file line _ <<<"$entry"
  if [[ -z $file ]]; then
    continue
  fi
  line=${line:-1}
  args+=("+$line" "$file")
done

if [ ${#args[@]} -eq 0 ]; then
  exit 0
fi

"${EDITOR:-nvim}" "${args[@]}"
EOF
)

fzf --ansi --disabled --query "$INITIAL_QUERY" \
    --multi \
    --with-shell 'bash -c' \
    --bind "start,change:transform:$TRANSFORMER" \
    --bind 'f1:toggle-preview' \
    --header="F1: toggle preivew" \
	  --walker-skip="*log*,.git,node_modules,target" \
    --color "hl:229:underline,hl+:229:underline:reverse" \
    --delimiter : \
    --preview 'bat --style numbers --color=always {1} --highlight-line {2}' \
    --preview-window "$PREVIEW_POS" \
	  --reverse \
    --height=75% \
    --border \
    --bind "enter:become(bash -c '$OPEN_EDITOR_SCRIPT' _ {+})"


# #!/usr/bin/env bash
# # Text search script using ripgrep and fzf
# # Usage: search_text.sh [directory]
#
# # Check if ripgrep and fzf are installed
# if ! command -v rg &> /dev/null; then
#     echo "Error: ripgrep is not installed. Please install it first."
#     exit 1
# fi
#
# if ! command -v fzf &> /dev/null; then
#     echo "Error: fzf is not installed. Please install it first."
#     exit 1
# fi
#
# # Set search directory (default to current directory)
# SEARCH_DIR="${1:-.}"
#
# # Check if directory exists
# if [[ ! -d "$SEARCH_DIR" ]]; then
#     echo "Error: Directory '$SEARCH_DIR' does not exist."
#     exit 1
# fi
#
# # Ripgrep options
# RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case --hidden --follow --glob '!.git/*'"
#
# # Interactive search with fzf
# selected=$(
#     FZF_DEFAULT_COMMAND="$RG_PREFIX '' $SEARCH_DIR" \
#     fzf --ansi \
#         --disabled \
#         --bind "change:reload:$RG_PREFIX {q} $SEARCH_DIR || true" \
#         --bind "enter:become(echo {})" \
#         --preview 'bat --style=numbers --color=always --highlight-line {2} {1} 2> /dev/null || cat {1}' \
#         --preview-window 'right:60%:wrap:+{2}-5' \
#         --delimiter ':' \
#         --height=100% \
#         --border \
#         --prompt="Search Text > " \
#         --header="Type to search | Enter to select | Esc to quit" \
#         --bind 'ctrl-/:toggle-preview' \
#         --bind 'ctrl-y:execute-silent(echo -n {1}:{2} | xclip -selection clipboard)' \
#         --bind 'ctrl-e:execute(${EDITOR:-vim} {1} +{2} < /dev/tty > /dev/tty)' \
#         --color='hl:yellow,hl+:bright-yellow,fg+:bright-white,bg+:236,border:240'
# )
#
# # If a result was selected, parse and display it
# if [[ -n "$selected" ]]; then
#     # Extract file path and line number
#     file=$(echo "$selected" | cut -d: -f1)
#     line=$(echo "$selected" | cut -d: -f2)
#
#     echo "File: $file"
#     echo "Line: $line"
#     echo "---"
#     echo "$selected"
#
#     # Optionally open the file at the specific line
#     # Uncomment one of the lines below based on your editor preference
#     # ${EDITOR:-vim} "$file" "+$line"
#     # code -g "$file:$line"  # For VS Code
# fi

