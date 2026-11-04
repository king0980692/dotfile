# herdr integration (herdr.dev — the terminal workspace manager this box runs
# inside: HERDR_ENV=1, socket at ~/.config/herdr/herdr.sock).
#
# 1. Windowing module. Kakoune has no way to run an interactive program
#    itself (it owns the tty, and unlike vim it ships no run-shell), so
#    :terminal / :new delegate to whichever windowing module detects the
#    environment (rc/windowing/detection.kak probes windowing_modules just
#    after the user config is read). herdr has no stock module, so this one
#    opens a FLOATING POPUP through the kak-popup plugin
#    (herdr/plugins/local/kak-popup, linked with `herdr plugin link`):
#      herdr plugin pane open --placement popup --focus
#        -> the popup host run.sh execs $KAK_POPUP_CMD
#    and because the program is the popup's root process, herdr closes the
#    popup and returns focus to Kakoune's pane by itself (all verified
#    against herdr 0.9.3). The plugin API is the only programmatic popup:
#    `herdr pane split` has none, and [[keys.command]] popups are
#    config-level only.
#
# 2. OSC 52 yank, mirroring nvim's clipboard handling (nvim/init.lua): herdr
#    panes have no system clipboard to hand a register to, but the outer
#    terminal honours OSC 52 — it already does for nvim — so `y` forwards the
#    yanked register to /dev/tty.
#
# The light/dark colorscheme selection lives in kakrc, next to the comment
# explaining the shared term-appearance file.

# Try herdr before the stock modules: outside herdr the module's own guard
# (below) makes require-module fail and detection.kak moves on to tmux etc.
set global windowing_modules 'herdr' 'tmux' 'screen' 'zellij' 'kitty' \
    'iterm' 'appleterminal' 'sway' 'wayland' 'x11' 'wezterm'

provide-module herdr %{

# Refuse to load outside a herdr pane — same contract as the stock modules.
evaluate-commands %sh{
    [ -z "${kak_opt_windowing_modules}" ] || [ -n "${HERDR_ENV:-}" ] || echo 'fail herdr not detected'
}

define-command -hidden -params 1.. herdr-terminal-impl -docstring \
'herdr-terminal-impl <program> [<arguments>]: run <program> in a floating herdr popup' \
%{
    evaluate-commands %sh{
        if ! command -v herdr >/dev/null 2>&1; then
            printf "fail 'herdr: herdr binary not found in PATH'\n"
            exit
        fi
        # One shell command line for the popup host (run.sh does
        # `exec sh -c "$KAK_POPUP_CMD"`); single quotes are doubled for
        # sh on the way in. No exec-safe quoting is needed beyond that:
        # the value passes through exactly one sh -c.
        cmd=exec
        for arg in "$@"; do
            cmd="$cmd '$(printf %s "$arg" | sed "s/'/'\\\\''/g")'"
        done
        cwd=${kak_client_env_PWD:-$PWD}
        # Sizes are per-open; the manifest only pins placement=popup.
        if ! herdr plugin pane open --plugin kak-popup --entrypoint kak-popup \
            --placement popup --width 80% --height 70% --focus \
            --cwd "$cwd" --env "KAK_POPUP_CMD=$cmd" >/dev/null 2>&1; then
            printf "fail 'herdr: popup open failed (is the kak-popup plugin linked and enabled?)'\n"
        fi
    }
}

define-command herdr-terminal-window -params 1.. -docstring '
herdr-terminal-window <program> [<arguments>]: run <program> in a floating
herdr popup — herdr panes are the only window level and every placement
here floats' \
%{
    herdr-terminal-impl %arg{@}
}
complete-command herdr-terminal-window shell

define-command herdr-terminal-horizontal -params 1.. -docstring '
herdr-terminal-horizontal <program> [<arguments>]: same as -window; the
popup ignores split directions' \
%{
    herdr-terminal-impl %arg{@}
}
complete-command herdr-terminal-horizontal shell

define-command herdr-terminal-vertical -params 1.. -docstring '
herdr-terminal-vertical <program> [<arguments>]: same as -window; the
popup ignores split directions' \
%{
    herdr-terminal-impl %arg{@}
}
complete-command herdr-terminal-vertical shell

# No `focus` alias: `herdr pane focus` only moves focus to a *neighbouring*
# pane (--direction left/right/up/down), there is no focus-the-current-pane
# call to alias to. :focus stays undefined, exactly as it is today outside
# tmux (no stock module ever loads on this box).
}

# ── OSC 52 clipboard ───────────────────────────────────────────────────────
# Same condition as nvim's clipboard setup: SSH_TTY or HERDR_ENV
# (nvim/init.lua). Fires after `y` has stored the selections in the default
# yank register (dquote); deletes/copies stay internal, only explicit yanks
# travel to the terminal's clipboard.
evaluate-commands %sh{
    if [ -n "${HERDR_ENV:-}" ] || [ -n "${SSH_TTY:-}" ]; then
        cat <<'PICK'
hook global NormalKey 'y' %{ nop %sh{
    # empty yank would otherwise clear the terminal clipboard
    [ -n "$kak_reg_dquote" ] || exit 0
    printf '\033]52;c;%s\a' "$(printf %s "$kak_reg_dquote" | base64 -w0)" >/dev/tty
} }
PICK
    fi
}
