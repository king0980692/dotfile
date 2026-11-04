#!/usr/bin/env bash
# Picker helper — runs inside the split pane that Kakoune's `terminal`
# command opens (see kak/pickers.kak, invoked as
# `terminal .../pick.sh %opt{pick_a1} ...` so the config path travels in
# kak_config). It runs one interactive fzf/yazi selection on this pane's
# tty, ships the result back to the Kakoune session with `kak -p`, and
# exits; because herdr/tmux started us with `exec`, the pane then closes
# itself and focus returns to Kakoune.
#
# usage: pick.sh <mode> <origin> <session> <client> [<mode-specific>...]
#         mode:   file | grep | yazi | word
#         origin: insert | normal — mode to fall back to when aborted
set -u
mode=$1
origin=$2
session=$3
client=$4
shift 4
config=${XDG_CONFIG_HOME:-$HOME/.config}

kq() { # Kakoune quotes strings by doubling embedded single quotes
    local s=${1//\'/\'\'}
    printf "'%s'" "$s"
}

ev() { # run a command line in the session, in the launching client's context
    if [ -n "$client" ]; then
        printf 'evaluate-commands -try-client %s %s\n' "$(kq "$client")" "$(kq "$1")" \
            | kak -p "$session" 2>/dev/null
    else
        printf 'evaluate-commands %s\n' "$(kq "$1")" | kak -p "$session" 2>/dev/null
    fi
}

restore() { [ "$origin" = insert ] && ev "execute-keys 'i'"; }
aborted() { restore; exit 0; }

# Open every entry on stdin bottom-up so the first entry ends up as the
# current buffer/focused window. An entry is `path` or `path:line[:col...]`;
# the trailing line number becomes `Ngh` (goto line N, line begin) right
# after the open. Paths are absolutised so the server resolves them from
# its own cwd.
open_all() {
    local entry f ln
    while IFS= read -r entry; do
        [ -n "$entry" ] || continue
        f=${entry%%:*}
        ln=${entry#*:}
        ln=${ln%%:*}
        case $ln in '' | *[!0-9]*) ln=1 ;; esac
        case $f in /*) ;; *) f=$PWD/$f ;; esac
        ev "edit $(kq "$f")"
        ev "execute-keys $(kq "${ln}gh")"
    done
}

case $mode in
file)
    # leon_scripts/search_files.sh — the very script the ble.sh C-t widget
    # runs; prints the chosen path, nothing when aborted.
    if ! sel=$("$config/leon_scripts/search_files.sh" 2>/dev/null) || [ -z "$sel" ]; then
        aborted
    fi
    printf '%s\n' "$sel" | tac | open_all
    restore
    ;;
grep)
    # kak/scripts/grep-pick.sh — one `file:line:col:text` entry per line;
    # rg colourises the output, drop the ANSI before parsing fields.
    if ! sel=$("$config/kak/scripts/grep-pick.sh" 2>/dev/null) || [ -z "$sel" ]; then
        aborted
    fi
    printf '%s\n' "$sel" | sed 's/\x1b\[[0-9;]*m//g' | tac | open_all
    restore
    ;;
yazi)
    chooser=$(mktemp "${TMPDIR:-/tmp}/kak-yazi.XXXXXX") || aborted
    yazi --chooser-file "$chooser" || true
    sel=$(cat "$chooser" 2>/dev/null)
    rm -f "$chooser"
    [ -n "$sel" ] || aborted
    printf '%s\n' "$sel" | tac | open_all
    restore
    ;;
word)
    # fzf-complete extras: the word under the cursor, then the words file.
    # Inserts the selected candidate in place of the word (ble.sh
    # fzf-menu-complete inserts the completion, not an append); on abort the
    # selection already still is the original word.
    [ $# -ge 2 ] || aborted
    word=$1
    words=$2
    sel=$(fzf --height=40% --min-height=10 --layout=reverse --border \
        --bind=tab:down,btab:up --query "$word" < "$words" 2>/dev/null) || sel=
    rm -f "$words"
    [ -n "$sel" ] || aborted
    # words are [[:alnum:]_-] so the candidate is plain literal key input
    if [ "$origin" = insert ]; then
        ev "execute-keys $(kq "c$sel")" # c: replace word, stay in insert
    else
        ev "execute-keys $(kq "c$sel<esc>")"
    fi
    ;;
*)
    aborted
    ;;
esac
exit 0
