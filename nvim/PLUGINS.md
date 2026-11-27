# Neovim 插件選擇與恢復紀錄

## 目前的組合

共 **13 個插件**：Ayu、原清單的 mini 七個、Barbar、Tree-sitter、UFO＋promise-async、nvim-lspconfig。Mason 三件組及工具副本已移除，LSP 改由 mise 管理，Neovim／Helix 共用。

- 啟用設定：`lua/config/selected.lua`。`init.lua` 載入基本設定後呼叫它。
- UFO 與 promise-async 的 `vim.pack.add`／setup 都放在第一次 `BufReadPost`；空白啟動連 runtimepath 都不加入。原生 `load=false` 仍會預先加入 runtimepath，因此不採用該方式。
- mini 七個指 files、pick、surround、move、clue、icons、cursorword，不是啟用 mini.nvim 所有其他模組。
- Barbar 使用 mini.icons 的 devicons 相容介面，沒有另外安裝 nvim-web-devicons。
- 所有插件固定到原 lockfile 的 commit，沒有趁恢復時一起升級。

### 語法與 LSP

- 已安裝 8 個 parser：Rust、Python、TypeScript、TSX、JavaScript、JSON、Lua、Bash。
- 原 nvim-treesitter 的 master 是凍結的舊介面；此設定只使用其固定版本 parser installer／queries，**高亮由 Neovim 原生 `vim.treesitter.start` 負責**。目前 Neovim 0.13 實測可用；未啟用舊 highlight 模組。
- Parser 安裝明確執行 `:TSInstallSync rust python typescript tsx javascript json lua bash`，不在每次開檔時偷偷下載其他語言。
- Rust 繼續使用 rustup 的 rust-analyzer／rust-src；不另外裝 Mason 版。
- `mise/config.toml` 固定 pyright 1.1.414、typescript-language-server 6.0.3、vscode-langservers-extracted 4.10.0，以及 TypeScript 6.0.3。
- Neovim 原生啟用 pyright、ts_ls、jsonls，由 PATH 找到 mise 安裝；Helix 共用同一套工具，Python 明確選用 pyright。
- TypeScript server 優先用專案 TypeScript，否則用 mise 6.0.3。mise 將工具隔離安裝，且 aube 的 tsserver launcher 不是 symlink，因此兩個編輯器的 fallback 明確指向 `typescript/lib/tsserver.js`；升級 mise TypeScript 時須同步更新兩處路徑，回歸測試會檢查一致性。
- 換機後安裝：`mise install npm:pyright npm:typescript-language-server npm:typescript npm:vscode-langservers-extracted`。不再使用 Mason 安裝命令。
- 沒有恢復 DAP／debug adapter、blink、Neo-tree、fzf-lua 或自動存檔格式化。

### 常用鍵

| 鍵 | 功能 |
|---|---|
| `-` | mini.files 檔案瀏覽 |
| `Ctrl-T` | mini.pick 模糊找檔 |
| `Ctrl-F` | mini.pick live grep |
| `sa`／`sd`／`sr` | surround 增加／刪除／替換 |
| 選取模式 `<`／`>`／`J`／`K` | 移動選取文字 |
| `H`／`L`、Ctrl-Tab／Ctrl-Shift-Tab | 依 Barbar 顯示順序切換 buffer |
| `{`／`}` | UFO 載入後關閉／開啟當前 fold |
| `zM`／`zR` | UFO 載入後關閉／開啟全部 folds |

原有 `jj`、Ctrl-S、Space-y／Space-d、Space-g／Space-D、persistent undo 等基本設定仍有效。

## 舊紀錄與啟動保護

- `legacy-pack-lock.json`：移除插件前的完整紀錄，40 個套件，原始內容保留不變。
- 原本的啟動清單有 29 個未註解項目（含依賴）；另外 11 個只有安裝紀錄，不代表當時啟用。
- `nvim-pack-lock.json`：由 Neovim 自動產生，只包含目前明確選定的 13 個套件。
- `vim.pack` 會在第一次呼叫時安裝 lockfile 中所有套件，因此不能直接沿用舊的 40 個項目。
- 舊的整批插件設定保留在 `init.lua` 的 `do return end` 後面，不會被意外執行。

## 原本啟動清單的功能套件（24 個）

| 套件 | 目前 | 用途 |
|---|---|---|
| neovim-ayu | 已恢復 | Ayu 明暗主題 |
| mini.files | 已恢復 | 輕量檔案瀏覽、檔案操作 |
| mini.pick | 已恢復 | 模糊找檔與搜尋 |
| fzf-lua | 未恢復 | 另一套模糊找檔／live grep |
| neo-tree.nvim | 未恢復 | 側邊檔案樹 |
| mini.surround | 已恢復 | 括號／引號操作 |
| mini.move | 已恢復 | 移動選取文字 |
| mini.clue | 已恢復 | 後續按鍵提示 |
| blink.cmp | 未恢復 | 補全 UI；目前使用原生補全 |
| barbar.nvim | 已恢復 | Buffer 列 |
| hlchunk.nvim | 未恢復 | 縮排／區塊提示 |
| nvim-scrollview | 未恢復 | 捲動條 |
| nvim-navic | 未恢復 | 函式／類別 breadcrumbs |
| nvim-treesitter | 已恢復 | Parser 管理與 queries，搭配原生高亮 |
| nvim-ufo | 延遲載入 | 折疊 |
| nvim-tmux-navigation | 未恢復 | Neovim／tmux 跨窗移動 |
| vim-slime | 未恢復 | 傳送程式碼到 tmux／REPL |
| nvim-dap | 未恢復 | DAP 除錯 client |
| nvim-dap-ui | 未恢復 | 除錯視窗 |
| nvim-dap-virtual-text | 未恢復 | 行內除錯變數 |
| nvim-lspconfig | 已恢復 | Python／TS／JSON 等 server 設定 |
| mason.nvim | 已移除 | 改由 mise 管理外部工具 |
| mason-lspconfig.nvim | 已移除 | 改用原生 vim.lsp.enable |
| mason-tool-installer.nvim | 已移除 | 改用 mise install |

## 原本的依賴（5 個）

| 套件 | 目前 | 搭配對象 |
|---|---|---|
| nvim-web-devicons | 未恢復 | 用 mini.icons 相容介面取代 |
| plenary.nvim | 未恢復 | Neo-tree 等工具庫 |
| nui.nvim | 未恢復 | Neo-tree UI |
| promise-async | 延遲載入 | nvim-ufo |
| nvim-nio | 未恢復 | nvim-dap-ui |

## 原先有安裝紀錄、最後未啟用（11 個）

| 套件 | 目前 | 用途 |
|---|---|---|
| diffview.nvim | 未恢復 | Git diff／歷史視圖 |
| vscode-diff.nvim | 未恢復 | VS Code 風格 diff |
| fyler.nvim | 未恢復 | 另一個檔案瀏覽器 |
| mini.cursorword | 已恢復 | 游標所在單字高亮 |
| mini.icons | 已恢復 | 圖示及 devicons 相容介面 |
| nvim-scrollbar | 未恢復 | 另一個捲動條 |
| toggleterm.nvim | 未恢復 | 終端機 UI |
| vim-tpipeline | 未恢復 | tmux 狀態列整合 |
| vague.nvim | 未恢復 | 替代主題 |
| oxocarbon.nvim | 未恢復 | 替代主題 |
| vscode.nvim | 未恢復 | 替代主題 |

只有註解、未出現在舊 lockfile 的 mini.indentscope／indentmini 不算入這 40 個。
`lazy-lock.json` 與舊 LazyVim 設定屬於另一套歷史配置，不代表這次移除前的啟用套件。

## 驗證與資源測試

- 基本回歸：`python3 nvim/tests/test_basics.py`。使用已安裝插件，測試不下載套件；state/cache 及檔案 fixture 使用暫存目錄，不動系統剪貼簿。
- 本輪另以暫存 fixture 驗證 Python、TS、JS、JSON 的實際 LSP 請求，以及 Herdr Rust、高亮與 UFO。
- 資源比較：同一份基本設定，測試程序用 preload 暫時跳過 selected 模組作原生基線，不修改正式設定、不刪除插件。初次交錯各三輪後，完整延遲加入 UFO 的最終版本再測三輪；最後比較保留的三輪基線與最終三輪。
- 空白啟動與 Herdr Rust 工作階段分開計量；Rust 工作負載包含 hover、定義、補全、symbols、格式化／rename dry-run、記憶體內診斷測試。
- RAM 使用 macOS footprint 並附 RSS；編輯器與 rust-analyzer／proc-macro 分開。磁碟包含已安裝插件、parser、Mason 工具；共用 Rust／Node／Zig 與專案 target 不重複計入。
- 本輪量測腳本與結果保存在 `/tmp/nvim-selected-restore/`；完整報告為 `report.md`，最終原始數據為 `benchmark-final/results.json`。

### 改用 mise 後

- Neovim 專用磁碟（本體、13 個插件／parser、設定與 state/cache）約 **79.1 MiB**。
- 共用 mise LSP／TypeScript 四個工具合計約 **153.8 MiB**，兩者合計約 **232.9 MiB**，不含各工具管理器的共用下載快取。
- 這是把 LSP 移到共用管理，不是讓它們消失；不能將刪除 Mason 的約 159 MiB 全視為整機釋放空間。
- 移除後回歸 **11 項全過**；Neovim 五個語言案例的實際請求、Helix Python／TS／JS hover 與 JSON 格式化均通過。Rust 啟動方式未改。
- 未重跑完整 RAM benchmark。下表保留的是切換前的數據，不能當作目前 13 個插件的實測。

### 2026-11-13 切換 mise 前的量測（含 Mason，歷史紀錄）

macOS 27.2、Neovim 0.13.0-dev-2081；各三輪中位數，RAM 主指標為 physical footprint，單位 MiB。

| 場景 | 原生基線 | 選定組合 |
|---|---:|---:|
| 空白編輯器 | 9.3 | 16.7 |
| Herdr Rust 功能測試後，編輯器本身 | 22.9 | 34.2 |
| Rust LSP／proc-macro | 1435.7 | 1475.2 |
| 整個 Rust 工作階段 | 1458.8 | 1509.4 |

編輯器本身約增加 **11.3 MiB**；總量約 **1.47 GiB**，主要仍是 Rust LSP。Rust 子樹波動較大，不能把整體中位數差全歸因於插件；各欄獨立取中位數，加總可能略有差異。

磁碟：本體／runtime 38.8、插件含 parser 44.6、Mason 154.1、設定／state／cache 1.1，專用合計 **238.5 MiB**。另有本輪新增 npm 下載快取 40.0 MiB，不重複計入既有共用工具與專案 target。

最終比較六個 Rust 工作階段共 48 項檢查全過，寬限退出後無所屬程序殘留，Herdr 原始碼與 git status 未變。未測多語言同時活躍、超大型檔案或長時間使用。
