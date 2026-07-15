#!/usr/bin/env bash

set -u

AGENTS=(claude opencode codex)
SCRIPT_PATH="$HOME/.config/leon_scripts/tmux_agent_manager.sh"
TMUX_BIN="${TMUX_BIN:-tmux}"
STATE_DIR="${STATE_DIR:-}"

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmds() {
  local missing=0
  local cmd
  for cmd in "$@"; do
    if ! has_cmd "$cmd"; then
      printf 'Missing command: %s\n' "$cmd" >&2
      missing=1
    fi
  done

  if [ "$missing" -ne 0 ]; then
    exit 1
  fi
}

sanitize() {
  printf '%s' "$1" | tr '\t' ' ' | tr '\n' ' '
}

shorten() {
  local text
  local max_len

  text=$(sanitize "$1")
  max_len="$2"

  if [ "${#text}" -le "$max_len" ]; then
    printf '%s' "$text"
    return
  fi

  printf '%s...' "${text:0:max_len-3}"
}

detect_agent() {
  local pane_cmd="$1"
  local window_name="$2"
  local pane_title="$3"
  local session_name="$4"
  local lower_cmd lower_title

  lower_cmd=$(printf '%s' "$pane_cmd" | tr '[:upper:]' '[:lower:]')
  lower_title=$(printf '%s' "$pane_title" | tr '[:upper:]' '[:lower:]')

  case "$lower_cmd" in
    claude|opencode|codex)
      printf '%s' "$lower_cmd"
      return
      ;;
  esac

  if [[ "$lower_title" == *"claude code"* ]]; then
    printf 'claude'
    return
  fi

  if [[ "$lower_title" == oc\ \|* ]]; then
    printf 'opencode'
    return
  fi
}

list_agents() {
  require_cmds "$TMUX_BIN" awk cut tr

  local fmt line found=0
  fmt=$'#{pane_id}\t#{session_name}\t#{window_index}\t#{window_name}\t#{pane_index}\t#{pane_pid}\t#{pane_current_command}\t#{pane_title}\t#{pane_current_path}\t#{pane_dead}'

  printf 'pane\tsession\tagent\ttitle\ttarget_session\ttarget_window\ttarget_pane\n'

  while IFS=$'\t' read -r pane_id session_name window_index window_name pane_index pane_pid pane_cmd pane_title pane_path pane_dead; do
    [ -n "$pane_id" ] || continue

    local agent title

    agent=$(detect_agent "$pane_cmd" "$window_name" "$pane_title" "$session_name")

    [ -n "$agent" ] || continue
    found=1

    title=$(shorten "$pane_title" 28)
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$pane_id" \
      "$session_name" \
      "$agent" \
      "$title" \
      "$session_name" \
      "$window_index" \
      "$pane_index"
  done < <("$TMUX_BIN" list-panes -a -F "$fmt" 2>/dev/null)

  if [ "$found" -eq 0 ]; then
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      '-' 'No agent pane found' '-' '-' '-' '-' '-'
  fi
}

preview_agent() {
  require_cmds "$TMUX_BIN"

  local pane_id="$1"
  local fmt line session_name window_index window_name pane_index pane_pid pane_cmd pane_title pane_path pane_dead
  fmt=$'#{pane_id}\t#{session_name}\t#{window_index}\t#{window_name}\t#{pane_index}\t#{pane_pid}\t#{pane_current_command}\t#{pane_title}\t#{pane_current_path}\t#{pane_dead}'
  line=$("$TMUX_BIN" list-panes -a -F "$fmt" 2>/dev/null | awk -F '\t' -v pane_id="$pane_id" '$1 == pane_id { print; exit }')

  if [ -z "$line" ]; then
    printf 'pane not found: %s\n' "$pane_id"
    exit 0
  fi

  "$TMUX_BIN" capture-pane -p -e -t "$pane_id" -S -80 2>/dev/null
}

preview_snapshot() {
  preview_agent "$1"
}

preview_live() {
  require_cmds "$TMUX_BIN" cksum

  local pane_id="$1"
  local freeze_file snapshot current_hash previous_hash

  if [ -z "$pane_id" ] || [ "$pane_id" = "pane" ] || [ "$pane_id" = "-" ]; then
    exit 0
  fi

  freeze_file="$STATE_DIR/freeze"
  previous_hash=''

  while true; do
    if [ -f "$freeze_file" ]; then
      preview_snapshot "$pane_id"
      exit 0
    fi

    snapshot=$(preview_snapshot "$pane_id")
    current_hash=$(printf '%s' "$snapshot" | cksum | cut -d' ' -f1)

    if [ "$current_hash" != "$previous_hash" ]; then
      printf '\033[2J\033[H'
      printf '%s' "$snapshot"
      previous_hash="$current_hash"
    fi

    sleep 0.3
  done
}

toggle_freeze() {
  [ -n "$STATE_DIR" ] || exit 0

  local freeze_file="$STATE_DIR/freeze"

  if [ -f "$freeze_file" ]; then
    rm -f "$freeze_file"
  else
    : > "$freeze_file"
  fi
}

open_manager() {
  require_cmds "$TMUX_BIN" fzf mktemp

  local header preview_cmd list_cmd selected state_dir
  header='Enter jump  Ctrl-R refresh  Ctrl-S freeze/live  Ctrl-C send C-c  Alt-X kill pane  Esc/Q quit'
  state_dir=$(mktemp -d)
  trap 'rm -rf "$state_dir"' RETURN
  export STATE_DIR="$state_dir"
  preview_cmd="$SCRIPT_PATH --preview-live {1}"
  list_cmd="$SCRIPT_PATH --list"

  selected=$(
    "$SCRIPT_PATH" --list | \
      fzf \
        --ansi \
        --reverse \
        --disabled \
        --no-input \
        --height=100% \
        --layout=reverse \
        --style=full \
        --cycle \
        --header-lines=1 \
        --border-label ' Agents ' \
        --input-label ' Session / Agent ' \
        --header-label ' Actions ' \
        --preview-label ' Pane Preview ' \
        --header "$header" \
        --ghost 'Select an agent session' \
        --tabstop=12 \
        --prompt '' \
        --pointer '➤' \
        --delimiter=$'\t' \
        --with-nth=2,3 \
        --preview "$preview_cmd" \
        --preview-window 'right,70%,border,follow' \
        --bind 'result:bg-transform-list-label:
          if [[ -z $FZF_QUERY ]]; then
            echo " $FZF_MATCH_COUNT agents "
          else
            echo " $FZF_MATCH_COUNT matches for [$FZF_QUERY] "
          fi
          ' \
        --bind 'focus:bg-transform-preview-label:
          if [[ {1} == "pane" || {1} == "-" ]]; then
            printf "%s" " Pane Preview "
          elif [[ -n {4} ]]; then
            printf " %s " {4}
          else
            printf "%s" " Pane Preview "
          fi
          ' \
        --bind 'focus:+bg-transform-header:
          if [[ {1} == "pane" || {1} == "-" ]]; then
            printf "%s" "Enter jump  Ctrl-R refresh  Ctrl-S freeze/live  Ctrl-C send C-c  Alt-X kill pane  Esc/Q quit"
          else
            printf "Session: %s | Agent: %s | Title: %s" {2} {3} {4}
          fi
          ' \
        --bind "start:reload:$list_cmd" \
        --bind "ctrl-r:reload:$list_cmd" \
        --bind 'ctrl-s:execute-silent('"$SCRIPT_PATH"' --toggle-freeze)+refresh-preview' \
        --bind 'esc:abort' \
        --bind 'q:abort' \
        --bind 'enter:transform:[[ {1} != "-" ]] && echo "execute(tmux switch-client -t {5}; tmux select-window -t {5}:{6}; tmux select-pane -t {1})+abort" || echo ignore' \
        --bind "ctrl-c:execute-silent(if [[ {1} != '-' ]]; then tmux send-keys -t {1} C-c; fi)+reload:$list_cmd" \
        --bind "alt-x:execute-silent(if [[ {1} != '-' ]]; then tmux kill-pane -t {1}; fi)+reload:$list_cmd" \
        --color 'border:#aaaaaa,label:#cccccc' \
        --color 'preview-border:#9999cc,preview-label:#ccccff' \
        --color 'list-border:#669966,list-label:#99cc99' \
        --color 'input-border:#996666,input-label:#ffcccc' \
        --color 'header-border:#6699cc,header-label:#99ccff'
  )

  [ -n "$selected" ] || return 0
}

case "${1:-}" in
  --list)
    list_agents
    ;;
  --preview)
    preview_agent "${2:-}"
    ;;
  --preview-live)
    preview_live "${2:-}"
    ;;
  --toggle-freeze)
    toggle_freeze
    ;;
  --help)
    printf 'Usage: %s [--list|--preview <pane_id>|--preview-live <pane_id>|--toggle-freeze]\n' "$SCRIPT_PATH"
    ;;
  *)
    open_manager
    ;;
esac
