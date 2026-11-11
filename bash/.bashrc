# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Locale (required by ble.sh)
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# atuin 負責硬碟持久化，bash 只保留 in-memory history 供 Ctrl+P/N 使用
export HISTFILE=/dev/null
export HISTSIZE=10000

#####################################################################

[[ $- == *i* ]] && source -- ~/.local/share/blesh/ble.sh --attach=none

source ~/.config/bash/ble_config.sh
source ~/.config/bash/ble_widget.sh

#########
# alias #
#########
alias vim='nvim'
alias vz='vim ~/.config/bash/.bashrc'
alias vt='vim ~/.config/tmux/tmux.conf'
alias vnv='vim ~/.config/nvim/init.lua'
alias lg='lazygit'
alias ..='cd ..'
if ls --color=auto -d . >/dev/null 2>&1; then
    alias ls='ls --color=auto'
elif [[ $(uname -s) == Darwin ]]; then
    alias ls='ls -G'
fi
alias ll='ls -lh'
alias la='ls -lah'
alias l='ls'

alias ccc='CLAUDE_CODE_NO_FLICKER=1 claude --dangerously-skip-permissions'
alias cc='claude --dangerously-skip-permissions'
alias pi-bolt="SSH_CONNECTION=1 pi-bolt"

export EDITOR="nvim"

ta() {
    if ! command -v tmux &> /dev/null; then
        echo "錯誤：未找到 'tmux' 命令。"
        return 1
    fi
    if [[ -z "$(tmux ls 2>/dev/null)" ]]; then
        tmux new -s "HOME" -c "$HOME"
    else
        tmux attach -t "$(tmux list-sessions -F '#{session_activity} #{session_name}' | grep -v ' popup$' | sort -rn | head -n 1 | cut -d' ' -f2)"
    fi
}
ha() {
  # Last moment we still own the real terminal: re-ask it whether it is light
  # or dark, so attaching picks up a theme changed since the last login. Inside
  # herdr nothing can ask any more — it never answers the query in a pane.
  _term_appearance_probe
  _yazi_theme_sync
  herdr
}

# open <path>  — open a file/dir with the handler that suits where the terminal
# actually is: local WSL -> Windows, over ssh -> stay in the terminal.
# Defaults to the current dir.
open() {
  # Delegates to smart-open.sh so the shell and yazi agree on the handler, and
  # so an ssh session stops popping windows on the WSL host. See that script.
  "$HOME"/.config/leon_scripts/smart-open.sh "${@:-.}"
}

# Cache eval output — only regenerate when binary changes
_cached_eval() {
    local name="$1" bin="$2"; shift 2
    local cache="$HOME/.cache/bash_init/${name}.sh"
    local bin_path
    # support both full path and command name. `hash` + BASH_CMDS resolves it
    # without forking; no realpath needed since -nt below follows symlinks.
    if [[ "$bin" == /* ]]; then
        bin_path="$bin"
    else
        hash "$bin" 2>/dev/null || return
        bin_path=${BASH_CMDS[$bin]}
    fi
    [[ -x "$bin_path" ]] || return
    [[ -d "$HOME/.cache/bash_init" ]] || mkdir -p "$HOME/.cache/bash_init"
    # Regenerate when missing, empty, or older than the binary. Write to a temp
    # file and only keep a successful, non-empty result: an init that failed
    # once (e.g. binary mid-upgrade) used to leave a 0-byte cache that was
    # "newer" than the binary and silently disabled the tool for good.
    if [[ ! -s "$cache" || "$bin_path" -nt "$cache" ]]; then
        if "$@" > "$cache.tmp" 2>/dev/null && [[ -s "$cache.tmp" ]]; then
            mv -f "$cache.tmp" "$cache"
        else
            rm -f "$cache.tmp"
            eval "$("$@" 2>/dev/null)"
            return
        fi
    fi
    source "$cache"
}

# Not cached: `mise activate` bakes the *current* PATH (and, in a shell nested
# in another mise-activated one, an undo of the parent's env) into its output,
# so a cached copy would reset every new shell's PATH to a stale snapshot.
# It only costs ~5ms; the expensive part is the hook-env it runs anyway.
[[ -x "$HOME/.local/bin/mise" ]] && eval "$("$HOME/.local/bin/mise" activate bash)"
# ^^^ packages installed by mise must come after this line

# herdr-assistant-resurrect: in a pane restored after reboot, resume its agent.
# restore-check.sh matches this pane to a saved session and, once per boot, emits
# `RESUME <argv>` which we exec (claude --resume <id>). No-op otherwise; disable
# with HERDR_NO_RESURRECT=1.
# Retired in favour of herdr's native [session] resume_agents_on_restore, which
# brought back 14/14 claude panes on the same session id across a real server
# restart. The one thing native loses is argv: agents return as plain
# `claude --resume <id>`, without --dangerously-skip-permissions. Accepted —
# re-launching with the flag is cheaper than keeping this path alive.
# Delete the next line to bring the DIY resume back.
export HERDR_NO_RESURRECT=1
if [[ $- == *i* ]] && [[ -n "${HERDR_ENV:-}" && -z "${HERDR_NO_RESURRECT:-}" ]]; then
  _hr_out="$("$HOME/.config/herdr/scripts/resurrect/restore-check.sh" 2>/dev/null || true)"
  [[ "$_hr_out" == RESUME\ * ]] && eval "exec ${_hr_out#RESUME }"
  unset _hr_out
fi

# mise: 每天自動 self-update（背景執行，不阻塞開 shell；同一天多個 shell 只跑一次）
_mise_daily_update() {
    local stamp="$HOME/.cache/mise/last_self_update" today last
    printf -v today '%(%Y-%m-%d)T' -1
    [[ -d "$HOME/.cache/mise" ]] || mkdir -p "$HOME/.cache/mise"
    # 今天已檢查過就跳過
    { read -r last <"$stamp"; } 2>/dev/null && [[ $last == "$today" ]] && return
    # 先寫戳記，避免同一天多個 shell 同時觸發
    echo "$today" > "$stamp"
    # 背景更新，只更新 mise 本體（--no-plugins），輸出存到 log
    ( "$HOME/.local/bin/mise" self-update -y --no-plugins \
        >"$HOME/.cache/mise/self_update.log" 2>&1 ) &
    disown 2>/dev/null
}
# mise: 每天背景檢查工具是否有新版（只提醒，不自動升級，避免破壞可重現性）
_mise_outdated_check() {
    local stamp="$HOME/.cache/mise/last_outdated" today last
    printf -v today '%(%Y-%m-%d)T' -1
    [[ -d "$HOME/.cache/mise" ]] || mkdir -p "$HOME/.cache/mise"
    { read -r last <"$stamp"; } 2>/dev/null && [[ $last == "$today" ]] && return
    echo "$today" > "$stamp"
    (
        local notice="$HOME/.cache/mise/notice" out n names
        out=$("$HOME/.local/bin/mise" outdated --no-header 2>/dev/null | grep -v '^[[:space:]]*$')
        [[ -z "$out" ]] && { rm -f "$notice" "$notice.tools"; exit; }  # 全部最新（或 mise 失敗）：清掉舊提示
        n=$(printf '%s\n' "$out" | grep -c .)
        # 記下要升級的工具：不帶參數的 mise upgrade 會把 config 裡每個工具都重新 resolve 一次
        printf '%s\n' "$out" | awk '{print $1}' > "$notice.tools"
        names=$(printf '%s\n' "$out" | awk '{print $1}' | head -6 | paste -sd, - | sed 's/,/, /g')
        (( n > 6 )) && names="$names …"
        echo "$n 個工具可升級: $names（詳情: mise outdated；升級: mise upgrade）" > "$notice"
    ) &
    disown 2>/dev/null
}

# 顯示 mise 過期提示，並互動詢問是否直接升級（預設 Y；Enter 就升級）
_mise_show_notice() {
    local n="$HOME/.cache/mise/notice"
    [[ -r "$n" ]] || return
    printf '\e[35m[mise]\e[m %s\n' "$(cat "$n")"
    rm -f "$n"
    local tools=()
    [[ -r "$n.tools" ]] && mapfile -t tools < "$n.tools"
    rm -f "$n.tools"
    [[ $- == *i* ]] || return                    # 非互動 shell 不詢問
    local ans
    read -r -p $'\e[35m[mise]\e[m 現在升級全部? [Y/n] ' ans
    [[ "$ans" == [nN]* ]] && return              # 只有明確 n/no 才跳過
    "$HOME/.local/bin/mise" upgrade "${tools[@]}"  # 只升級提示裡那幾個（舊版提示沒有清單時退回全部）
}
[[ $- == *i* ]] && command -v mise &>/dev/null && { _mise_show_notice; _mise_daily_update; _mise_outdated_check; }

# ble.sh: 每天偵測 nightly 是否有新版（背景下載 tarball 比對 hash，不同才就地更新）
_blesh_daily_update() {
    local dir="$HOME/.local/share/blesh"
    local stamp="$HOME/.cache/blesh/last_update" today last
    [[ -f "$dir/ble.sh" ]] || return
    printf -v today '%(%Y-%m-%d)T' -1
    [[ -d "$HOME/.cache/blesh" ]] || mkdir -p "$HOME/.cache/blesh"
    { read -r last <"$stamp"; } 2>/dev/null && [[ $last == "$today" ]] && return
    echo "$today" > "$stamp"
    (
        local notice="$HOME/.cache/blesh/notice"
        # 目前安裝的版本字串（e.g. 0.4.0-nightly+d69e4d5）
        local cur; cur=$(sed -n 's/.*_ble_init_version=//p' "$dir/ble.sh" | head -1)
        [[ "$cur" == *nightly* ]] || exit          # 只自動更新 nightly 安裝（release 版跳過）
        local tmp; tmp=$(mktemp -d) || exit
        if curl -fsSL --max-time 60 -o "$tmp/ble.tar.xz" \
                https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz \
             && tar xJf "$tmp/ble.tar.xz" -C "$tmp" 2>/dev/null; then
            local new; new=$(sed -n 's/.*_ble_init_version=//p' "$tmp/ble-nightly/ble.sh" | head -1)
            if [[ -n "$new" && "$new" != "$cur" ]]; then
                # 就地覆蓋（cp -a 不刪除既有的 cache.d/ run/）
                cp -a "$tmp/ble-nightly/." "$dir/" \
                    && echo "已更新 $cur -> $new，重開 shell 生效。" > "$notice"
            fi
        fi
        rm -rf "$tmp"
    ) &
    disown 2>/dev/null
}

# 顯示上一次背景更新留下的提示
_blesh_show_notice() {
    local n="$HOME/.cache/blesh/notice"
    [[ -r "$n" ]] && { printf '\e[36m[ble.sh]\e[m %s\n' "$(cat "$n")"; rm -f "$n"; }
}
[[ $- == *i* ]] && [[ ${BLE_VERSION-} ]] && command -v curl &>/dev/null && { _blesh_show_notice; _blesh_daily_update; }

# fzf available via mise (no key binding integration — using custom widgets)

# Prompt: starship everywhere, so raw bash / ssh / herdr / tmux all look alike.
# The old branch gated starship on $TMUX/$HERDR_ENV and left plain bash on a
# hand-rolled PS1 whose $(__git_ps1) silently expanded to nothing (git-prompt.sh
# is never sourced here), i.e. no git info at all. Kept only as a real fallback
# for hosts without starship.
if command -v starship >/dev/null 2>&1; then
    _cached_eval starship starship starship init bash
else
    PS1="\[\e[32m\][\w]\[\e[89m\]\$(GIT_PS1_SHOWDIRTYSTATE=1 __git_ps1 2>/dev/null)\[\033[00m\] $ "
fi

_cached_eval zoxide zoxide zoxide init bash
# ble.sh <-> zoxide 整合（讓 z/zi 在 ble.sh 下正常運作；須在 zoxide init 之後）
[[ ${BLE_VERSION-} ]] && ble-import integration/zoxide

# Record what the real terminal answers to an OSC 11 background query, so that
# programs which cannot ask for themselves can still tell light from dark.
# herdr (and tmux) swallow the query inside their panes and never reply —
# verified — so only the login shell, the one attached to the actual terminal,
# can ask. nvim reads this file when it is running inside herdr; outside it,
# nvim asks the terminal itself and ignores the file.
_term_appearance_probe() {
  [[ -t 0 && -t 1 ]] || return 0
  [[ -z ${HERDR_ENV:-} && -z ${TMUX:-} ]] || return 0
  local out=${XDG_RUNTIME_DIR:-/tmp}/term-appearance reply
  # Write the query to the tty directly: read -p sends its prompt to stderr,
  # which is easy to silence by accident, and then nothing ever asks.
  printf '\e]11;?\e\\' >/dev/tty 2>/dev/null || return 0
  IFS= read -rs -d '\\' -t 0.6 reply </dev/tty 2>/dev/null
  printf '%s' "$reply" >"$out.reply"   # keep the raw answer: an empty file here
                                       # means the terminal ignored the query
  [[ $reply =~ rgb:([0-9a-fA-F]+)/([0-9a-fA-F]+)/([0-9a-fA-F]+) ]] || return 0
  local r=$((16#${BASH_REMATCH[1]:0:2})) g=$((16#${BASH_REMATCH[2]:0:2})) b=$((16#${BASH_REMATCH[3]:0:2}))
  # Rec. 709 luma; >50% brightness means a light background.
  if (( (2126*r + 7152*g + 722*b) / 10000 > 127 )); then
    printf 'light\n' >"$out"
  else
    printf 'dark\n' >"$out"
  fi
}
[[ $- == *i* ]] && _term_appearance_probe

# yazi asks the terminal with OSC 11 too, and applies no flavor at all when it
# gets no answer — which is every herdr pane. Its theme.toml is applied
# unconditionally though, so it is a symlink to one of two generated full
# themes (leon_scripts/yazi-theme-gen.sh) and we point it at the right one.
# Runs in every interactive shell so the link also appears on a fresh machine.
_yazi_theme_sync() {
  local link=$HOME/.config/yazi/theme.toml want=theme-dark.toml
  [[ -d ${link%/*} ]] || return 0
  local appearance=
  { read -r appearance <"${XDG_RUNTIME_DIR:-/tmp}/term-appearance"; } 2>/dev/null
  [[ $appearance == light ]] && want=theme-light.toml
  [[ $(readlink "$link" 2>/dev/null) == "$want" ]] || ln -sfn "$want" "$link" 2>/dev/null
}
[[ $- == *i* ]] && _yazi_theme_sync

# Not every terminal answers the OSC 11 query (Windows Terminal is a common
# one that does not), and then nothing above can tell light from dark. Set it
# by hand: `appearance light` / `appearance dark`. A terminal that does answer
# overrides this at the next login shell.
appearance() {
  case ${1:-} in
  auto)
    _term_appearance_probe && _yazi_theme_sync
    printf 'appearance: %s\n' "$(cat "${XDG_RUNTIME_DIR:-/tmp}/term-appearance" 2>/dev/null || echo 'terminal did not answer')"
    ;;
  light | dark)
    printf '%s\n' "$1" >"${XDG_RUNTIME_DIR:-/tmp}/term-appearance"
    _yazi_theme_sync
    printf 'appearance: %s (reopen yazi/nvim to pick it up)\n' "$1"
    ;;
  *)
    printf 'appearance: %s\n' "$(cat "${XDG_RUNTIME_DIR:-/tmp}/term-appearance" 2>/dev/null || echo 'unset — terminal never answered; use: appearance light|dark|auto')"
    ;;
  esac
}


# Check the remote in the background, never pull automatically. The prompt hook
# displays a cached result once per remote commit (including in ble.sh).
_dotfiles_update_notice() {
    local repo="${XDG_CONFIG_HOME:-$HOME/.config}" remote interval
    local cache="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-update/origin-main"
    [[ ${DOTFILES_UPDATE_CHECK:-1} != 0 && -d "$repo/.git" ]] || return 0
    if (( SECONDS >= ${_dotfiles_next_check:-0} )); then
        interval=${DOTFILES_UPDATE_INTERVAL:-3600}
        [[ $interval =~ ^[0-9]+$ ]] || interval=3600
        interval=$((10#$interval))
        # Clamp the shell-side schedule so a zero TTL does not spawn a process
        # at every prompt; the worker still enforces its own cache TTL.
        (( interval < 60 )) && interval=60
        _dotfiles_next_check=$((SECONDS + interval))
        bash "$repo/leon_scripts/dotfiles-update-check.sh" </dev/null >/dev/null 2>&1 &
        # Remove the worker from the job table to suppress completion notices.
        disown "$!" 2>/dev/null
    fi
    [[ -r "$cache" ]] || return 0
    IFS= read -r remote < "$cache" || return 0
    [[ $remote =~ ^[[:xdigit:]]{40}([[:xdigit:]]{24})?$ ]] || return 0
    [[ $remote != "${_dotfiles_checked_remote:-}" ]] || return 0
    _dotfiles_checked_remote=$remote
    # If the remote commit is already an ancestor, this device is current or
    # ahead. An unknown commit is treated as a possible update, not fetched.
    if ! git -C "$repo" merge-base --is-ancestor "$remote" HEAD 2>/dev/null; then
        printf '\n[dotfiles] origin/main 有新版本或已分歧；請先檢查 git status，再 fetch / pull。\n'
        printf '  cd "%s" && git fetch origin && git status -sb\n\n' "$repo"
    fi
}
if [[ ${DOTFILES_UPDATE_CHECK:-1} != 0 && -r "${XDG_CONFIG_HOME:-$HOME/.config}/leon_scripts/dotfiles-update-check.sh" ]]; then
    if [[ ${PROMPT_COMMAND@a} == *a* ]]; then
        PROMPT_COMMAND+=(_dotfiles_update_notice)
    else
        PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}_dotfiles_update_notice"
    fi
fi

# Prompt -> ble.sh status line, PS1 -> "> ". Must come before ble-attach; see
# the header of ble_statusline.sh for why.
[[ ${BLE_VERSION-} ]] && source ~/.config/bash/ble_statusline.sh

# Add this line at the end of .bashrc:
[[ ! ${BLE_VERSION-} ]] || ble-attach

# atuin: cached like the others. (Loading it before ble-attach was measured too:
# no gain, its binding cost just moves into ble-attach.)
_cached_eval atuin atuin atuin init bash --disable-up-arrow
# atuin's ble.sh auto-suggest source runs `atuin search` (50-90ms) in a plain
# $(...), so every keystroke typed meanwhile waits for it. Same source, but via
# conditional-sync: the search is killed as soon as a key arrives.
if [[ ${BLE_VERSION-} ]] && declare -F __atuin_history >/dev/null; then
    function ble/complete/auto-complete/source:atuin-history {
        local suggestion
        ble/util/assign suggestion '
            ble/util/conditional-sync \
                "ATUIN_QUERY=\$_ble_edit_str exec atuin search --cmd-only --limit 1 --search-mode prefix" \
                "! ble/decode/has-input" 32 progressive-weight' 2>/dev/null || return 1
        [[ $suggestion == "$_ble_edit_str"?* ]] || return 1
        ble/complete/auto-complete/enter h 0 "${suggestion:${#_ble_edit_str}}" '' "$suggestion"
    }
fi

# atuin AI: `atuin init` 只把 ? 綁在 emacs keymap，這裡補上 vi-insert，
# 之後若切到 ble.sh 的 vi keymap 也能用。vi_nmap 的 ? 是往回搜尋，保留不動。
if declare -F _atuin_ai_question_mark &>/dev/null; then
    if [[ ${BLE_VERSION-} ]]; then
        ble-bind -m vi_imap -x '?' _atuin_ai_question_mark
    else
        bind -m vi-insert -x '"?": _atuin_ai_question_mark'
    fi
fi

source ~/.config/bash/lscolors.sh
source ~/.config/bash/git-completion.bash
source ~/.config/bash/git_alias.sh
source ~/.config/bash/extract.sh

# Homebrew（跨平台：macOS Apple Silicon / Intel / Linuxbrew，找到才載入）
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew \
             /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
    [[ -x "$_brew" ]] && { eval "$("$_brew" shellenv)"; break; }
done
unset _brew

# Use Homebrew coreutils if already installed; mise remains the tool manager.
for _gnubin in /opt/homebrew/opt/coreutils/libexec/gnubin /usr/local/opt/coreutils/libexec/gnubin; do
    [[ -d "$_gnubin" ]] && { export PATH="$_gnubin:$PATH"; break; }
done
unset _gnubin

export PATH="$HOME/.config/leon_scripts/:$PATH"
export EDITOR='nvim'
export PAGER='less'
export LESS='--mouse --wheel-lines=3'
export PYTHONBREAKPOINT="ipdb.set_trace"

# nnn: ; p toggles the preview-tui pane (patched to split herdr panes)
export NNN_FIFO="/tmp/nnn.fifo"
export NNN_PLUG='p:preview-tui'
export NNN_BATTHEME='ansi'

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# keymap_vi_mode_string_nmap 定義在 blesh 的 lib/keymap.vi.sh，只有 vi keymap
# 真的載入後才存在。目前是 emacs keymap，直接設會噴 `option not found`，
# 所以延後到 vi keymap 載入時才套用。
_my_vi_nmap_string=$'\e[1m-- NORMAL --\e[m'
[[ ${BLE_VERSION-} ]] && blehook/eval-after-load keymap_vi 'bleopt keymap_vi_mode_string_nmap="$_my_vi_nmap_string"'

# herdr session switcher (detach-loop launcher: pick/new/delete/rename -> attach)
alias hs='~/.config/herdr/scripts/herdr_sessions.sh'

# broot's launcher is optional and generated locally by broot.
_broot_launcher="${XDG_CONFIG_HOME:-$HOME/.config}/broot/launcher/bash/br"
[[ -r "$_broot_launcher" ]] && source "$_broot_launcher"
unset _broot_launcher

# User-local tools (these directories may not exist on every machine).
export PATH="$HOME/.opencode/bin:$HOME/.ocv/bin:$HOME/.local/bin:$PATH"
# herdr thin client -> 遠端 herdr server（走 ~/.ssh/config 的 Host 名稱）。
# 第一次連會問要不要在遠端裝相同版本的 herdr binary，答 y 即可。
alias hleon='herdr --remote leon'
alias hgx10='herdr --remote gx10'

# Google Cloud CLI (dedicated venv: py3.14 + grpcio, needed by `gcloud beta interactive`)
export CLOUDSDK_PYTHON="$HOME/.local/share/gcloud-venv/bin/python"
export CLOUDSDK_PYTHON_SITEPACKAGES=1
[[ -f "$HOME/google-cloud-sdk/path.bash.inc" ]] && source "$HOME/google-cloud-sdk/path.bash.inc"
[[ -f "$HOME/google-cloud-sdk/completion.bash.inc" ]] && source "$HOME/google-cloud-sdk/completion.bash.inc"
