#!/bin/bash

# 檢查 mise 工具的安裝狀態
# 用法: check-mise-tool.sh <tool_name>

# 確保 mise 在 PATH 中
if ! command -v mise &> /dev/null; then
  # 嘗試使用絕對路徑
  export PATH="$HOME/.local/bin:$PATH"
fi

tool="$1"

if [ -z "$tool" ]; then
  echo "provide tool_name"
  exit 1
fi

# 移除 backend 前綴
tool_base="$tool"
tool_short="$tool"

if [[ "$tool" =~ ^[a-z]+:(.+)$ ]]; then
  tool_short="${BASH_REMATCH[1]}"
fi

# 使用 mise ls 檢查是否已安裝
# 正規化名稱比對:backend 全名(如 aqua:openai/codex)也要能對到
# registry 短名(codex)。把已安裝名字拆成 全名 / 去前綴 / basename 三種比。
install_info=$(mise ls --installed 2>/dev/null | awk -v t="$tool_base" -v s="$tool_short" '
  {
    name=$1
    nop=name; sub(/^[a-z]+:/, "", nop)      # 去 backend 前綴: aqua:openai/codex -> openai/codex
    base=nop; sub(/.*\//, "", base)          # basename:            openai/codex -> codex
    if (name==t || nop==t || base==t || name==s || nop==s || base==s) { print; exit }
  }')

if [ -n "$install_info" ]; then
  # 檢查安裝來源
  if echo "$install_info" | grep -q "/mise.toml"; then
    # 檢查是否為當前目錄
    current_dir=$(pwd)
    if echo "$install_info" | grep -qE "\./mise.toml|${current_dir}/mise.toml"; then
      echo "✓ 已安裝 (local)"
    else
      echo "✓ 已安裝 (global)"
    fi
  else
    echo "✓ 已安裝 (global)"
  fi
else
  echo "未安裝"
fi
