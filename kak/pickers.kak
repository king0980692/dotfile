# fzf + yazi pickers.
#
# Kakoune cannot run an interactive program in the current terminal (it owns
# the tty and has no run-shell), so every picker runs in a floating popup
# opened through the `terminal` command — herdr.kak's windowing module
# inside herdr (kak-popup plugin), the stock tmux module inside tmux. The
# popup runs scripts/pick.sh, which sends the result back to this session
# with `kak -p` and exits; it then closes itself and focus returns here.
#
# Keys mirror the ble.sh widgets in bash/ble_widget.sh (same hand memory for
# shell and editor):
#   <c-t>  fzf file picker (leon_scripts/search_files.sh, shared with the
#          shell widget)                                — ble: C-t
#   <c-f>  ripgrep + fzf live search                    — ble: C-f
#   <tab>  fzf word-completion menu                     — ble: TAB
#   <a-o>  yazi file manager                            — ble: M-o
#   <a-f>  yazi file manager                            — ble: M-f
# The optional argument is the mode to fall back to when a picker is
# aborted: `insert` (what the bindings pass) or `normal` (the default).

# Arguments reach scripts/pick.sh through these options: Kakoune's parser
# ends a %{...} block at the first unbalanced brace no matter how the value
# is quoted, so raw values (session names, buffer words, paths) must never
# be spliced into generated code — each one travels as its own %opt
# expansion instead. pick_a1..pick_a6 cover mode, origin, session, client
# and the two word-completion extras.
evaluate-commands %sh{
    for name in pick_a1 pick_a2 pick_a3 pick_a4 pick_a5 pick_a6 \
                pick_origin pick_words; do
        printf "declare-option str %s ''\n" "$name"
    done
}

define-command -hidden -params 1.. -docstring \
'pick-launch <mode> [<origin> [<extra>...]]: open scripts/pick.sh in a floating popup (internal)' \
pick-launch %{
    evaluate-commands %sh{
        mode=$1
        shift
        origin=normal
        if [ $# -gt 0 ]; then
            origin=$1
            shift
        fi
        sq() { printf "'%s'" "$(printf %s "$1" | sed "s/'/''/g")"; }
        sets=
        refs=
        n=0
        for arg in "$mode" "$origin" "$kak_session" "$kak_client" "$@"; do
            n=$((n + 1))
            if [ "$n" -gt 7 ]; then
                printf "fail 'pick-launch: too many arguments'\n"
                exit
            fi
            sets="$sets
set global pick_a$n $(sq "$arg")"
            refs="$refs %opt{pick_a$n}"
        done
        if [ "$origin" = insert ]; then
            restore="; execute-keys 'i'"
        else
            restore=
        fi
        msg='pickers: no popup available (herdr kak-popup plugin or tmux required)'
        printf '%s
try %%{ terminal %s %s } catch %%{ echo "%s"%s }\n' \
            "$sets" "$(sq "$kak_config/scripts/pick.sh")" "$refs" "$msg" "$restore"
    }
}

define-command -params 0..1 -docstring \
'fzf-file [insert]: pick a file with fzf and edit it (ble.sh fzf_search_widget, C-t)' \
fzf-file %{
    pick-launch file %arg{@}
}

define-command -params 0..1 -docstring \
'fzf-grep [insert]: live ripgrep + fzf search; opens every match in a buffer (ble.sh fzf_grep_widget, C-f)' \
fzf-grep %{
    pick-launch grep %arg{@}
}

define-command -params 0..1 -docstring \
'yazi-picker [insert]: browse with the yazi file manager and edit the chosen files (ble.sh fff_widget, M-o/M-f)' \
yazi-picker %{
    pick-launch yazi %arg{@}
}

define-command -params 0..1 -docstring \
'fzf-complete [insert]: fzf completion menu over the words of the loaded buffers (ble.sh fzf-menu-complete, TAB); falls back to indenting when no word is under the cursor' \
fzf-complete %{
    # Select the word under the cursor first: pick.sh replaces exactly that
    # selection when a candidate comes back, so every step below leaves it
    # alone (a whole-buffer `%y` yank would move the cursor to the buffer
    # end and destroy it, which is why the candidates do not use a yank).
    try %{
        execute-keys '<a-i>w'
    } catch %{
        # Nothing to complete: keep plain TAB indenting instead.
        execute-keys 'i<tab>'
        fail 'fzf-complete: no word under the cursor'
    }
    # yank the word into z for pick.sh (query prefill).
    execute-keys '"zy'
    # Candidates: every word of the buffer, de-duplicated below. `write!`
    # copies the buffer to a temp file without touching cursor or
    # selection; the file path travels to pick.sh as pick_words.
    evaluate-commands %sh{
        words=$(mktemp "${TMPDIR:-/tmp}/kak-words.XXXXXX" 2>/dev/null)
        if [ -z "$words" ]; then
            echo "fail 'fzf-complete: cannot create a temporary file'"
        else
            sq() { printf "'%s'" "$(printf %s "$1" | sed "s/'/''/g")"; }
            printf 'set global pick_origin %s\n' "$(sq "${1:-normal}")"
            printf 'set global pick_words %s\n' "$(sq "$words")"
            printf 'write! %%opt{pick_words}\n'
        fi
    }
    evaluate-commands %sh{
        grep -oE '[[:alnum:]_][[:alnum:]_-]*' "$kak_opt_pick_words" \
            | awk '!seen[$0]++' > "$kak_opt_pick_words.w" \
            && mv "$kak_opt_pick_words.w" "$kak_opt_pick_words"
    }
    pick-launch word %opt{pick_origin} %reg{z} %opt{pick_words}
}

# ble.sh muscle memory (bash/ble_widget.sh), insert mode like the shell's
# vi_imap bindings; <c-t> also from normal mode, the rest would clash with
# Kakoune defaults there (<c-f> pages, <a-o> opens a line).
map global insert <c-t> '<esc>:fzf-file insert<ret>'
map global insert <c-f> '<esc>:fzf-grep insert<ret>'
map global insert <a-o> '<esc>:yazi-picker insert<ret>'
map global insert <a-f> '<esc>:yazi-picker insert<ret>'
map global insert <tab> '<esc>:fzf-complete insert<ret>'
map global normal <c-t> ':fzf-file<ret>'
