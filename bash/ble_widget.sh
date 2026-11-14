function ble/widget/zi_widget {
  local oldpwd=$PWD

  # Hand terminal input modes to fzf, then restore ble.sh even on cancellation.
  ble/widget/external-command '_ZO_DOCTOR=0 zi'

  if [[ $PWD != "$oldpwd" ]] && declare -f on_chpwd >/dev/null; then
    on_chpwd
  fi

  ble/widget/redraw-line

}
ble-bind -m 'vi_imap' -f 'M-c' 'zi_widget'

function ble/widget/fff_widget {
  # 1. 建立一個臨時檔案儲存 yazi 退出時的最後路徑
  local tmpfile
  tmpfile=$(mktemp -t "yazi-cwd.XXXXXX")

  # 2. 執行 yazi，並傳入 --cwd-file 紀錄離開時的路徑
  # (如果是 fff，請改用 fff "$@" 後參考下方說明)
  yazi --cwd-file="$tmpfile"

  # 3. 讀取記錄下來的路徑
  local target_dir
  if [[ -f "$tmpfile" ]]; then
    target_dir=$(cat "$tmpfile")
    rm -f "$tmpfile"
  fi

  # 4. 如果路徑存在且與目前目錄不同，使用 gum 詢問使用者
  if [[ -n "$target_dir" && "$target_dir" != "$PWD" ]]; then
    # if gum confirm "Navigate to $target_dir?"; then
    cd -- "$target_dir" || return
    if [[ $PWD != "$oldpwd" ]] && declare -f on_chpwd >/dev/null; then
      on_chpwd
    fi
    # fi
  fi

  # 5. 執行完後，重繪 ble.sh 提示符號與命令列
  ble/widget/redraw-line
}
ble-bind -m 'vi_imap' -f 'M-o' 'fff_widget'
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

function ble/widget/fzf_grep_widget {
  # 執行指定的 binary
  ~/.config/leon_scripts/search_text.sh
  # echo '\n\n'
  # 執行完後，重繪提示符
  ble/widget/redraw-line
}
ble-bind -m 'vi_imap' -f 'C-f' 'fzf_grep_widget'


ble-bind -f 'C-g' edit-and-execute-command
