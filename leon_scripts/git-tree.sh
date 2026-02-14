function git-tree() {
    # 1. 組合所有變更的檔案路徑
    #    - (git ls-files -m): 已修改 (unstaged)
    #    - (git ls-files -o --exclude-standard): 未追蹤 (untracked)，但尊重 .gitignore
    #    - (git diff --name-only --cached): 已暫存 (staged)
    # 2. sort -u: 排序並移除重複項
    # 3. tree --fromfile .: 
    #    tree 從標準輸入(.)讀取檔案列表，並只顯示那些檔案
    
    # ( \
    #     git ls-files -m; \
    #     git ls-files -o --exclude-standard; \
    #     git diff --name-only --cached; \
    # ) | sort -u 
    # ) | sort -u | tree -C --fromfile .
	git status --porcelain=v1 | awk '
    {
        # $1 是狀態 (例如 "M ", "??", "A ")
        # $2 是檔案路徑
        status = $1
        path = $2
        
        # 處理重新命名 (例如 "R  old -> new")
        if (status == "R") {
            # $3 是 "->", $4 是新路徑
            path = $4
        }
        
        # 設定自訂標記
        marker = "?"
        if (status == "M " || status == " M") marker = "M"  # 修改
        if (status == "A " || status == " A") marker = "A"  # 新增 (已暫存)
        if (status == "??") marker = "N"  # 新增 (未追蹤)
        if (status == "D " || status == " D") marker = "D"  # 刪除
        if (status == "R " || status == " R") marker = "R"  # 重新命名
        
        # 輸出格式化結果
        printf "(%s) \033[33m%s\033[0m\n", marker, path
    }
    ' | sort
}

