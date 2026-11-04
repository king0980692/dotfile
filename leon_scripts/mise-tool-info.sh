#!/bin/bash

# 獲取工具的詳細信息
# 用法: mise-tool-info.sh [--no-header] <tool name>
#   --no-header  不顯示標題與描述 (mise-search-fzf.sh 已在其他區塊顯示)

source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/mise-tool-common.sh"
show_header=true
if [ "$1" = "--no-header" ]; then
  show_header=false
  shift
fi

tool="$1"

if [ -z "$tool" ]; then
  echo "錯誤: 未提供工具名稱"
  exit 1
fi

# 顏色定義
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 分隔線
print_separator() {
  echo -e "${GRAY}────────────────────────────────────────${NC}"
}

if $show_header; then
  # 顯示標題
  echo -e "${BOLD}${BLUE}工具: ${tool}${NC}"

  # 描述來自 registry (mise tool --description 對很多工具只回傳 [none])
  description=$(mise registry --json "$tool" 2>/dev/null | jq -r 'if type == "array" then .[0].description // empty else .description // empty end' 2>/dev/null)
  if [ -n "$description" ]; then
    echo -e "${BOLD}描述:${NC} ${description}"
  fi
  print_separator
fi

# 移除 backend 前綴以獲取短名稱
tool_short="$tool"
if [[ "$tool" =~ ^[a-z]+:(.+)$ ]]; then
  tool_short="${BASH_REMATCH[1]}"
fi

# 透過 registry 的精確 backend spec 比對；預覽優先使用 widget 快取。
matches=$(mise_matching_installed "$tool")
installed_names=$(awk 'NF && !seen[$1]++ {print $1}' <<< "$matches")
if [ "$(grep -c . <<< "$installed_names")" -gt 1 ]; then
  echo -e "${YELLOW}⚠ 多個已安裝的 backend，請明確指定：${NC}"
  printf '%s\n' "$installed_names"
  exit 0
fi
installed_info=$(awk 'NF {line=$0} END {print line}' <<< "$matches")

if [ -n "$installed_info" ]; then
  # 已安裝
  echo -e "${GREEN}✓ 已安裝${NC}"
  echo ""

  # 解析安裝信息
  installed_name=$(echo "$installed_info" | awk '{print $1}')
  installed_version=$(echo "$installed_info" | awk '{print $2}')
  # mise ls 的第三欄是配置來源而非安裝路徑，安裝路徑要問 mise where
  config_source=$(echo "$installed_info" | grep -oE '[~/][^ ]*(\.toml|\.tool-versions)')
  install_path=$(mise where "${installed_name}@${installed_version}" 2>/dev/null)

  echo -e "${BOLD}名稱:${NC} ${installed_name}"
  echo -e "${BOLD}版本:${NC} ${installed_version}"
  if [ -n "$config_source" ]; then
    echo -e "${BOLD}配置來源:${NC} ${config_source}"
  fi

  if [ -d "$install_path" ]; then
    echo -e "${BOLD}安裝路徑:${NC} ${install_path/#$HOME/\~}"

    # 列出主要執行檔 (優先找 bin/，否則從安裝目錄往下找)
    echo ""
    echo -e "${BOLD}可執行檔:${NC}"
    if [ -d "${install_path}/bin" ]; then
      mapfile -t exes < <(find -L "${install_path}/bin" -maxdepth 1 -type f -executable 2>/dev/null | sort)
    else
      mapfile -t exes < <(find -L "$install_path" -maxdepth 3 -type f -executable 2>/dev/null | sort)
    fi

    # 限制顯示數量
    max_exes=10
    for exe in "${exes[@]:0:$max_exes}"; do
      echo -e "  ${YELLOW}•${NC} $(basename "$exe")"
    done

    if [ ${#exes[@]} -eq 0 ]; then
      echo -e "  ${GRAY}無可執行檔${NC}"
    elif [ ${#exes[@]} -gt $max_exes ]; then
      echo -e "  ${GRAY}... 還有 $((${#exes[@]} - max_exes)) 個執行檔${NC}"
    fi
  fi

else
  # 未安裝
  echo -e "${RED}✗ 未安裝${NC}"
fi

# 列出可用的 backend
# 優先讀 mise-search-fzf.sh 的快取，避免每次預覽都重跑 mise registry
if [ -r "$MISE_FZF_STATE/registry" ]; then
  registry=$(<"$MISE_FZF_STATE/registry")
else
  registry=$(mise registry 2>/dev/null)
fi

# 每個 backend 一行: aqua:openai/codex -> [aqua] openai/codex
backends=$(echo "$registry" | awk -v t="$tool" '
  $1 == t {
    for (i = 2; i <= NF; i++) {
      sep = index($i, ":")
      printf "  [%s] %s\n", substr($i, 1, sep - 1), substr($i, sep + 1)
    }
    exit
  }')
if [ -n "$backends" ]; then
  echo ""
  echo -e "${BOLD}可用 Backend:${NC}"
  echo "$backends"
fi

if $show_header; then
  print_separator
fi
