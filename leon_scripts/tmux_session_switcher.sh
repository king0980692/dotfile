#!/bin/bash
# tmux session switcher using fzf


current_session=$(tmux display-message -p "#{session_name}")
(echo "$current_session"; tmux list-sessions -F "#{session_name}" | grep -v "^$current_session$" | grep -v "^popup$") | fzf \
  --reverse \
  --disabled \
  --cycle \
  --prompt="" \
  --pointer="➤" \
  --padding 0,0,0,6 \
  --no-input \
  --header "" \
  --info=hidden \
  --bind "esc:abort" \
  --bind "q:abort" \
  --bind "change:clear-query" \
  --bind 'left-click:execute(tmux switch-client -t {1})+abort' \
  --bind 'right-click:abort' \
  --bind 'scroll-up:up+execute(tmux switch-client -t {1})' \
  --bind 'scroll-down:down+execute(tmux switch-client -t {1})' \
  --bind "ctrl-j:down+execute(tmux switch-client -t {1})" \
  --bind "ctrl-k:up+execute(tmux switch-client -t {1})" \
  --bind "alt-j:down+execute(tmux switch-client -t {1})" \
  --bind "alt-k:up+execute(tmux switch-client -t {1})" \
  --bind "ctrl-n:down+execute(tmux switch-client -t {1})" \
  --bind "j:down+execute(tmux switch-client -t {1})" \
  --bind "ctrl-p:up+execute(tmux switch-client -t {1})" \
  --bind "k:up+execute(tmux switch-client -t {1})" \
  --bind "up:up+execute(tmux switch-client -t {1})" \
  --bind "down:down+execute(tmux switch-client -t {1})" \
  --color "bg:-1,bg+:-1,gutter:#000000,marker:-1,hl:-1,hl+:-1"
  # --color "bg+:#E1E1E1,bg:#E1E1E1,hl:#719872,fg:#616161,header:#719872,info:#727100,pointer:136,marker:#E17899,fg+:136,prompt:#0099BD,hl+:#719899"
