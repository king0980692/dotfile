#!/usr/bin/env bash
# <c-f> grep picker for Kakoune (mode=grep in kak/scripts/pick.sh): live
# ripgrep + fzf search — same query split and transformer as
# leon_scripts/search_text.sh (the script ble.sh's C-f widget runs), but
# printing the selected `file:line:col:text` entries for pick.sh to open in
# Kakoune instead of handing them to $EDITOR.
#
# usage: grep-pick.sh [initial-query]   (no argument = empty query, like C-f)
set -u
export TEMP=$(mktemp -u)
trap 'rm -f "$TEMP"' EXIT

INITIAL_QUERY="${*:-}"

# Determine preview window position based on terminal width
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
if [[ $TERM_WIDTH -lt 120 ]]; then
    PREVIEW_POS="down:60%:wrap"
else
    PREVIEW_POS="right:60%:wrap"
fi

TRANSFORMER='
  rg_pat={q:1}      # The first word is passed to ripgrep
  fzf_pat={q:2..}   # The rest are passed to fzf

  if ! [[ -r "$TEMP" ]] || [[ $rg_pat != $(cat "$TEMP") ]]; then
    echo "$rg_pat" > "$TEMP"
    printf "reload:sleep 0.1; rg -j 1 --column --line-number --no-heading --color=always --smart-case -- %q || true\n" "$rg_pat"
  fi
  echo "+search:$fzf_pat"
'

# Default Enter prints the selections for pick.sh to parse; no become/exec.
fzf --ansi --disabled --query "$INITIAL_QUERY" \
    --multi \
    --with-shell 'bash -c' \
    --bind "start,change:transform:$TRANSFORMER" \
    --bind 'f1:toggle-preview' \
    --header="F1: toggle preview | Enter: open in Kakoune | Tab: multi-select" \
    --walker-skip="*log*,.git,node_modules,target" \
    --color "hl:229:underline,hl+:229:underline:reverse" \
    --delimiter : \
    --preview 'sleep 0.2 && file={1}; line={2}; if [[ -n "$line" && "$line" -gt 0 ]] 2>/dev/null; then start=$((line > 5 ? line - 5 : 1)); end=$((line + 95)); bat --style=numbers --color=always --paging=never --highlight-line "$line" --line-range "$start:$end" "$file"; else bat --style=numbers --color=always --paging=never --line-range :100 "$file"; fi' \
    --preview-window "$PREVIEW_POS" \
    --reverse \
    --height=75% \
    --border
