#!/bin/bash

repo() {
    # 設定你的專案主目錄，預設為家目錄下的 Projects，如果沒有傳入參數的話
    local search_dir="${1:-$HOME}" 
    local target_dir
    
    # 尋找所有隱藏的 .git 資料夾，並回傳其父目錄，最後交由 fzf 選擇
    target_dir=$(fd --hidden --exclude '.claude' --exclude '.cache' --exclude '.cargo' --exclude '.local' --type d '^\.git$' "$search_dir" -x echo {//} | \
                 fzf --prompt="📂 Select Repo> " \
                     --height=40% \
                     --layout=reverse \
                     --border \
                     --info=inline)
    
    # 如果有選中目標，則切換過去
    if [[ -n "$target_dir" ]]; then
        cd "$target_dir" || return
        echo "✅ 已切換至: $target_dir"
    else
        echo "❌ 取消操作"
    fi
}

repo
