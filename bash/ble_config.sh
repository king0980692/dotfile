
# NOTE: fzf integration is loaded in .bashrc after mise activates

bleopt info_display=bottom
bleopt complete_auto_delay=100

# bleopt prompt_ruler=$'\e[94m-'  # blue line
bleopt prompt_ruler=$'\e[90m─'

# bleopt keymap_vi_mode_string_nmap="-- NORMAL --"
# bleopt keymap_vi_mode_string_nmap=$'NORMAL'


bleopt complete_menu_style=align-nowrap
bleopt menu_align_max=35
bleopt menu_align_prefix='\e[1m%d:\e[m '

# --- 智慧補全：TAB 用 fzf 模糊選單 + 大小寫不敏感 ---
# 多個候選時 TAB 跳出 fzf 模糊搜尋（取代原生選單）
ble-import integration/fzf-menu
# 只針對補全選單設高度：不用全域 FZF_DEFAULT_OPTS（避免 tmux-fzf 等繼承出錯）
# local -x 把設定限制在這次補全的 fzf 子行程，不影響其他 fzf widget
function ble/widget/fzf-menu-complete {
  local -x FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS-} --height=40% --min-height=10 --layout=reverse --border"
  local bleopt_integration_fzf_menu_enabled=1
  ble/widget/complete
}
# 大小寫不敏感、- 與 _ 互通
bind 'set completion-ignore-case on'
bind 'set completion-map-case on'

ble-sabbrev L='| $PAGER'
ble-sabbrev J='| jqfzf_eval'
ble-sabbrev -l '..'='cd ..'
ble-sabbrev v='nvim'

bleopt color_scheme=catppuccin_mocha

ble-face auto_complete='fg=#a6adc8,italic'  # catppuccin_mocha的太淺
ble-face syntax_error=none # syntax_error 有顏色讓我很不爽

ble-bind -m 'menu_complete' -f 'C-h' 'menu/backward-column'
ble-bind -m 'menu_complete' -f 'C-l' 'menu/forward-column'
ble-bind -m 'menu_complete' -f 'C-j' 'menu/forward-line'
ble-bind -m 'menu_complete' -f 'C-k' 'menu/backward-line'

ble-bind -f 'C-m' accept-line
ble-bind -f 'RET' accept-line

# 注意：因為用 set -o vi，打字時在 vi_imap keymap，必須指定 -m vi_imap 才會生效
ble-bind -m vi_imap -f 'C-i' fzf-menu-complete
ble-bind -m vi_imap -f 'TAB' fzf-menu-complete





set -o vi
ble-bind -m vi_imap -f 'j j' 'vi_imap/normal-mode'
ble-bind -m vi_imap -f 'C-c' discard-line
ble-bind -m vi_nmap -f 'C-c' discard-line
ble-bind -m vi_imap -f 'C-p' 'history-prev'
ble-bind -m vi_imap -f 'C-n' 'history-next'


# Hook
# https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A71-Introduction#user-content-fn-blehook
function on_chpwd {
  if [ -n "$TMUX" ] || [ -n "${HERDR_ENV:-}" ]; then
    local dir_display git_info branch git_state item_count
    local -a entries

    # tmux-only: update the pane border format (herdr has its own border UI).
    [ -n "$TMUX" ] && tmux set -g pane-border-format "#(~/.config/tmux/pane_border.sh '#{pane_current_path}' '#{pane_title}' '#{pane_active}' '#{pane_width}' '#{pane_current_command}')"

    dir_display=${PWD/#$HOME/~}
    git_info=''

    if git rev-parse --show-toplevel >/dev/null 2>&1; then
      branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
      if git diff --no-ext-diff --quiet --cached 2>/dev/null && git diff --no-ext-diff --quiet 2>/dev/null && [ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
        git_state='clean'
      else
        git_state='changed'
      fi
      git_info="  git:$branch ($git_state)"
    fi

    shopt -s nullglob dotglob
    entries=(*)
    item_count=${#entries[@]}
    shopt -u nullglob dotglob

    clear
    printf '\e[48;5;238;38;5;255;1m %s \e[0m\e[38;5;245m%s  %s items\e[0m\n' "$dir_display" "$git_info" "$item_count"
    ls -CF --group-directories-first --color=auto
  fi
}

blehook CHPWD=on_chpwd

# function vim_status_hook {
#   local cmd="$1"
#   if [ -n "$TMUX" ]; then
#     if [[ "$cmd" =~ ^(vim|nvim)([[:space:]]|$) ]]; then
#       # vim/nvim 模式：顯示 pane_title
#       tmux set -g pane-border-format "#[align=left]#[fg=green][#[fg=colour214]#{pane_title}#[fg=green]]#[fg=yellow]#[default]"
#     fi
#   fi
# }
#
# blehook PREEXEC=vim_status_hook
