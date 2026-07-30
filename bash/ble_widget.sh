function ble/widget/zi_widget {
  local oldpwd=$PWD

  _ZO_DOCTOR=0 zi 

  if [[ $PWD != "$oldpwd" ]] && declare -f on_chpwd >/dev/null; then
    on_chpwd
  fi

  ble/widget/redraw-line

}
ble-bind -m 'vi_imap' -f 'M-c' 'zi_widget'
ble-bind -m 'vi_imap' -f 'M-c' 'zi_widget'

function ble/widget/fff_widget {
  # 執行指定的 binary
  # bash ~/.config/leon_scripts/fff
  yazi
  # fff
  # echo -e 'ls\n'
  # 執行完後，重繪提示符
  # stty sane
  # stty echo icanon
  ble/widget/redraw-line
}
ble-bind -m 'vi_imap' -f 'C-o' 'fff_widget'
ble-bind -m 'vi_imap' -f 'M-f' 'fff_widget'
# ble-bind -m 'vi_nmap' -f 'M-f' 'fff_widget'


function ble/widget/mise_install_widget {
  # 執行指定的 binary
  ~/.config/leon_scripts/mise-search-fzf.sh
  # echo '\n\n'
  # 執行完後，重繪提示符
  ble/widget/redraw-line
}
ble-bind -m 'vi_imap' -f 'M-i' 'mise_install_widget'
# ble-bind -m 'vi_nmap' -f 'M-i' 'mise_install_widget'

function ble/widget/fzf_search_widget {
  # Pick a file, then insert its (shell-quoted) path at the cursor on the bash
  # command line — like fzf's stock Ctrl+T — instead of an action menu.
  local sel
  sel="$(~/.config/leon_scripts/search_files.sh)"
  if [[ -n $sel ]]; then
    local q; printf -v q '%q' "$sel"
    ble/widget/insert-string "$q "
  fi
  ble/widget/redraw-line
}
ble-bind -m 'vi_imap' -f 'C-t' 'fzf_search_widget'
# ble-bind -m 'vi_nmap' -f 'C-t' 'fzf_search_widget'

function ble/widget/fzf_grep_widget {
  # 執行指定的 binary
  ~/.config/leon_scripts/search_text.sh
  # echo '\n\n'
  # 執行完後，重繪提示符
  ble/widget/redraw-line
}
ble-bind -m 'vi_imap' -f 'C-f' 'fzf_grep_widget'


ble-bind -f 'C-g' edit-and-execute-command
