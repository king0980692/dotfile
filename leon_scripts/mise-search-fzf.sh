#!/bin/bash

# 用 fzf 瀏覽 mise registry，選取後交給 mise-tool-action.sh 安裝/移除
#   TAB / SHIFT-TAB   切換安裝狀態 (All / Installed / Uninstalled)
#   CTRL-B / ALT-B    切換 backend (下一個 / 上一個)
#   ENTER             安裝/移除
#   貼上 GitHub URL   (https://github.com/owner/repo、git@github.com:owner/repo.git
#                     或 github:owner/repo) 會列出 github:owner/repo，ENTER 用 mise 安裝
#
# fzf 的 bind 會以 "__" 開頭的子命令回呼本腳本，狀態放在 $MISE_FZF_STATE 目錄

set -o pipefail
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SELF")"
TOOL_INFO_SCRIPT="$SCRIPT_DIR/mise-tool-info.sh"
TOOL_ACTION_SCRIPT="$SCRIPT_DIR/mise-tool-action.sh"
STATE="$MISE_FZF_STATE"

# 獲取符合 backend、狀態與搜尋字串的工具列表 (從快取讀取，單一 awk 完成)
# 輸出表格: 第一行是欄位標題，之後每行 NAME VERSION DESCRIPTION
# (可用的 backend 顯示在 preview)
#
# 搜尋由這裡負責而不是 fzf (fzf 以 --disabled 啟動)，因為名稱與描述適合不同的
# 比對方式: 名稱短，用模糊比對；描述長，模糊比對會命中太多無關的工具，只比對
# 子字串。query 以空白分成多個詞，每個詞都要符合，結果依分數排序:
#   名稱完全相同 > 名稱開頭 > 名稱包含 > 描述的單字開頭 > 描述包含 > 名稱模糊符合
#
# 參數: $1 = 搜尋字串
list_tools() {
  if github_row "$1"; then return; fi
  awk -v backend="$(<"$STATE/backend")" -v status="$(<"$STATE/status")" \
    -v descriptions="$STATE/descriptions" -v query="$1" \
    -v name_width="$([ -n "$MISE_FZF_COMPACT" ] && echo 18 || echo 26)" '
    # term 的字元是否依序出現在 text 中。第一個字元必須相同 (lzg -> lazygit)，
    # 否則幾乎任何短詞都能在長名稱裡湊出來
    function is_subsequence(term, text,    i, pos) {
      if (substr(term, 1, 1) != substr(text, 1, 1)) return 0
      for (i = 1; i <= length(term); i++) {
        pos = index(text, substr(term, i, 1))
        if (pos == 0) return 0
        text = substr(text, pos + 1)
      }
      return 1
    }

    # 單一搜尋詞對工具的分數，0 = 不符合
    function term_score(term, name, text,    pos) {
      if (name == term) return 6
      pos = index(name, term)
      if (pos == 1) return 5
      if (pos > 1) return 4
      pos = index(text, term)
      if (pos == 1 || (pos > 1 && substr(text, pos - 1, 1) !~ /[a-z0-9]/)) return 3
      if (pos > 1) return 2
      if (length(term) > 1 && is_subsequence(term, name)) return 1
      return 0
    }

    # 所有搜尋詞的分數總和，任一個詞不符合就是 0
    function score(name,    i, s, total, lower_name, lower_text) {
      if (term_count == 0) return 1
      lower_name = tolower(name)
      lower_text = tolower(description[name])
      total = 0
      for (i = 1; i <= term_count; i++) {
        s = term_score(terms[i], lower_name, lower_text)
        if (s == 0) return 0
        total += s
      }
      return total
    }

    # 標出 text 中符合搜尋詞的部分。先用 \001 \002 當記號，最後才換成顏色碼，
    # 以免後面的詞比對到前面插入的顏色碼
    function mark(text,    i, pos, lower) {
      for (i = 1; i <= term_count; i++) {
        lower = tolower(text)
        pos = index(lower, terms[i])
        if (pos > 0 && index(terms[i], "\001") == 0)
          text = substr(text, 1, pos - 1) "\001" substr(text, pos, length(terms[i])) "\002" \
            substr(text, pos + length(terms[i]))
      }
      return text
    }
    function colorize(text, base_color) {
      gsub(/\001/, "\033[1;33m", text)
      gsub(/\002/, "\033[0m" base_color, text)
      return base_color text "\033[0m"
    }

    # 描述欄很窄，符合的部分稍微後面就會被截掉，改從符合的那個單字開始顯示
    function excerpt(text,    i, pos, first, start, lower) {
      first = 0
      lower = tolower(text)
      for (i = 1; i <= term_count; i++) {
        pos = index(lower, terms[i])
        if (pos > 0 && (first == 0 || pos < first)) first = pos
      }
      if (first <= 8) return text
      # 從空白處切，才不會切在多位元組字元中間
      start = first
      while (start > 1 && substr(text, start - 1, 1) != " ") start--
      return "…" substr(text, start)
    }

    function add_row(name, version,    s, padded) {
      s = score(name)
      if (s == 0) return
      if (version == "") version = "-"
      # 補滿寬度後才上色，否則顏色碼會被算進寬度
      padded = sprintf("%-*s", name_width, name)
      rows[s, ++row_count[s]] = sprintf("%s  %s%-10s\033[0m  %s", \
        colorize(mark(padded), ""), (version == "-" ? "\033[90m" : "\033[32m"), version, \
        colorize(mark(excerpt(description[name])), "\033[90m"))
      if (s > max_score) max_score = s
    }

    BEGIN {
      FS = "\t"
      while ((getline line < descriptions) > 0) {
        split(line, part, "\t")
        description[part[1]] = part[2]
      }
      FS = " "
      term_count = split(tolower(query), terms, " ")
      printf "%-*s  %-10s  %s\n", name_width, "NAME", "VERSION", "DESCRIPTION"
    }

    # 第一個檔案: 已安裝的工具與版本，僅保留精確名稱。
    FILENAME == ARGV[1] {
      installed[++n] = $1
      version[$1] = $2
      next
    }

    # 第二個檔案: registry
    {
      registry[$1]
      for (i = 2; i <= NF; i++) registry[$i]
      if (backend != "all") {
        hit = 0
        for (i = 2; i <= NF; i++)
          if (index($i, backend ":") == 1) { hit = 1; break }
        if (!hit) next
      }
      installed_version = version[$1]
      for (i = 2; i <= NF; i++) {
        if ($i in version) installed_version = version[$i]
      }
      is_installed = (installed_version != "")
      if (status == "all" || (status == "installed") == is_installed) add_row($1, installed_version)
    }

    END {
      # 已安裝但不在 registry 的工具 (如 github:sinelaw/fresh) 補在最後
      if (status != "uninstalled") {
        for (i = 1; i <= n; i++) {
          name = installed[i]
          if (name in registry) continue
          if (backend != "all" && index(name, backend ":") != 1) continue
          add_row(name, version[name])
        }
      }
      for (s = max_score; s >= 1; s--)
        for (i = 1; i <= row_count[s]; i++) print rows[s, i]
    }
  ' "$STATE/installed" "$STATE/registry"
}

# 搜尋字串是 GitHub repo 時，只列出一行 github:owner/repo (registry 裡沒有的
# repo 也能用 mise 的 github backend 安裝)，不是則回傳 1 交給一般搜尋
# 參數: $1 = 搜尋字串
github_row() {
  local query=$1 repo version name_width
  query="${query#"${query%%[![:space:]]*}"}"
  query="${query%"${query##*[![:space:]]}"}"
  if [[ "$query" =~ ^(https?://)?(www\.)?github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+) ]] ||
    [[ "$query" =~ ^(git@)()github\.com:([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+) ]] ||
    [[ "$query" =~ ^()()github:([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$ ]]; then
    repo="${BASH_REMATCH[3]}/${BASH_REMATCH[4]%.git}"
  else
    return 1
  fi
  name_width=$([ -n "$MISE_FZF_COMPACT" ] && echo 18 || echo 26)
  version=$(awk -v n="github:$repo" '$1 == n {print $2; exit}' "$STATE/installed")
  printf "%-*s  %-10s  %s\n" "$name_width" "NAME" "VERSION" "DESCRIPTION"
  printf "\033[1;33m%-*s\033[0m  %s%-10s\033[0m  \033[90m%s\033[0m\n" "$name_width" "github:$repo" \
    "$([ -n "$version" ] && echo $'\033[32m' || echo $'\033[90m')" "${version:--}" \
    "$([ -n "$version" ] && echo "ENTER 移除" || echo "GitHub release，ENTER 用 mise 安裝")"
}

# 把狀態檔切換到清單中的下一個/上一個值
# 參數: $1 = 狀態檔, $2 = next|prev, $3... = 可選的值
cycle() {
  local file=$1 direction=$2
  shift 2
  local values=("$@") current i
  current=$(<"$file")
  for i in "${!values[@]}"; do
    [ "${values[$i]}" = "$current" ] && break
  done
  if [ "$direction" = "prev" ]; then
    i=$(((i - 1 + ${#values[@]}) % ${#values[@]}))
  else
    i=$(((i + 1) % ${#values[@]}))
  fi
  echo "${values[$i]}" > "$file"
}

# list 的標題: 目前的過濾條件與切換按鍵
filter_state() {
  local backend status
  backend=$(<"$STATE/backend")
  status=$(<"$STATE/status")
  [ "$backend" = "all" ] && backend="All"
  if [ -n "$MISE_FZF_COMPACT" ]; then
    echo " < ${status^} > | < $backend > "
  else
    echo " TAB Status < ${status^} > | ^B Backend < $backend > "
  fi
}

# footer 區塊: 工具的完整描述，依 list 欄寬折行，最多三行以免擠壓 list
# 參數: $1 = tool name
tool_description() {
  # 扣掉各層邊框與留白
  local width=$((FZF_COLUMNS - FZF_PREVIEW_COLUMNS - 12))
  [ -n "$MISE_FZF_COMPACT" ] && width=$((width + 2))
  [ "$width" -lt 16 ] && width=16
  awk -F '\t' -v name="$1" '$1 == name {print $2; exit}' "$STATE/descriptions" |
    fold -s -w "$width" | head -n "$([ -n "$MISE_FZF_COMPACT" ] && echo 2 || echo 3)"
}

# fzf 回呼的子命令
case "$1" in
  __list)
    list_tools "$2"
    exit
    ;;
  __filter)
    filter_state
    exit
    ;;
  __description)
    tool_description "$2"
    exit
    ;;
  __cycle-status)
    cycle "$STATE/status" "$2" all installed uninstalled
    exit
    ;;
  __cycle-backend)
    mapfile -t backends < "$STATE/backends"
    cycle "$STATE/backend" "$2" "${backends[@]}"
    exit
    ;;
esac

# 檢查必要的指令與腳本是否存在
for cmd in mise fzf jq; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "錯誤: 找不到 $cmd 指令"
    exit 1
  fi
done

for script in "$TOOL_INFO_SCRIPT" "$TOOL_ACTION_SCRIPT"; do
  if [ ! -x "$script" ]; then
    echo "錯誤: 找不到 $(basename "$script") 或沒有執行權限"
    echo "請確保 $(basename "$script") 在同一目錄下並且可執行"
    exit 1
  fi
done

STATE=$(mktemp -d "${TMPDIR:-/tmp}/mise-fzf.XXXXXX") || exit 1

# 清理函數
cleanup() {
  rm -rf "$STATE"
}
trap cleanup EXIT
# 終端機被關閉時也要清理
trap 'exit 129' HUP
trap 'exit 143' TERM

# 預設 backend / status (all = 不過濾)
echo "all" > "$STATE/backend"
echo "all" > "$STATE/status"

# registry 與已安裝列表只獲取一次，之後的 reload 都讀快取
mise registry 2>/dev/null > "$STATE/registry"
if [ ! -s "$STATE/registry" ]; then
  echo "錯誤: 無法取得 mise registry"
  exit 1
fi
# 每個工具一行: 名稱<TAB>描述 (mise tool --description 對很多工具只回傳 [none]，
# 所以從 registry 的 JSON 取)
if ! mise registry --json 2>/dev/null | jq -r '.[] | [.short, (.description // "" | gsub("[\\t\\r\\n]"; " "))] | @tsv' > "$STATE/descriptions"; then
  echo "錯誤: 無法解析 mise registry JSON"
  exit 1
fi

# 每個工具一行: 名稱與最新的已安裝版本
COLUMNS=1000 mise ls --installed 2>/dev/null |
  awk '!($1 in version) {names[++n] = $1} {version[$1] = $2} END {for (i = 1; i <= n; i++) print names[i], version[names[i]]}' \
    > "$STATE/installed"

# 可切換的 backend 從 registry 取得，依工具數量排序
{
  echo "all"
  awk '{for (i = 2; i <= NF; i++) {split($i, part, ":"); print part[1]}}' "$STATE/registry" |
    sort | uniq -c | sort -k1,1nr -k2 | awk '{print $2}'
} > "$STATE/backends"

# 導出變量，供 fzf 子進程使用
export MISE_FZF_STATE="$STATE"
export MISE_FZF_SELF="$SELF"
export TOOL_INFO_SCRIPT

reload='reload("$MISE_FZF_SELF" __list {q})+first'
refresh="$reload"'+transform-list-label("$MISE_FZF_SELF" __filter)'

# 更新 preview 標題與描述。重新載入後游標位置不變就不會觸發 focus，
# 所以 result 事件也要綁
describe='bg-transform-preview-label([[ -n {1} ]] && echo " "{1}" ")'
describe+='+bg-transform-footer("$MISE_FZF_SELF" __description {1})'

# 終端機太小時改用精簡版面: 拿掉外框與留白，list 標題不顯示按鍵提示
layout=(--border --padding 1,2 --border-label ' mise ' --preview-window=right:55%:wrap)
read -r term_lines term_cols < <(stty size < /dev/tty 2> /dev/null)
if [ "${term_lines:-0}" -lt 24 ] || [ "${term_cols:-0}" -lt 100 ]; then
  export MISE_FZF_COMPACT=1
  layout=(--preview-window=right:50%:wrap)
fi

# 搜尋由 list_tools 負責，fzf 只負責顯示 (--disabled)，每次輸入都重新載入清單
# 左側由上到下: input = 搜尋, list = 工具表格 (標題顯示目前的過濾條件，欄位
# 標題與描述以 inline 邊框嵌在 list 框內)；右側 preview = 安裝資訊
# 顏色用 ANSI 色號，跟隨終端機的亮/暗主題
selected=$(list_tools "" | fzf \
  --style full \
  --reverse \
  --height=100% \
  "${layout[@]}" \
  --ansi \
  --disabled \
  --no-hscroll \
  --header-lines 1 \
  --header-lines-border inline \
  --footer-border inline \
  --input-label ' 搜尋 ' \
  --ghost '搜尋名稱或描述，或貼上 GitHub URL' \
  --preview '"$TOOL_INFO_SCRIPT" --no-header {1}' \
  --list-label "$(filter_state)" \
  --bind "change:$reload" \
  --bind "focus:$describe" \
  --bind "result:$describe" \
  --bind "tab:execute-silent(\"\$MISE_FZF_SELF\" __cycle-status next)+$refresh" \
  --bind "btab:execute-silent(\"\$MISE_FZF_SELF\" __cycle-status prev)+$refresh" \
  --bind "ctrl-b:execute-silent(\"\$MISE_FZF_SELF\" __cycle-backend next)+$refresh" \
  --bind "alt-b:execute-silent(\"\$MISE_FZF_SELF\" __cycle-backend prev)+$refresh" \
  --color 'preview-border:4,preview-label:4' \
  --color 'list-border:2,list-label:2' \
  --color 'input-border:1,input-label:1' \
  --color 'footer:3')

# 如果取消選擇，退出
if [ -z "$selected" ]; then
  exit 0
fi

# 讀取最終選擇的 backend
backend=$(<"$STATE/backend")
item=${selected%% *}

# exec 不會觸發 EXIT trap，先自行清理
cleanup
trap - EXIT

# 調用獨立的 action 腳本處理安裝/移除
exec "$TOOL_ACTION_SCRIPT" "$item" "$backend"
