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
alias ls='ls --color=auto'
alias ll='ls -lh'
alias la='ls -lah'
alias l='ls'

alias ccc='CLAUDE_CODE_NO_FLICKER=1 claude --dangerously-skip-permissions'

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
  herdr
}

# Cache eval output — only regenerate when binary changes
_cached_eval() {
    local name="$1" bin="$2"; shift 2
    local cache="$HOME/.cache/bash_init/${name}.sh"
    local bin_path
    # support both full path and command name
    if [[ "$bin" == /* ]]; then
        bin_path="$bin"
    else
        bin_path=$(command -v "$bin" 2>/dev/null) || return
        bin_path=$(realpath "$bin_path" 2>/dev/null || echo "$bin_path")
    fi
    [[ -x "$bin_path" ]] || return
    mkdir -p "$HOME/.cache/bash_init"
    if [[ ! -f "$cache" || "$bin_path" -nt "$cache" ]]; then
        "$@" > "$cache" 2>/dev/null
    fi
    source "$cache"
}

_cached_eval mise "$HOME/.local/bin/mise" "$HOME/.local/bin/mise" activate bash
# ^^^ packages installed by mise must come after this line

# herdr-assistant-resurrect: in a pane restored after reboot, resume its agent.
# restore-check.sh matches this pane to a saved session and, once per boot, emits
# `RESUME <argv>` which we exec (claude --resume <id>). No-op otherwise; disable
# with HERDR_NO_RESURRECT=1.
if [[ $- == *i* ]] && [[ -n "${HERDR_ENV:-}" ]]; then
  _hr_out="$("$HOME/.config/herdr/scripts/resurrect/restore-check.sh" 2>/dev/null || true)"
  [[ "$_hr_out" == RESUME\ * ]] && eval "exec ${_hr_out#RESUME }"
  unset _hr_out
fi

# mise: 每天自動 self-update（背景執行，不阻塞開 shell；同一天多個 shell 只跑一次）
_mise_daily_update() {
    local stamp="$HOME/.cache/mise/last_self_update" today
    today=$(date +%Y-%m-%d)
    mkdir -p "$HOME/.cache/mise"
    # 今天已檢查過就跳過
    [[ -r "$stamp" && "$(cat "$stamp" 2>/dev/null)" == "$today" ]] && return
    # 先寫戳記，避免同一天多個 shell 同時觸發
    echo "$today" > "$stamp"
    # 背景更新，只更新 mise 本體（--no-plugins），輸出存到 log
    ( "$HOME/.local/bin/mise" self-update -y --no-plugins \
        >"$HOME/.cache/mise/self_update.log" 2>&1 ) &
    disown 2>/dev/null
}
# mise: 每天背景檢查工具是否有新版（只提醒，不自動升級，避免破壞可重現性）
_mise_outdated_check() {
    local stamp="$HOME/.cache/mise/last_outdated" today
    today=$(date +%Y-%m-%d)
    mkdir -p "$HOME/.cache/mise"
    [[ -r "$stamp" && "$(cat "$stamp" 2>/dev/null)" == "$today" ]] && return
    echo "$today" > "$stamp"
    (
        local notice="$HOME/.cache/mise/notice" out n names
        out=$("$HOME/.local/bin/mise" outdated 2>/dev/null | grep -v '^[[:space:]]*$')
        [[ -z "$out" ]] && { rm -f "$notice"; exit; }        # 全部最新（或 mise 失敗）：清掉舊提示
        n=$(printf '%s\n' "$out" | grep -c .)
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
    [[ $- == *i* ]] || return                    # 非互動 shell 不詢問
    local ans
    read -r -p $'\e[35m[mise]\e[m 現在升級全部? [Y/n] ' ans
    [[ "$ans" == [nN]* ]] && return              # 只有明確 n/no 才跳過
    "$HOME/.local/bin/mise" upgrade
}
[[ $- == *i* ]] && command -v mise &>/dev/null && { _mise_show_notice; _mise_daily_update; _mise_outdated_check; }

# dotfile: 每天偵測遠端是否有更新（背景 fetch，安全不覆蓋本地修改）
_dotfile_daily_sync() {
    local repo="$HOME/.config"
    local stamp="$HOME/.cache/dotfile/last_sync" today
    [[ -d "$repo/.git" ]] || return
    today=$(date +%Y-%m-%d)
    mkdir -p "$HOME/.cache/dotfile"
    [[ -r "$stamp" && "$(cat "$stamp" 2>/dev/null)" == "$today" ]] && return
    echo "$today" > "$stamp"
    (
        # BatchMode 避免 SSH 在背景卡在密碼提示
        GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=10' \
            git -C "$repo" fetch --quiet origin 2>/dev/null || exit
        local L R B notice="$HOME/.cache/dotfile/notice"
        L=$(git -C "$repo" rev-parse @ 2>/dev/null)
        R=$(git -C "$repo" rev-parse '@{u}' 2>/dev/null)
        B=$(git -C "$repo" merge-base @ '@{u}' 2>/dev/null)
        [[ -z "$R" || "$L" == "$R" ]] && exit                    # 沒 upstream 或已最新
        if [[ "$L" == "$B" ]]; then                              # 落後遠端，可 fast-forward
            if [[ -z "$(git -C "$repo" status --porcelain)" ]]; then
                git -C "$repo" pull --ff-only --quiet \
                    && echo "已自動更新到最新，建議重開 shell 生效。" > "$notice"
            else
                echo "遠端有更新，但本機有未提交變更。手動更新: cd ~/.config && git stash && git pull --ff-only && git stash pop" > "$notice"
            fi
        else                                                     # 分歧
            echo "本機與遠端分歧，請手動處理: cd ~/.config && git status" > "$notice"
        fi
    ) &
    disown 2>/dev/null
}

# 顯示上一次背景 sync 留下的提示（在下次開 shell 時）
_dotfile_show_notice() {
    local n="$HOME/.cache/dotfile/notice"
    [[ -r "$n" ]] && { printf '\e[33m[dotfile]\e[m %s\n' "$(cat "$n")"; rm -f "$n"; }
}
[[ $- == *i* ]] && command -v git &>/dev/null && { _dotfile_show_notice; _dotfile_daily_sync; }

# ble.sh: 每天偵測 nightly 是否有新版（背景下載 tarball 比對 hash，不同才就地更新）
_blesh_daily_update() {
    local dir="$HOME/.local/share/blesh"
    local stamp="$HOME/.cache/blesh/last_update" today
    [[ -f "$dir/ble.sh" ]] || return
    today=$(date +%Y-%m-%d)
    mkdir -p "$HOME/.cache/blesh"
    [[ -r "$stamp" && "$(cat "$stamp" 2>/dev/null)" == "$today" ]] && return
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

if [ -n "$TMUX" ] || [ -n "${HERDR_ENV:-}" ]; then
    _cached_eval starship starship starship init bash
else
    PS1="\[\e[32m\][\w]\[\e[89m\]\$(GIT_PS1_SHOWDIRTYSTATE=1 __git_ps1 2>/dev/null)\[\033[00m\] $ "
fi

_cached_eval zoxide zoxide zoxide init bash
# ble.sh <-> zoxide 整合（讓 z/zi 在 ble.sh 下正常運作；須在 zoxide init 之後）
[[ ${BLE_VERSION-} ]] && ble-import integration/zoxide

# Add this line at the end of .bashrc:
[[ ! ${BLE_VERSION-} ]] || ble-attach

command -v atuin &>/dev/null && eval "$(atuin init bash --disable-up-arrow)"

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

# GNU coreutils (for ls --color and other GNU tools)
[[ -d "/opt/homebrew/opt/coreutils/libexec/gnubin" ]] && export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"

export PATH="$HOME/.config/leon_scripts/:$PATH"
export EDITOR='nvim'
export PAGER='less'
export LESS='--mouse --wheel-lines=3'
export PYTHONBREAKPOINT="ipdb.set_trace"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

bleopt keymap_vi_mode_string_nmap=$'\e[1m-- NORMAL --\e[m'

# herdr session switcher (detach-loop launcher: pick/new/delete/rename -> attach)
alias hs='~/.config/herdr/scripts/herdr_sessions.sh'
