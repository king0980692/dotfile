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
[[ $- == *i* ]] && command -v mise &>/dev/null && _mise_daily_update

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

# fzf available via mise (no key binding integration — using custom widgets)

if [ -n "$TMUX" ]; then
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
