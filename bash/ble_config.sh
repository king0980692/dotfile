
# Defer fzf integration until ble-attach (mise hasn't activated yet at source time)
blehook/eval-after-load keymap_vi '
  _ble_contrib_fzf_base=$(which fzf 2>/dev/null)
  ble-import -d integration/fzf-completion
'

bleopt info_display=bottom
bleopt complete_auto_delay=100

# bleopt prompt_ruler=$'\e[94m-'  # blue line
bleopt prompt_ruler=$'\e[90m─'

# bleopt keymap_vi_mode_string_nmap="-- NORMAL --"
# bleopt keymap_vi_mode_string_nmap=$'NORMAL'


bleopt complete_menu_style=align-nowrap
bleopt menu_align_max=35
bleopt menu_align_prefix='\e[1m%d:\e[m '

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

ble-bind -f TAB menu-complete
ble-bind -f C-i menu-complete





set -o vi
ble-bind -m vi_imap -f 'j j' 'vi_imap/normal-mode'
ble-bind -m vi_imap -f 'C-c' discard-line
ble-bind -m vi_nmap -f 'C-c' discard-line


# Hook
# https://github.com/akinomyoga/ble.sh/wiki/Manual-%C2%A71-Introduction#user-content-fn-blehook
function on_chpwd {
  if [ -n "$TMUX" ]; then
    # tmux set -g pane-border-format "#[align=left]#[fg=green][#[fg=colour214]#{pane_current_path}#[fg=green]]#[fg=yellow]#[default]"
	# tmux set -g pane-border-format "#(~/.config/tmux/format_path.sh '#{pane_current_path}' '#{pane_title}')#(~/.config/tmux/cur_cmd.sh '#{pane_tty}' '#{pane_title}')#[default] "

  tmux set -g pane-border-format "#(~/.config/tmux/format_path.sh '#{pane_current_path}' '#{pane_title}' '#{pane_active}')#(~/.config/tmux/cur_cmd.sh '#{pane_tty}' '#{pane_title}' '#{pane_current_path}')#[default]"
  echo $PWD 
  ls --color
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

