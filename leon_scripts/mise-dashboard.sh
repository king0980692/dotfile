#!/bin/bash
# M-i: local global-tool dashboard. Ctrl-A opens the existing registry installer.
set -o pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export MISE_DASH_DATA_SCRIPT="$SCRIPT_DIR/mise-dashboard.py"
for cmd in mise fzf python3; do
  command -v "$cmd" >/dev/null || { printf '錯誤: 需要 %s\n' "$cmd" >&2; exit 1; }
done
MISE_DASH_STATE=$(mktemp -d "${TMPDIR:-/tmp}/mise-dashboard.XXXXXX") || exit 1
export MISE_DASH_STATE
trap 'rm -rf -- "$MISE_DASH_STATE"' EXIT
trap 'exit 129' HUP
trap 'exit 143' TERM
printf 'usage\n' > "$MISE_DASH_STATE/sort"

while :; do
  python3 "$MISE_DASH_DATA_SCRIPT" snapshot || exit 1
  read -r term_lines term_cols < <(stty size </dev/tty 2>/dev/null)
  export MISE_DASH_COLUMNS=${term_cols:-100}
  layout=(--border rounded --padding 0,1 --preview-window=right:38%:wrap)
  if [ "${term_cols:-100}" -lt 125 ]; then
    layout=(--border rounded --preview-window=down:38%:wrap)
  fi
  if [ "${term_lines:-24}" -lt 24 ]; then
    layout=(--preview-window=down:40%:hidden:wrap)
  fi
  result=$(python3 "$MISE_DASH_DATA_SCRIPT" rows | FZF_DEFAULT_OPTS= FZF_DEFAULT_OPTS_FILE= fzf \
    --height=100% --reverse --ansi --no-sort --no-hscroll \
    "${layout[@]}" --border-label ' mise · Global packages ' \
    --delimiter=$'\t' --with-nth=2.. --header-lines=1 \
    --header "$(python3 "$MISE_DASH_DATA_SCRIPT" header)" \
    --prompt 'Filter › ' --ghost '篩選已安裝套件；Ctrl-A 搜尋安裝新套件' \
    --info=inline-right --pointer='▌' \
    --preview 'python3 "$MISE_DASH_DATA_SCRIPT" preview {1}' \
    --preview-label ' Package details ' \
    --footer ' ^A 安裝 · ^S 排序 · ^R 更新狀態 · Enter 詳情 · ^D 移除 · Esc 離開 ' \
    --bind 'enter:toggle-preview' \
    --bind 'ctrl-s:reload(python3 "$MISE_DASH_DATA_SCRIPT" cycle)' \
    --expect=ctrl-a,ctrl-r,ctrl-d \
    --color 'border:4,label:4,header:6,pointer:2,hl:3,hl+:3')
  status=$?
  key=${result%%$'\n'*}
  # --expect still emits the key when the filtered list is empty, but fzf
  # returns 1. Navigation actions must work without a selected package.
  case "$status:$key" in
    0:*|1:ctrl-a|1:ctrl-r) ;;
    130:*) exit 0 ;; # Esc/Ctrl-C
    *) exit "$status" ;;
  esac
  case "$key" in
    ctrl-a) bash "$SCRIPT_DIR/mise-search-fzf.sh" ;;
    ctrl-r) ;;
    ctrl-d)
      row=${result#*$'\n'}
      tool=${row%%$'\t'*}
      [ -n "$tool" ] && [ "$row" != "$result" ] && bash "$SCRIPT_DIR/mise-tool-action.sh" "$tool"
      ;;
    *) exit 0 ;;
  esac
done
