#!/usr/bin/env bash

# 設定最大長度（可根據您的需求調整）
# 如果路徑超過這個長度，將會被截斷
MAX_LENGTH=40

# 接收 tmux 傳入的路徑變數作為第一個參數
FULL_PATH="$1"

# 檢查路徑是否超過最大長度
if [ ${#FULL_PATH} -le $MAX_LENGTH ]; then
    # 如果沒有超長，直接輸出完整路徑
    echo "cwd: $FULL_PATH"
    exit 0
fi

# 1. 處理家目錄 (~) 的替換
# 檢查是否以家目錄開頭 (這裡假設家目錄在 $HOME 變數中)
if [[ "$FULL_PATH" == "$HOME"* ]]; then
    # 將 $HOME 替換為 ~，並更新路徑變數
    TRUNCATED_PATH="${FULL_PATH/#$HOME/\~}"
else
    # 否則使用完整路徑
    TRUNCATED_PATH="$FULL_PATH"
fi

# 重新檢查替換後的長度
if [ ${#TRUNCATED_PATH} -le $MAX_LENGTH ]; then
    echo "$TRUNCATED_PATH"
    exit 0
fi

# 2. 核心截斷邏輯 (將中間部分替換為 "...")
# a. 確定要保留的結尾部分長度 (例如：最後 20 個字元)
# b. 確定要保留的開頭部分長度 (例如：開頭 10 個字元)
END_LEN=20
START_LEN=10

# 獲取路徑的開頭部分
START_PART="${TRUNCATED_PATH:0:$START_LEN}"

# 獲取路徑的結尾部分 (從倒數 $END_LEN 的位置開始)
# 注意：Bash 的字串截取從 0 開始，所以要計算正確的起始位置
END_PART_START=$(( ${#TRUNCATED_PATH} - END_LEN ))
END_PART="${TRUNCATED_PATH:$END_PART_START:$END_LEN}"

# 輸出最終的截斷路徑
echo "${START_PART}...${END_PART}"

# 範例輸出：
# 原始路徑：/home/user/my/very/long/project/directory/src/app/index.js
# 截斷後：~/my/very/long/.../src/app/index.js (如果MAX_LENGTH設定更嚴格)
# 我們的腳本輸出：/home/user/m...pp/index.js (長度限制為 40)
