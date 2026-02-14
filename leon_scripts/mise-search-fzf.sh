#!/bin/bash

# 獲取腳本目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_TOOL_SCRIPT="$SCRIPT_DIR/check-mise-tool.sh"
TOOL_INFO_SCRIPT="$SCRIPT_DIR/mise-tool-info.sh"
TOOL_ACTION_SCRIPT="$SCRIPT_DIR/mise-tool-action.sh"

# 檢查必要的腳本是否存在
if [ ! -x "$CHECK_TOOL_SCRIPT" ]; then
  echo "錯誤: 找不到 check-mise-tool.sh 或沒有執行權限"
  echo "請確保 check-mise-tool.sh 在同一目錄下並且可執行"
  exit 1
fi

if [ ! -x "$TOOL_INFO_SCRIPT" ]; then
  echo "錯誤: 找不到 mise-tool-info.sh 或沒有執行權限"
  echo "請確保 mise-tool-info.sh 在同一目錄下並且可執行"
  exit 1
fi

if [ ! -x "$TOOL_ACTION_SCRIPT" ]; then
  echo "錯誤: 找不到 mise-tool-action.sh 或沒有執行權限"
  echo "請確保 mise-tool-action.sh 在同一目錄下並且可執行"
  exit 1
fi

# 預設 backend (all = 不過濾)
BACKEND_FILE="/tmp/mise-fzf-backend.$$"
echo "all" > "$BACKEND_FILE"

# 預設 status (all = 不過濾安裝狀態)
STATUS_FILE="/tmp/mise-fzf-status.$$"
echo "all" > "$STATUS_FILE"

# 預先獲取所有已安裝的工具列表（只執行一次，大幅提升效能）
INSTALLED_TOOLS_FILE="/tmp/mise-fzf-installed.$$"
mise ls --installed 2>/dev/null | awk '{print $1}' | sort -u > "$INSTALLED_TOOLS_FILE"

# 清理函數
cleanup() {
  rm -f "$BACKEND_FILE" "$STATUS_FILE" "$INSTALLED_TOOLS_FILE"
}
trap cleanup EXIT

# 檢查工具是否已安裝（使用預先載入的列表）
is_tool_installed() {
  local tool=$1
  local tool_short=$tool

  # 移除 backend 前綴
  if [[ "$tool" =~ ^[a-z]+:(.+)$ ]]; then
    tool_short="${BASH_REMATCH[1]}"
  fi

  # 在已安裝列表中查找（完整名稱或短名稱）
  grep -qE "^${tool}$|^${tool_short}$" "$INSTALLED_TOOLS_FILE" 2>/dev/null
}

# 獲取指定 backend 和狀態的工具列表
get_tools() {
  local backend=$1
  local status=$2

  # 先根據 backend 過濾
  local tools
  if [ "$backend" = "all" ]; then
    tools=$(mise registry)
  else
    tools=$(mise registry | awk -v backend="$backend:" '$0 ~ backend {print}')
  fi

  # 再根據安裝狀態過濾
  if [ "$status" = "all" ]; then
    echo "$tools"
  else
    echo "$tools" | while IFS= read -r line; do
      tool=$(echo "$line" | cut -d' ' -f1)

      if [ "$status" = "installed" ] && is_tool_installed "$tool"; then
        echo "$line"
      elif [ "$status" = "uninstalled" ] && ! is_tool_installed "$tool"; then
        echo "$line"
      fi
    done
  fi
}

# 導出變量，供 fzf 子進程使用
export BACKEND_FILE
export STATUS_FILE
export INSTALLED_TOOLS_FILE
export CHECK_TOOL_SCRIPT
export TOOL_INFO_SCRIPT
export -f is_tool_installed
export -f get_tools

# 使用 fzf 選擇工具，按 TAB 切換 backend、CTRL+I 切換安裝狀態
selected=$(get_tools "all" "all" | fzf \
  --delimiter ' ' \
  --with-nth=1 \
   --bind change:first \
  --preview '$TOOL_INFO_SCRIPT $(echo {} | cut -d" " -f1)' \
  --preview-label=" Backend: < All > | Status: < All > " \
  --preview-label-pos=bottom,-2 \
  --preview-window=right:70%:wrap \
  --list-border rounded \
  --bind 'tab:execute-silent(
    current=$(cat '"$STATUS_FILE"');
    case "$current" in
      all)          echo "installed" > '"$STATUS_FILE"' ;;
      installed)    echo "uninstalled" > '"$STATUS_FILE"' ;;
      uninstalled)  echo "all" > '"$STATUS_FILE"' ;;
    esac
  )+reload(get_tools $(cat '"$BACKEND_FILE"') $(cat '"$STATUS_FILE"'))+refresh-preview+transform-preview-label:[[ -f '"$BACKEND_FILE"' ]] && [[ -f '"$STATUS_FILE"' ]] && { backend=$(cat '"$BACKEND_FILE"'); status=$(cat '"$STATUS_FILE"'); b_label=$([ "$backend" = "all" ] && echo "All" || echo "$backend"); s_label=$([ "$status" = "all" ] && echo "All" || ([ "$status" = "installed" ] && echo "Installed" || echo "Uninstalled")); echo " Backend: < $b_label > | Status: < $s_label > "; }' \
  --bind 'btab:execute-silent(
    current=$(cat '"$STATUS_FILE"');
    case "$current" in
      all)          echo "uninstalled" > '"$STATUS_FILE"' ;;
      uninstalled)  echo "installed" > '"$STATUS_FILE"' ;;
      installed)    echo "all" > '"$STATUS_FILE"' ;;
    esac
  )+reload(get_tools $(cat '"$BACKEND_FILE"') $(cat '"$STATUS_FILE"'))+refresh-preview+transform-preview-label:[[ -f '"$BACKEND_FILE"' ]] && [[ -f '"$STATUS_FILE"' ]] && { backend=$(cat '"$BACKEND_FILE"'); status=$(cat '"$STATUS_FILE"'); b_label=$([ "$backend" = "all" ] && echo "All" || echo "$backend"); s_label=$([ "$status" = "all" ] && echo "All" || ([ "$status" = "installed" ] && echo "Installed" || echo "Uninstalled")); echo " Backend: < $b_label > | Status: < $s_label > "; }' \
  --bind 'ctrl-b:execute-silent(
    current=$(cat '"$BACKEND_FILE"');
    case "$current" in
      all)    echo "aqua" > '"$BACKEND_FILE"' ;;
      aqua)   echo "ubi" > '"$BACKEND_FILE"' ;;
      ubi)    echo "asdf" > '"$BACKEND_FILE"' ;;
      asdf)   echo "npm" > '"$BACKEND_FILE"' ;;
      npm)    echo "go" > '"$BACKEND_FILE"' ;;
      go)     echo "cargo" > '"$BACKEND_FILE"' ;;
      cargo)  echo "pipx" > '"$BACKEND_FILE"' ;;
      pipx)   echo "all" > '"$BACKEND_FILE"' ;;
    esac
  )+reload(get_tools $(cat '"$BACKEND_FILE"') $(cat '"$STATUS_FILE"'))+refresh-preview+transform-preview-label:[[ -f '"$BACKEND_FILE"' ]] && [[ -f '"$STATUS_FILE"' ]] && { backend=$(cat '"$BACKEND_FILE"'); status=$(cat '"$STATUS_FILE"'); b_label=$([ "$backend" = "all" ] && echo "All" || echo "$backend"); s_label=$([ "$status" = "all" ] && echo "All" || ([ "$status" = "installed" ] && echo "Installed" || echo "Uninstalled")); echo " Backend: < $b_label > | Status: < $s_label > "; }')

# 如果取消選擇，退出
if [ -z "$selected" ]; then
  exit 0
fi

# 讀取最終選擇的 backend
backend=$(cat "$BACKEND_FILE")
item=$(echo "$selected" | tr -s ' ' | cut -d " " -f 1)

# 調用獨立的 action 腳本處理安裝/移除
"$TOOL_ACTION_SCRIPT" "$item" "$backend"
