# Move the whole starship prompt into ble.sh's vim-style status line (the bottom
# line that already shows "-- INSERT --") and leave PS1 as a single character.
#
# MUST be sourced BEFORE ble-attach. Once ble.sh attaches, ble-edit/adjust-PS1
# does `builtin unset -v PROMPT_COMMAND` and keeps the real one in
# _ble_edit_PROMPT_COMMAND; anything appended after that is silently dropped on
# the next prompt (and sees PS1 = "[ble: press RET to continue]", the sentinel).
#
# Turn off with BLE_NO_STATUSLINE=1.

[[ ${BLE_VERSION-} && ! ${BLE_NO_STATUSLINE:-} ]] || return 0

_ble_sl_text='' _ble_sl_ver=0
_ble_sl_ps1='\[\e[1;38;2;255;20;147m\]>\[\e[m\] '

# Runs last in PROMPT_COMMAND, i.e. after starship has rendered the full prompt
# into PS1: take that string for the status line, hand PS1 back as one char.
_ble_sl_hoist() {
  _ble_sl_text=${PS1//\\[/}
  _ble_sl_text=${_ble_sl_text//\\]/}
  ((_ble_sl_ver++))
  PS1=$_ble_sl_ps1
  # The vi mode indicator is drawn from the internal_PRECMD hook, which runs
  # *before* PROMPT_COMMAND — without this redraw the status line lags one
  # command behind (it would still show the previous cwd after a cd).
  ble/is-function ble/keymap:vi/update-mode-indicator &&
    ble/keymap:vi/update-mode-indicator
}
if [[ ${PROMPT_COMMAND@a} == *a* ]]; then
  PROMPT_COMMAND+=(_ble_sl_hoist)
else
  PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}_ble_sl_hoist"
fi

# The mode indicator is itself a prompt-expanded string, so the status line can
# carry arbitrary content next to -- INSERT -- / -- NORMAL --.
# The vi mode shows up as the colour of starship's character bubble (the last
# one) — no -- INSERT -- text, no full-width bar. starship paints that bubble in
# char_bg, so recolouring it is a substitution of that one RGB triple; the
# symbol keeps starship's own fg, so the bubble still shows exit status too.
_ble_sl_char_bg='50;63;56'   # = starship.toml [palettes.custom1] char_bg #323f38
function ble/prompt/backslash:leon/statusline {
  ble/prompt/unit/add-hash '$_ble_sl_ver'
  local keymap=${prompt_vi_keymap-}
  if [[ $keymap ]]; then
    ble/prompt/unit/add-hash '$_ble_decode_keymap,${_ble_decode_keymap_stack[*]}'
  else
    ble/keymap:vi/script/get-vi-keymap
  fi
  local mode
  case $keymap in
  (vi_imap)         mode='38;66;47'  ;;  # insert  #26422f - green
  (vi_nmap|vi_omap) mode='40;64;95'  ;;  # normal  #28405f - blue
  (vi_xmap|vi_smap) mode='77;58;24'  ;;  # visual  #4d3a18 - amber
  (vi_cmap)         mode='63;47;82'  ;;  # command #3f2f52 - purple
  (*)               mode=$_ble_sl_char_bg ;;
  esac
  ble/prompt/print "${_ble_sl_text//$_ble_sl_char_bg/$mode}"
}
# lib/keymap.vi.sh is loaded lazily and re-declares this option with its own
# default, so setting it here directly gets clobbered — defer until it loads.
blehook/eval-after-load keymap_vi '
  bleopt prompt_vi_mode_indicator="\q{leon/statusline}"'
