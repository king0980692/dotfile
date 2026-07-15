#!/bin/bash
# tmux session switcher using fzf

MODE=${1:-compact}
BASE_MODE=${MODE%-static}
LIVE_SWITCH=1
if [ "$MODE" != "$BASE_MODE" ]; then
  LIVE_SWITCH=0
fi
SCRIPT_PATH="$HOME/.config/leon_scripts/tmux_session_switcher.sh"
REOPEN_FILE="/tmp/tmux_switcher_reopen"
rm -f "$REOPEN_FILE"

current_session=$(tmux display-message -p "#{session_name}")

fzf_args=(
  --reverse
  --disabled
  --no-input
  --cycle
  --prompt=""
  --pointer="➤"
  --no-header
  --info=hidden
  --bind "esc:abort"
  --bind "q:abort"
  --bind "change:clear-query"
  --bind 'left-click:execute(tmux switch-client -t {1})+abort'
  --bind 'right-click:abort'
  --bind "enter:transform:[[ -n {1} ]] && echo 'execute(tmux switch-client -t {1})+abort' || echo 'become(~/.config/leon_scripts/tmux_session_create.sh {q})'"
  --bind "n:become(~/.config/leon_scripts/tmux_session_create.sh {q})"
  --bind "x:become(~/.config/leon_scripts/tmux_session_delete.sh {1})"
  --bind "r:become(~/.config/leon_scripts/tmux_session_rename.sh {1})"
  --bind "/:transform:[[ {fzf:prompt} =~ / ]] && echo 'hide-input+disable-search+clear-query+change-prompt()+rebind(j,k,q,n,x,r,change)' || echo 'change-prompt(/ )+unbind(j,k,q,n,x,r,change)+show-input+enable-search'"
)

if [ "$LIVE_SWITCH" -eq 1 ]; then
  fzf_args+=(
    --bind 'scroll-up:up+execute(tmux switch-client -t {1})'
    --bind 'scroll-down:down+execute(tmux switch-client -t {1})'
    --bind "ctrl-j:down+execute(tmux switch-client -t {1})"
    --bind "ctrl-k:up+execute(tmux switch-client -t {1})"
    --bind "alt-j:down+execute(tmux switch-client -t {1})"
    --bind "alt-k:up+execute(tmux switch-client -t {1})"
    --bind "ctrl-n:down+execute(tmux switch-client -t {1})"
    --bind "j:down+execute(tmux switch-client -t {1})"
    --bind "ctrl-p:up+execute(tmux switch-client -t {1})"
    --bind "k:up+execute(tmux switch-client -t {1})"
    --bind "up:up+execute(tmux switch-client -t {1})"
    --bind "down:down+execute(tmux switch-client -t {1})"
  )
else
  fzf_args+=(
    --bind 'scroll-up:up'
    --bind 'scroll-down:down'
    --bind "ctrl-j:down"
    --bind "ctrl-k:up"
    --bind "alt-j:down"
    --bind "alt-k:up"
    --bind "ctrl-n:down"
    --bind "j:down"
    --bind "ctrl-p:up"
    --bind "k:up"
    --bind "up:up"
    --bind "down:down"
  )
fi

if [ "$BASE_MODE" = "full" ]; then
  REOPEN_TARGET="compact"
  fzf_args+=(
    --padding 1,0,1,2
    --preview 'tmux capture-pane -t {1} -p 2>/dev/null'
    --preview-window 'right,80%'
  )
else
  REOPEN_TARGET="full"
  if [ "$LIVE_SWITCH" -eq 1 ]; then
    REOPEN_TARGET="full-static"
  fi
  fzf_args+=(
    --padding 1,0,1,6
  )
fi

fzf_args+=(
  --bind "\`:execute-silent(echo $REOPEN_TARGET > $REOPEN_FILE)+abort"
)

fzf_args+=(
  --color "bg:-1,bg+:-1,gutter:#000000,marker:-1,hl:-1,hl+:-1"
)

(echo "$current_session"; tmux list-sessions -F "#{session_activity} #{session_name}" | sort -rn | awk '{print $2}' | grep -v "^$current_session$" | grep -v "^popup$") | fzf "${fzf_args[@]}"

# Handle reopen for mode toggle
REOPEN=$(cat "$REOPEN_FILE" 2>/dev/null)
rm -f "$REOPEN_FILE"
if [ "$REOPEN" = "full" ] || [ "$REOPEN" = "full-static" ]; then
  tmux run-shell -b "sleep 0.05 && tmux display-popup -b heavy -T 'Session Switcher' -w 70% -h 70% -E '$SCRIPT_PATH $REOPEN'"
elif [ "$REOPEN" = "compact" ] || [ "$REOPEN" = "compact-static" ]; then
  tmux run-shell -b "sleep 0.05 && tmux display-popup -b heavy -x L -y S -T 'Session Switcher' -w 20% -h 25% -E '$SCRIPT_PATH $REOPEN'"
fi
