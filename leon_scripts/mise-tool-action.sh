#!/bin/bash

# 處理工具的安裝/移除操作
# 參數: $1 = tool name, $2 = backend (all = 由 mise 自動選擇)

source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/mise-tool-common.sh"
tool="$1"
backend="${2:-all}"

if [ -z "$tool" ]; then
  echo "錯誤: 未提供工具名稱"
  exit 1
fi

# 檢查 gum 是否可用
if ! command -v gum &> /dev/null || ! command -v jq &> /dev/null; then
  echo "錯誤: 需要安裝 gum 和 jq 才能使用此功能"
  echo "請執行: mise use -g gum jq"
  exit 1
fi

# 移除 backend 前綴以獲取短名稱
tool_short="$tool"
if [[ "$tool" =~ ^[a-z]+:(.+)$ ]]; then
  tool_short="${BASH_REMATCH[1]}"
fi

# 只比對精確名稱與 registry 登記的 backend spec，避免同名工具誤判。
find_installed_name() {
  mise_matching_installed "$tool" | awk '!seen[$1]++ {print $1}'
}

# 列出指定工具所有已安裝的版本
# 參數: $1 = installed name
installed_versions() {
  COLUMNS=1000 mise ls --installed 2>/dev/null | awk -v n="$1" '$1 == n {print $2}'
}

# 執行 mise 並顯示 spinner，失敗時印出 mise 的錯誤訊息
# 參數: $1 = spinner 標題, $2... = mise 參數
run_mise() {
  local title=$1
  shift
  gum spin --show-error --spinner dot --title "$title" -- mise "$@"
}

mapfile -t installed_names < <(find_installed_name)
if [ "${#installed_names[@]}" -gt 1 ]; then
  printf '錯誤: 找到多個已安裝的 backend，為避免誤刪，請明確指定：\n' >&2
  printf '  %s\n' "${installed_names[@]}" >&2
  exit 1
fi
installed_name=${installed_names[0]:-}

# 描述來自 registry (mise tool --description 對很多工具只回傳 [none])
description=$(mise registry --json "$tool" 2>/dev/null | jq -r 'if type == "array" then .[0].description // empty else .description // empty end' 2>/dev/null)
# registry 沒有的 github:owner/repo 改用 GitHub repo 的描述
if [ -z "$description" ] && [[ "$tool" == github:*/* ]]; then
  description=$(curl -fsSL --max-time 3 "https://api.github.com/repos/${tool#github:}" 2>/dev/null |
    jq -r '.description // empty' 2>/dev/null)
fi
if [ -z "$description" ]; then
  description="無"
fi
# 依終端機寬度折行，避免確認框超出畫面 (扣掉邊框與 "描述: " 前綴)
term_cols=$(tput cols 2> /dev/null || echo 80)
description=$(echo "$description" | fold -s -w $((term_cols > 30 ? term_cols - 12 : 18)) | sed '2,$s/^/      /')

if [ -n "$installed_name" ]; then
  # 已安裝 - 詢問是否移除
  versions=$(installed_versions "$installed_name" | paste -sd ' ')

  echo ''
  gum style \
    --border rounded \
    --padding "0 1" \
    --border-foreground 212 \
    "工具: $(gum style --foreground 212 --bold "$installed_name")" \
    "描述: ${description}" \
    "版本: $(gum style --foreground 177 "$versions")" \
    "狀態: $(gum style --foreground 46 "已安裝")"

  if ! gum confirm "確認要移除 $installed_name 的全部已安裝版本（$versions）嗎？"; then
    gum style --foreground 241 "已取消移除"
    exit 0
  fi

  # 可能裝了多個版本，全部移除
  if ! run_mise "正在移除 $installed_name..." uninstall --all "$installed_name"; then
    gum style --foreground 196 "✗ 移除失敗"
    exit 1
  fi
  gum style --foreground 212 "✓ 移除完成！"

  # 從全局配置中移除，否則 mise 之後會再把它裝回來
  if COLUMNS=1000 mise ls --global 2>/dev/null | awk -v n="$installed_name" '$1 == n {found = 1} END {exit !found}'; then
    if mise use -g --remove "$installed_name" &> /dev/null; then
      gum style --foreground 212 "✓ 已從全局配置移除"
    else
      gum style --foreground 196 "✗ 無法從全局配置移除，請手動執行: mise use -g --remove $installed_name"
      exit 1
    fi
  fi
  exit 0
fi

# 未安裝 - 啟動安裝程序

# registry 中此工具可用的 backend (完整名稱，如 aqua:openai/codex)
mapfile -t tool_backends < <(mise registry 2>/dev/null |
  awk -v t="$tool" '$1 == t {for (i = 2; i <= NF; i++) print $i; exit}')

# 目前 backend 過濾條件對應的完整名稱
install_target="$tool"
for spec in "${tool_backends[@]}"; do
  if [ "${spec%%:*}" = "$backend" ]; then
    install_target="$spec"
    break
  fi
done

echo ''
gum style \
  --border rounded \
  --padding "0 1" \
  --border-foreground 212 \
  "工具: $(gum style --foreground 212 --bold "$tool")" \
  "描述: ${description}" \
  "Backend: $(gum style --foreground 177 "${tool_backends[*]:-$tool}")" \
  "狀態: $(gum style --foreground 196 "未安裝")"

# 步驟 1: 詢問是否要安裝
if ! gum confirm "確認要安裝 $tool 嗎?"; then
  gum style --foreground 241 "已取消安裝"
  exit 0
fi

# 步驟 2: 是否使用特定 backend (先選 backend，版本列表才會對應到正確的來源)
if [ ${#tool_backends[@]} -gt 0 ]; then
  if [ "$install_target" = "$tool" ]; then
    default_label="由 mise 自動選擇"
  else
    default_label="$install_target"
  fi

  if gum confirm --default=false "是否要使用特定 backend？(預設: $default_label)"; then
    selected_backend=$(printf "%s\n" "auto" "${tool_backends[@]}" | gum filter --placeholder "選擇 backend...")

    if [ -z "$selected_backend" ]; then
      gum style --foreground 241 "已取消安裝"
      exit 0
    fi

    if [ "$selected_backend" = "auto" ]; then
      install_target="$tool"
    else
      install_target="$selected_backend"
    fi
  fi
fi

# 步驟 3: 是否使用特定版本 (預設否)
selected_version=""
if gum confirm --default=false "是否要使用特定版本？(預設: 否，使用最新版)"; then
  gum style --foreground 177 "正在獲取可用版本..."

  # 獲取可用版本列表 (新版本在前)
  versions=$(mise ls-remote "$install_target" 2>/dev/null | tac)

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

# 執行安裝
install_spec="$install_target"
if [ -n "$selected_version" ]; then
  install_spec="$install_target@$selected_version"
fi

if ! run_mise "正在安裝 $install_spec..." use -g "$install_spec"; then
  gum style --foreground 196 "✗ 安裝失敗"
  exit 1
fi

# 重新生成 shims
mise reshim 2> /dev/null

gum style --foreground 212 "✓ 安裝完成！"

# 顯示安裝後的信息
install_path=$(mise where "$install_target" 2> /dev/null)
if [ -n "$install_path" ]; then
  gum style \
    --border rounded \
    --padding "0 1" \
    --border-foreground 46 \
    "已安裝版本: $(gum style --foreground 46 --bold "$(basename "$install_path")")" \
    "安裝路徑: $install_path"
fi

# 偵測現有 PATH 中同名指令；只提示，不自動覆蓋或建立連結。
# 新安裝的路徑通常要等下一個 prompt 才會加入 PATH，因此此處可看到原有指令。
if [ -n "$install_path" ] && [ -d "$install_path" ]; then
  while IFS= read -r -d '' exe; do
    exe_name=${exe##*/}
    existing=$(command -v -- "$exe_name" 2>/dev/null) || continue
    # 函式、alias 和內建指令也會遮蔽新執行檔；檔案則比較實際路徑。
    if [ -f "$existing" ] && [ "$(readlink -f -- "$existing")" = "$(readlink -f -- "$exe")" ]; then
      continue
    fi
    # mise shim 本身不是衝突：確認它目前解析到哪個執行檔。
    if [ "$(readlink -f -- "$existing" 2>/dev/null)" = "$(readlink -f -- "$(command -v mise)" 2>/dev/null)" ] &&
      [ "$(mise which "$exe_name" 2>/dev/null)" = "$exe" ]; then
      continue
    fi
    gum style --foreground 214 "⚠ 指令名稱衝突: $exe_name（目前解析為 $existing）"
    gum style --foreground 214 "  新安裝的執行檔: $exe"
    gum style --foreground 241 "  可建立不同名稱的 symlink；請先確認目標名稱不存在，並使用更新後仍有效的路徑。"
  done < <(find -L "$install_path" -maxdepth 1 -type f -executable -print0; \
    if [ -d "$install_path/bin" ]; then find -L "$install_path/bin" -maxdepth 1 -type f -executable -print0; fi)
fi

# mise activate 會在下一個 prompt 更新 PATH，不需要重啟 shell
gum style --foreground 241 "提示: 回到 prompt 後可檢查 ${tool_short##*/} 是否可用"

exit 0
