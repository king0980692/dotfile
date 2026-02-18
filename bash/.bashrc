# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Locale (required by ble.sh)
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# Disable bash history (using zsh-histdb as the single source of truth)
export HISTFILE=/dev/null
export HISTSIZE=0

#####################################################################

[[ $- == *i* ]] && source -- ~/.local/share/blesh/ble.sh --noattach

source ~/.config/bash/ble_config.sh
source ~/.config/bash/ble_widget.sh

ble/complete/auto-complete/source:atuin-history() { :; }

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

export EDITOR="nvim"

ta() {
    if ! command -v tmux &> /dev/null; then
        echo "錯誤：未找到 'tmux' 命令。"
        return 1
    fi
    if [[ -z "$(tmux ls 2>/dev/null)" ]]; then
        tmux new -s "HOME" -c "$HOME"
    else
        tmux attach -t "$(tmux list-sessions -F '#{session_name}' | grep -v '^popup$' | tail -n 1)"
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

# fzf available via mise (no key binding integration — using custom widgets)

if [ -n "$TMUX" ]; then
    _cached_eval starship starship starship init bash
else
    PS1="\[\e[32m\][\w]\[\e[89m\]\$(GIT_PS1_SHOWDIRTYSTATE=1 __git_ps1 2>/dev/null)\[\033[00m\] $ "
fi

_cached_eval zoxide zoxide zoxide init bash

# Add this line at the end of .bashrc:
[[ ! ${BLE_VERSION-} ]] || ble-attach

command -v atuin &>/dev/null && eval "$(atuin init bash --disable-up-arrow)"

source ~/.config/bash/lscolors.sh
source ~/.config/bash/git-completion.bash
source ~/.config/bash/git_alias.sh
source ~/.config/bash/extract.sh

# GNU coreutils (for ls --color and other GNU tools)
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"

export PATH="$HOME/.config/leon_scripts/:$PATH"
export EDITOR='nvim'
export PAGER='less'
export PYTHONBREAKPOINT="ipdb.set_trace"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
