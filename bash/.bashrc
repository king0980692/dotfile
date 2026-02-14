# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

#####################################################################

# Add this lines at the top of .bashrc:
[[ $- == *i* ]] && source -- ~/.local/share/blesh/ble.sh --noattach
# your bashrc settings come here...

source ~/.config/bash/ble_config.sh
source ~/.config/bash/ble_widget.sh

ble/complete/auto-complete/source:atuin-history() { :; }



# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
fi




#########
# alias #
#########
# alias v='nvim'
alias vim='nvim'

alias vz='vim ~/.config/bash/.bashrc'
alias vt='vim ~/.config/tmux/tmux.conf'
alias vnv='vim ~/.config/nvim/init.lua'
alias lg='lazygit'
alias ..='cd ..'
alias ll='ls -l'
alias la='ls -al'
alias l='ls '


export EDITOR="nvim"

ta() {
    # 1. 檢查是否有 tmux 伺服器正在執行
    if ! command -v tmux &> /dev/null; then
        echo "錯誤：未找到 'tmux' 命令。請先安裝 tmux。"
        return 1
    fi

    # 檢查是否有任何 tmux 伺服器在運行
    if [[ -z "$(tmux ls 2>/dev/null)" ]]; then
	# 沒有伺服器在執行
        SESSION_NAME="HOME"
        tmux new -s "$SESSION_NAME" -c "$HOME"
    else
        # 附加到伺服器中的最後一個會話
		tmux attach -t "$(tmux list-sessions -F '#{session_name}' | grep -v '^popup$' | tail -n 1)"
    fi
}


eval "$(/home/lychang/.local/bin/mise activate bash)"
# be ware the package installed by mise, need put after here


if [ -n "$TMUX" ]; then
  command -v starship &>/dev/null && eval "$(starship init bash)"
else
  PS1="\[\e[32m\][\w]\[\e[89m\]\$(GIT_PS1_SHOWDIRTYSTATE=1 __git_ps1 2>/dev/null)\[\033[00m\] $ "
fi

command -v zoxide &>/dev/null && eval "$(zoxide init bash)"



# Add this line at the end of .bashrc:
[[ ! ${BLE_VERSION-} ]] || ble-attach

command -v atuin &>/dev/null && eval "$(atuin init bash --disable-up-arrow)"



source ~/.config/bash/lscolors.sh
source ~/.config/bash/git-completion.bash
source ~/.config/bash/git_alias.sh
source ~/.config/bash/extract.sh

export PATH="/home/lychang/.config/leon_scripts/:$PATH"
export EDITOR='nvim'
export PAGER='ov'
export PYTHONBREAKPOINT="ipdb.set_trace"



bleopt keymap_vi_mode_string_nmap=$'\e[1m-- NORMAL --\e[m'
# bleopt keymap_vi_mode_name_insert=$'\e[1;mINSERT\e[m'



# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# opencode
export PATH=/home/lychang/.opencode/bin:$PATH

source ~/.config/leon_scripts/fzf_walk.sh

function open() {
  if [[ "$1" == "" ]]; then
    Explorer.exe .
  else
    # Handle Windows paths correctly
    Explorer.exe ${1//\\//\\\\}
  fi
}
export -f open

if ! pgrep -x "sleep" > /dev/null; then
    nohup sleep infinity > /dev/null 2>&1 &
fi
