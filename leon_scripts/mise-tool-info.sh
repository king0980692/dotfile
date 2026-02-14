#!/bin/bash

# 獲取工具的詳細信息
# 參數: $1 = tool name

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

# 顯示標題
echo -e "${BOLD}${BLUE}工具: ${tool}${NC}"
print_separator

# 移除 backend 前綴以獲取短名稱
tool_short="$tool"
if [[ "$tool" =~ ^[a-z]+:(.+)$ ]]; then
  tool_short="${BASH_REMATCH[1]}"
fi

# 檢查是否已安裝 (檢查完整名稱和短名稱)
installed_info=$(mise ls --installed 2>/dev/null | grep -E "^${tool}\s|^${tool_short}\s" | head -1)

if [ -n "$installed_info" ]; then
  # 已安裝
  echo -e "${GREEN}✓ 已安裝${NC}"
  echo ""

  # 解析安裝信息
  installed_name=$(echo "$installed_info" | awk '{print $1}')
  installed_version=$(echo "$installed_info" | awk '{print $2}')
  install_path=$(echo "$installed_info" | awk '{print $3}')

  echo -e "${BOLD}版本:${NC} ${installed_version}"

  if [ -n "$install_path" ] && [ "$install_path" != "" ]; then
    echo -e "${BOLD}安裝路徑:${NC} ${install_path}"

    # 計算目錄大小
    if [ -d "$install_path" ]; then
      size=$(du -sh "$install_path" 2>/dev/null | cut -f1)
      if [ -n "$size" ]; then
        echo -e "${BOLD}磁碟使用:${NC} ${size}"
      fi

      # 列出主要執行檔
      echo ""
      echo -e "${BOLD}可執行檔:${NC}"
      bin_dir="${install_path}/bin"
      if [ -d "$bin_dir" ]; then
        exe_count=0
        while IFS= read -r exe; do
          if [ -f "$exe" ] && [ -x "$exe" ]; then
            exe_name=$(basename "$exe")
            exe_size=$(ls -lh "$exe" 2>/dev/null | awk '{print $5}')
            echo -e "  ${YELLOW}•${NC} ${exe_name} ${GRAY}(${exe_size})${NC}"
            exe_count=$((exe_count + 1))
            # 限制顯示數量
            if [ $exe_count -ge 10 ]; then
              remaining=$(find "$bin_dir" -type f -executable 2>/dev/null | wc -l)
              remaining=$((remaining - exe_count))
              if [ $remaining -gt 0 ]; then
                echo -e "  ${GRAY}... 還有 ${remaining} 個執行檔${NC}"
              fi
              break
            fi
          fi
        done < <(find "$bin_dir" -type f -executable 2>/dev/null | sort)

        if [ $exe_count -eq 0 ]; then
          echo -e "  ${GRAY}無可執行檔${NC}"
        fi
      else
        # 檢查根目錄下的執行檔
        exe_count=0
        while IFS= read -r exe; do
          if [ -f "$exe" ] && [ -x "$exe" ]; then
            exe_name=$(basename "$exe")
            exe_size=$(ls -lh "$exe" 2>/dev/null | awk '{print $5}')
            echo -e "  ${YELLOW}•${NC} ${exe_name} ${GRAY}(${exe_size})${NC}"
            exe_count=$((exe_count + 1))
            if [ $exe_count -ge 10 ]; then
              break
            fi
          fi
        done < <(find "$install_path" -maxdepth 3 -type f -executable 2>/dev/null | sort)

        if [ $exe_count -eq 0 ]; then
          echo -e "  ${GRAY}無可執行檔${NC}"
        fi
      fi
    fi
  fi


else
  # 未安裝
  echo -e "${RED}✗ 未安裝${NC}"
  echo ""

  # 嘗試獲取工具的描述信息
  registry_info=$(mise registry | grep "^${tool}\s" | head -1)
  if [ -n "$registry_info" ]; then
    description=$(echo "$registry_info" | cut -d' ' -f2- | tr " " "\n"  | sed ':a;N;s/^\n*//;ta'| sed 's/^\([^:]*\):\(.*\)/[\1] \2/')
    if [ -n "$description" ]; then
      echo -e "${BOLD}描述:${NC}"
      echo -e "\n${description}"
      echo ""
    fi
  fi

fi

print_separator
