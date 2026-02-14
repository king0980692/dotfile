#!/bin/bash

# 處理工具的安裝/移除操作
# 參數: $1 = tool name, $2 = backend

tool="$1"
backend="$2"

if [ -z "$tool" ]; then
  echo "錯誤: 未提供工具名稱"
  exit 1
fi

# 檢查 gum 是否可用
if ! command -v gum &> /dev/null; then
  echo "錯誤: 需要安裝 gum 才能使用此功能"
  echo "請執行: mise use -g gum"
  exit 1
fi

# 移除 backend 前綴以獲取短名稱
tool_short="$tool"
if [[ "$tool" =~ ^[a-z]+:(.+)$ ]]; then
  tool_short="${BASH_REMATCH[1]}"
fi

# 檢查是否已安裝
installed_info=$(mise ls --installed 2>/dev/null | grep -E "^${tool}\s|^${tool_short}\s" | head -1)

if [ -n "$installed_info" ]; then
  # 已安裝 - 詢問是否移除
  installed_name=$(echo "$installed_info" | awk '{print $1}')
  installed_version=$(echo "$installed_info" | awk '{print $2}')

  echo ''
  gum style \
    --border rounded \
    --padding "0 1" \
    --border-foreground 212 \
    "工具: $(gum style --foreground 212 --bold "$installed_name")" \
    "版本: $(gum style --foreground 177 "$installed_version")" \
    "狀態: $(gum style --foreground 46 "已安裝")"

  if gum confirm "確認要移除 $installed_name 嗎?"; then
    gum spin --spinner dot --title "正在移除 $installed_name..." -- mise uninstall "$installed_name"

    # 檢查是否移除成功
    if [ $? -eq 0 ]; then
      gum style --foreground 212 "✓ 移除完成！"

      # 直接從全局配置中移除
      if mise ls --global 2>/dev/null | grep -qE "^${installed_name}\s|^${tool_short}\s"; then
        mise use -g --rm "$installed_name" 2>/dev/null || mise use -g --rm "$tool_short" 2>/dev/null
        if [ $? -eq 0 ]; then
          gum style --foreground 212 "✓ 已從全局配置移除"
        fi
      fi
      exit 0
    else
      gum style --foreground 196 "✗ 移除失敗"
      exit 1
    fi
  else
    gum style --foreground 241 "已取消移除"
    exit 0
  fi

else
  # 未安裝 - 啟動安裝程序

  # 獲取工具描述
  registry_info=$(mise registry | grep "^${tool}\s" | head -1)
  description=$(echo "$registry_info" | cut -d' ' -f2- | tr -d " ")

  echo ''
  gum style \
    --border rounded \
    --padding "0 1" \
    --border-foreground 212 \
    "工具: $(gum style --foreground 212 --bold "$tool")" \
    "Backend: $(gum style --foreground 177 "$backend")" \
    "描述: ${description}" \
    "狀態: $(gum style --foreground 196 "未安裝")"

  # 步驟 1: 詢問是否要安裝
  if ! gum confirm "確認要安裝 $tool 嗎?"; then
    gum style --foreground 241 "已取消安裝"
    exit 0
  fi

  # 步驟 2: 是否使用特定版本 (預設否)
  selected_version=""
  if gum confirm --default=false "是否要使用特定版本？(預設: 否，使用最新版)"; then
    gum style --foreground 177 "正在獲取可用版本..."

    # 獲取可用版本列表
    versions=$(mise ls-remote "$tool" 2>/dev/null)

    if [ -n "$versions" ]; then
      selected_version=$(echo "$versions" | gum filter --placeholder "選擇版本...")

      if [ -z "$selected_version" ]; then
        gum style --foreground 241 "已取消安裝"
        exit 0
      fi
    else
      gum style --foreground 196 "無法獲取版本列表，將使用最新版本"
      sleep 1
    fi
  fi

  # 步驟 3: 是否使用特定 backend (預設 auto)
  final_backend="$backend"
  if [ "$backend" = "all" ]; then
    final_backend="auto"
  fi

  if gum confirm --default=false "是否要使用特定 backend？(預設: $final_backend)"; then
    # 提供 backend 選項
    backends=("auto" "aqua" "asdf" "cargo" "go" "npm" "pipx" "ubi")
    selected_backend=$(printf "%s\n" "${backends[@]}" | gum filter --placeholder "選擇 backend...")

    if [ -z "$selected_backend" ]; then
      gum style --foreground 241 "已取消安裝"
      exit 0
    fi

    final_backend="$selected_backend"
  fi

  # 執行安裝

  # 構建安裝命令
  if [ -n "$selected_version" ]; then
    install_target="$tool@$selected_version"
    display_name="$tool@$selected_version"
  else
    install_target="$tool"
    display_name="$tool"
  fi

  if [ "$final_backend" = "auto" ]; then
    gum spin --spinner dot --title "正在安裝 $display_name (由 mise 自動選擇 backend)..." -- mise use -g "$install_target"
  else
    gum spin --spinner dot --title "正在安裝 $display_name (backend: $final_backend)..." -- mise use -g "$final_backend:$install_target"
  fi

  if [ $? -eq 0 ]; then
    # 重新生成 shims
    mise reshim 2>/dev/null

    gum style --foreground 212 "✓ 安裝完成！"
    # 顯示安裝後的信息
    installed_info=$(mise ls --installed 2>/dev/null | grep -E "^${tool}\s|^${tool_short}\s" | head -1)
    if [ -n "$installed_info" ]; then
      installed_name=$(echo "$installed_info" | awk '{print $1}')
      installed_version=$(echo "$installed_info" | awk '{print $2}')
      # 使用 mise which 獲取正確的 binary 路徑
      install_path=$(mise which "$installed_name" 2>/dev/null || mise which "$tool_short" 2>/dev/null)
      if [ -z "$install_path" ]; then
        # fallback: 從安裝目錄的 bin 下查找
        install_dir=$(echo "$installed_info" | awk '{print $3}')
        if [ -d "$install_dir/bin" ]; then
          install_path=$(find "$install_dir/bin" -type f -executable 2>/dev/null | head -1)
        fi
      fi
      gum style \
        --border rounded \
        --padding "0 1" \
        --border-foreground 46 \
        "已安裝版本: $(gum style --foreground 46 --bold "$installed_version")" \
        "執行檔路徑: ${install_path:-未知}"

      # 詢問是否重啟 shell 以套用變更
      echo ""
      if gum confirm --default=true "是否重啟 shell 以立即使用 $tool_short？"; then
        exec $SHELL
      else
        gum style --foreground 241 "提示: 執行 'exec \$SHELL' 或開新終端機以使用 $tool_short"
      fi
    fi
  else
    gum style --foreground 196 "✗ 安裝失敗"
    exit 1
  fi
fi

exit 0
