# Helix：從 Neovim 搬移的操作

適用本機 Helix 25.07.1。設定在 `config.toml`，不依賴 Neovim 插件或 Mason。

## 常用鍵

`Space` 相當於原本的 leader；`Alt` 是 macOS 終端送出的 Meta 鍵。

| 按鍵 | 功能／差異 |
|---|---|
| `Esc` | 回 normal mode、只保留主要游標，並取消剩餘選取；適用 normal／insert／select |
| `Ctrl-s` | 存檔並回 normal mode，適用 normal／insert／select |
| insert `jj` | 回 normal mode；單一 `j` 會等下一個鍵才顯示，沒有 Vim 的 timeout |
| `Ctrl-v` | normal mode 進入 select mode 並向下增加同欄游標；select mode 向下複製選取，可重複按或加數字 |
| `Alt-Shift-c` | 向上一行複製選取 |
| `H` / `L` | 上／下一個 buffer |
| `Ctrl-Tab` / `Ctrl-Shift-Tab` | 下／上一個 buffer，終端須支援這些鍵碼 |
| `Alt-w n` / `Alt-w m` | 上一個 buffer |
| `Alt-w .` / `Alt-w /` | 下一個 buffer |
| `Alt-w x` | 關閉 buffer；有未存修改會拒絕關閉 |
| `Ctrl-t` | 專案檔案 picker |
| `Ctrl-f` / `Space g` | 搜尋 workspace；不同於原 Neovim Ctrl-f 只搜當前檔案目錄 |
| `-` / normal `Ctrl-b` | 從目前檔案目錄開啟內建 file explorer |
| `Space e` / `Space E` | 開啟 workspace file explorer，不是左右側邊樹 |
| `Alt-h/j/k/l` | 切換 Helix split；insert 會先回 normal，不會跨到 tmux pane |
| `Ctrl-d` / `Ctrl-u` | 游標與畫面下／上半頁後置中 |
| `0` / `^` / `$` | 行首／首個非空白字元／行尾 |
| `G` | 最後一行；select mode 中擴展選取 |
| `V` | 選取整行並進入 select mode |
| `D` / `C` | 刪除／修改至行尾 |
| `Y` | 複製整行 |
| `Space y` / `Space d` | 複製／剪下選取到系統剪貼簿 |
| `Space p` | 貼上系統剪貼簿 |
| select `p` | 用已複製內容取代選取，不覆蓋原剪貼簿 |
| `sa` / `sd` / `sr` | 加入／刪除／替換 surround，接著輸入括號或引號 |
| `Ctrl-]` | LSP 跳到定義，保留原生 `gd` |
| `Space D` | workspace 診斷 picker |
| `Space l d` | 當前文件診斷 picker（原生 Space d 已改為剪下） |
| `Space l f` | 格式化 |
| `Space o` | 重新載入 Helix 設定 |
| `Space j q` / `Space j c` | 用 jq 將整個 buffer pretty／compact；未自動存檔 |
| `Space J` | jumplist picker（原生 Space j 已改為 jq 前綴） |
| `Space B` | buffer picker（原生 Space b 已改為 breakpoint） |
| `F5` | 繼續已啟動的 debug session；不是自動啟動 adapter |
| `Space b` | 切換 breakpoint，需另行配置 debug adapter |
| insert `Ctrl-b` | 插入 `breakpoint()` 並回 normal mode |
| insert `Ctrl-Space` | 手動觸發補全；終端／輸入法可能攔截 |
| `Space t d/l/m` | 切換 Ayu dark／light／mirage，僅本次 session |

`Space w` 保留 Helix 原生視窗選單。未列出的鍵大多保留 Helix 預設。
預設 yank/paste register 設為 `+`，使用系統剪貼簿；clipboard provider 保持平台自動偵測。
macOS 本機健康檢查為 `pasteboard`（pbcopy/pbpaste）。

## 與 Vim／原本插件的界線

- `Ctrl-v` 是逐行新增多游標／選取，不是 Vim 的矩形模式；短行可能被跳過，Tab／寬字元也可能影響視覺對齊。
- 保留 Helix selection-first 的 `d`／`c`／`y`；不是完整 Vim 模擬器。
  例如整行刪除用 `xd` 或 `Vd`，不是 `dd`；選取詞後刪除用 `wd`，不是 `dw`。
- `sa` 前綴覆蓋原生 `s` 的 regex selection；後者可用 `Space ?` 的命令面板搜尋 regex matches。
- 不搬 Slime 的 `Ctrl-c Ctrl-c`、DAP watches／debug-session 專用鍵，或 mini.move 的選取搬移。
- 原本 `{`／`}` 的 folding 不搬；此版本沒有對等的原生 folding 命令，保留原生段落移動。
- 不搬 `Space j p` 的 jq 浮動預覽；pretty／compact 會修改 buffer，但失敗不替換原文。
- Neo-tree 特有的檔案操作、tmux 邊界自動導覽及補全 popup 的自訂鍵沒有等價搬移。
- 沒有新增 `:W`／`:Q` 等命令別名；使用 Helix 的 `:w`／`:q`／`:wq`。

## 主題與語言工具

沿用原本非 Mirage 的 Ayu，預設 `ayu_dark`，符合搬移時記錄的終端 dark appearance。
Helix 25.07.1 只有固定 theme 字串，沒有原生 light/dark 自動主題設定；要永久改色，
修改 `config.toml` 第一個 theme 設定，再用 `Space o` 重新載入。

Mason 已移除；Python、TS／JS、JSON 的語言伺服器改由 mise 管理，Helix／Neovim 共用。
Python 明確使用 pyright；TS server 優先專案 TypeScript，否則使用 mise 的 TypeScript 6.0.3。
兩個編輯器的 fallback 路徑固定對應該版本，升級時需同步更新，詳見 `nvim/PLUGINS.md`。
Rust 已在 `languages.toml` 配置：啟動時移除 mise 繼承的 `RUSTUP_TOOLCHAIN`，遵守專案的
`rust-toolchain.toml`，並指定本機已有的 Zig 0.16.0，供 Herdr 的 ghostty-vt build script 使用。
已補齊 Herdr 的 Rust 1.96.1 與 rustup 預設 1.93.1 的 rust-analyzer／rust-src；後者避免跳到
專案外的 Rust 原始碼時再次遇到缺少 component 的 shim 遞迴。check 使用 `cargo check`，
額外傳 `--locked`，不更新專案 Cargo.lock。Neovim、Mitos、Kakoune 使用相同的主要啟動設定。
這個 Zig 路徑與已安裝 Rust components 屬於本機設定；換機或換 toolchain 要重新確認。
共用工具版本固定於 `mise/config.toml`，透過 mise 啟用的 PATH／shims 取得，不引用 Neovim 的資料目錄。
Go 與 debug adapter 尚未安裝。
修改後閒置 3 秒自動存檔（`editor.auto-save.after-delay`）；Helix 25.07 在 insert mode 會延後至離開該模式才存檔。未啟用失去焦點時存檔。
自動存檔會直接更新原檔，不是備份或跨 session undo；未命名 buffer 仍需先指定存檔路徑。
`auto-format = true` 保留存檔格式化意圖，但實際取決於各語言的 server／formatter 設定。

## Neovim 留存與預設編輯器

Neovim 已恢復為 Bash 的預設編輯器，Helix 設定仍保留。
`nvim/init.lua` 先載入不依賴插件的基本選項、快捷鍵與原生 Rust LSP，再載入明確選定的
`lua/config/selected.lua`；舊的整批插件區以 `do return end` 隔離，不再靠目錄是否存在判斷。
持久 undo 已啟用，使用預設 `~/.local/state/nvim/undo/`；保留行號、4-space 預設縮排、
剪貼簿、`jj`、Ctrl-S、游標位置還原與 grep。H／L、Ctrl-Tab 依 Barbar 的 buffer 順序切換。
SSH／Herdr 使用原生 OSC 52，並以本機快取保留貼上內容及行／區塊型別。
已恢復 Ayu、mini 七個、Barbar、Tree-sitter、延遲載入 UFO，以及 nvim-lspconfig，共 13 個插件；Mason 三件組已移除。
存檔自動格式化與未選定的舊插件仍停用。完整清單見 `nvim/PLUGINS.md`。
舊 40 個套件紀錄保存在 `nvim/legacy-pack-lock.json`；啟用中的 `nvim-pack-lock.json`
只包含明確選定套件，避免整批重新安裝。
基本回歸測試：`python3 nvim/tests/test_basics.py`（使用已安裝選定插件，不會下載套件）。
Bash 的 `v`／`vim` alias，以及 `EDITOR`／`VISUAL` 均指向 `nvim`；Ghostty quick terminal 分支相同。
