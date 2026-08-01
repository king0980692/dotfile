-- require("config.lazy")
-- require("config.option")

-- vim.o.statuscolumn = "%!v:lua.require('mystcol').statuscolumn()"
-- vim.o.statusline = "%#Normal#" .. "" .. "%="
--
-- vim.api.nvim_set_hl(0, 'TermCursor', { fg = '#FFFFFF', bg = '#FF5555', reverse = false })

vim.opt.title = true
vim.opt.titlestring = "nvim %F %m"
vim.opt.ruler = false      -- 關閉右下角行列顯示
vim.opt.showcmd = false   -- 關閉右下角命令顯示

vim.opt.laststatus = 0    -- 隱藏下方 statusline（不建議這樣會連同檔名都隱藏）
-- vim.o.statusline = "%f"
-- vim.o.statusline = "%=%f"

vim.o.cursorline = true



vim.g.mapleader = " "

vim.o.number = true
-- vim.o.relativenumber = true
vim.o.signcolumn = "yes"
vim.o.termguicolors = true
vim.o.wrap = false
vim.o.tabstop = 4
vim.o.smarttab = true -- global-only 選項，原本散在 after/ftplugin，集中設一次
vim.o.swapfile = false
vim.g.mapleader = " "
vim.o.winborder = "rounded"
vim.o.clipboard = "unnamedplus"

vim.o.undofile = true
vim.o.undolevels = 10000
vim.o.updatetime = 200 -- Save swap file and trigger CursorHold

vim.o.scrolloff = 15
-- vim.o.colorcolumn = "80"

vim.cmd("set completeopt+=noselect")

vim.cmd [[command! Wq :wq]]
vim.cmd [[command! WQ :wq]]
vim.cmd [[command! W :w]]
vim.cmd [[command! Q :q]]

vim.api.nvim_set_keymap('n', 'q:', '<nop>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'q', '<nop>', { noremap = true, silent = true })


vim.cmd [[
cabbrev WQ wq
cabbrev Q! q!
cabbrev W! w!
]]

----------

vim.keymap.set({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })
vim.keymap.set("x", "p", '"_dP', { noremap = true, silent = true })
vim.keymap.set("i", "jj", "<Esc>")
-- vim.keymap.set('n', '0', '^', { noremap = true, silent = true })


vim.keymap.set('n', '<leader>o', ':update<CR> :source<CR>')
-- vim.keymap.set('n', '<leader>w', ':write<CR>')
-- vim.keymap.set('n', '<leader>q', ':quit<CR>')

vim.keymap.set({ 'n', 'v', 'x' }, '<leader>y', '"+y<CR>')
vim.keymap.set({ 'n', 'v', 'x' }, '<leader>d', '"+d<CR>')

vim.keymap.set("n", "<C-d>", "<C-d>zz", { noremap = true, silent = true })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { noremap = true, silent = true })

vim.keymap.set("n", "H", "<cmd>BufferPrevious<cr>", { desc = "Move to previous buffer" })
vim.keymap.set("n", "L", "<cmd>BufferNext<cr>", { desc = "Move to next buffer" })
vim.keymap.set("n", "<C-Tab>", "<cmd>BufferNext<cr>", { desc = "Next tab" })
vim.keymap.set("n", "<C-S-Tab>", "<cmd>BufferPrevious<cr>", { desc = "Previous tab" })
-- vim.keymap.set("n", "H", "<cmd>bp <CR>", { silent = false })
-- vim.keymap.set("n", "L", "<cmd>bn <CR>", { silent = false })

vim.keymap.set("x", "p", '"_dP', { noremap = true, silent = true })
vim.keymap.set("n", "<M-w>n", "<cmd>bp <CR>", { silent = false })
vim.keymap.set("n", "<M-w>m", "<cmd>bp <CR>", { silent = false })
vim.keymap.set("n", "<M-w>.", "<cmd>bn <CR>", { silent = false })
vim.keymap.set("n", "<M-w>/", "<cmd>bn <CR>", { silent = false })
vim.keymap.set("n", "<M-w>x", "<cmd>bd <CR>", { silent = false })


-- vim.keymap.set("n", "<C-i>", "Obreakpoint()<Esc>", { noremap = true, silent = true })
vim.keymap.set("i", "<C-b>", "breakpoint()<Esc>", { noremap = true, silent = true })

vim.keymap.set("n", "<C-c><C-c>", "<Plug>SlimeLineSend", { silent = false })
vim.keymap.set("x", "<C-c><C-c>", "<Plug>SlimeRegionSend", { silent = false })
vim.g.slime_target = "tmux"
vim.g.slime_default_config = { socket_name = "default", target_pane = "{last}" }
vim.g.slime_dont_ask_default = 1
vim.g.slime_cell_delimiter = "# %%"
vim.g.slimve_bracketed_paste = 1
vim.g.slime_no_mappings = 1
vim.g.slime_python_ipython = 0


vim.pack.add({
  
	{ src = "https://github.com/Shatur/neovim-ayu" },
	-- 未使用：colorscheme 目前是 ayu（第 840 行），vague / oxocarbon 沒有被載入
	-- { src = "https://github.com/vague2k/vague.nvim" },
	-- { src = "https://github.com/nyoom-engineering/oxocarbon.nvim" },
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter" },
	{ src = "https://github.com/neovim/nvim-lspconfig" },
  { src = 'https://github.com/mason-org/mason.nvim' },
	{ src = 'https://github.com/mason-org/mason-lspconfig.nvim' },
	{ src = 'https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim' },
	{ src = "https://github.com/mfussenegger/nvim-dap" },
	{ src = "https://github.com/rcarriga/nvim-dap-ui" },
	{ src = "https://github.com/nvim-neotest/nvim-nio" },
	{ src = "https://github.com/theHamsta/nvim-dap-virtual-text" },

	{ src = "https://github.com/romgrk/barbar.nvim"},
	{ src = 'https://github.com/nvim-tree/nvim-web-devicons'},

	-- { src = "https://github.com/A7Lavinraj/fyler.nvim" },

	{ src = "https://github.com/echasnovski/mini.files" },
	{ src = "https://github.com/echasnovski/mini.pick" },
	{ src = "https://github.com/echasnovski/mini.surround" },
	-- { src = "https://github.com/echasnovski/mini.indentscope" },
	-- 未使用：兩者的 setup() 都被註解（見下方 require "mini.cursorword" / "mini.icons"）
	-- mini.icons 沒 setup 就不會生效，圖示實際是走 nvim-web-devicons
	-- { src = "https://github.com/echasnovski/mini.icons" },
	-- { src = "https://github.com/echasnovski/mini.cursorword" },
	{ src = "https://github.com/echasnovski/mini.move" },
	{ src = "https://github.com/echasnovski/mini.clue" },


	{ src = "https://github.com/jpalardy/vim-slime" },
	{ src = "https://github.com/alexghergh/nvim-tmux-navigation" },
	{ src = "https://github.com/kevinhwang91/nvim-ufo" },
	{ src = "https://github.com/kevinhwang91/promise-async" },

	{ src = "https://github.com/SmiteshP/nvim-navic" },
	-- { src = "https://github.com/nvimdev/indentmini.nvim" },

  
  { src = "https://github.com/Saghen/blink.cmp", build = 'cargo build --release', version = "v1.6.0", },
	{ src = "https://github.com/shellRaining/hlchunk.nvim" },
  { src = "https://github.com/nvim-neo-tree/neo-tree.nvim" },
  { src = "https://github.com/nvim-lua/plenary.nvim" },
  { src = "https://github.com/MunifTanjim/nui.nvim"},
  { src = "https://github.com/dstein64/nvim-scrollview" },
  -- 未使用：colorscheme vscode 已註解
  -- { src = "https://github.com/Mofiqul/vscode.nvim" },
  { src = "https://github.com/ibhagwan/fzf-lua" },

  -- ignore the status line into tmux
  -- { src = "https://github.com/vimpostor/vim-tpipeline.git" },

  -- { src = "https://github.com/A7Lavinraj/fyler.nvim"  },

  -- { src = "https://github.com/akinsho/toggleterm.nvim" },

})


require('scrollview').setup({
  excluded_filetypes = {'neo-tree'},
  -- current_only = true,
  -- base = 'buffer',
  -- signs_on_startup = {'all'},
  diagnostics_severities = {vim.diagnostic.severity.ERROR},
  consider_border = true,

})


vim.keymap.set("n", "<leader>E", "<Cmd>Neotree left toggle<CR>")
vim.keymap.set("n", "<C-b>", "<Cmd>Neotree right toggle reveal_force_cwd<CR>")
vim.keymap.set("n", "<leader>e", "<Cmd>Neotree right toggle<CR>")

require("neo-tree").setup({
  close_if_last_window = true,
  enable_git_status = false,
  filesystem = {
    hijack_netrw_behavior = "disabled",
  },
  default_component_configs = {
    indent = {
      indent_size = 2,
      padding = 1, -- extra padding on left hand side
      -- indent guides
      with_markers = true,
      indent_marker = "│",
      last_indent_marker = "└",
      -- expander config, needed for nesting files
      expander_collapsed = "",
      expander_expanded = "",
    },
    icon = {
      --				folder_closed = icons.ui.Folder,
      --				folder_open = icons.ui.FolderOpen,
      --				folder_empty = icons.ui.EmptyFolder,
    },
    modified = {
      --				symbol = icons.git.LineAdded,
    },
    name = {
      trailing_slash = false,
      use_git_status_colors = true,
    },
    git_status = {
      symbols = {
        -- Change type
        added = "", -- or "✚", but this is redundant info if you use git_status_colors on the name
        modified = "", -- or "", but this is redundant info if you use git_status_colors on the name
        deleted = "✖", -- this can only be used in the git_status source
        renamed = "󰁕", -- this can only be used in the git_status source
        -- Status type
        --					untracked = icons.git.FileUntracked,
        --					ignored = icons.git.FileIgnored,
        --					unstaged = icons.git.FileUnstaged,
        --					staged = icons.git.FileStaged,
        --					conflict = icons.git.Diff,
      },
    },

    -- If you don't want to use these columns, you can set `enabled = false` for each of them individually
    file_size = {
      enabled = true,
      required_width = 64, -- min width of window required to show this column
    },
    type = {
      enabled = true,
      required_width = 122, -- min width of window required to show this column
    },
    last_modified = {
      enabled = true,
      required_width = 88, -- min width of window required to show this column
    },
    created = {
      enabled = true,
      required_width = 110, -- min width of window required to show this column
    },
    symlink_target = {
      enabled = false,
    },
  },
  window = {
    position = "left",
    width = 32,
    mappings = {
      ["l"] = "open",
      ["h"] = "close_node",
      -- ["P"] = { "toggle_preview", config = { use_float = true, use_image_nvim = true } },
      -- Read `# Preview Mode` for more information
      ["s"] = "open_vsplit",
      ["S"] = "",
      ["t"] = "open_tabnew",
      ["w"] = "open_with_window_picker",
      -- ["p"] = "toggle_preview", -- enter preview mode, which shows the current node without focusing
      ["C"] = "close_node",
      ["z"] = "close_all_nodes",
      ["a"] = {
        "add",
        -- this command supports BASH style brace expansion ("x{a,b,c}" -> xa,xb,xc). see `:h neo-tree-file-actions` for details
        -- some commands may take optional config options, see `:h neo-tree-mappings` for details
        config = {
          show_path = "none", -- "none", "relative", "absolute"
        },
      },
      ["A"] = "add_directory", -- also accepts the optional config.show_path option like "add". this also supports BASH style brace expansion.
      ["d"] = "delete",
      ["r"] = "rename",
      ["y"] = "copy_to_clipboard",
      ["x"] = "cut_to_clipboard",
      -- ["p"] = "paste_from_clipboard",
      ["c"] = "copy", -- takes text input for destination, also accepts the optional config.show_path option like "add":
      ["m"] = "move", -- takes text input for destination, also accepts the optional config.show_path option like "add".
      ["q"] = "close_window",
      ["R"] = "refresh",
      ["?"] = "show_help",
      ["<"] = "prev_source",
      [">"] = "next_source",
      ["i"] = "show_file_details",
      
      ["<C-d>"] = { "scroll_preview", config = { direction = -4 } },
      ["<C-u>"] = { "scroll_preview", config = { direction = 4 } },
      
      ["<C-b>"] = false,
      ["<C-f>"] = false,
    },
  },
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = "neo-tree",
  callback = function()
    -- 確保在 Neo-tree 視窗中不顯示行號
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
  end,
})


-- ============ mason（延遲載入）============
-- mason.setup() 在啟動時唯一不可省的副作用，就是把 mason 的 bin 目錄 prepend 到
-- PATH，讓 vim.lsp.enable() 找得到 pyright / ts_ls / jsonls 執行檔。
-- 這裡自己做掉那一行（0 成本），其餘 30+ 個 mason-core.* require 延到第一次進
-- cmdline 才載入。
vim.env.PATH = vim.fn.stdpath("data") .. "/mason/bin" .. ":" .. vim.env.PATH

local function load_mason()
	require("mason").setup()
	require("mason-lspconfig").setup()
	require("mason-tool-installer").setup({
		ensure_installed = {
			"pyright",
			"ts_ls",
			"jsonls",
			"js-debug-adapter",
		},
	})
end

vim.api.nvim_create_autocmd("CmdlineEnter", {
	group = vim.api.nvim_create_augroup("MasonLazyLoad", { clear = true }),
	once = true,
	callback = function()
		vim.schedule(load_mason)
	end,
})

-- ============ DAP（延遲載入）============
-- 實際設定在 lua/dap_setup.lua，第一次按下面任一鍵才會 require 進來。
-- require 有 memoize，之後每次都是 table 查找，成本為零。
local function dap_action(name)
	return function()
		require("dap_setup")[name]()
	end
end

vim.keymap.set("n", "<F5>", dap_action("continue"), { desc = "DAP continue" })
vim.keymap.set("n", "<leader>b", dap_action("toggle_breakpoint"), { desc = "DAP toggle breakpoint" })
vim.keymap.set("n", "<leader>w", dap_action("watch_cword"), { desc = "DAP add watch" })
vim.keymap.set("x", "w", dap_action("watch_selection"), { desc = "DAP add watch from selection" })

-- .jsonl 用獨立的 jsonl filetype（避免 jsonls 把多筆 JSON 當成一份而報錯）
vim.filetype.add({ extension = { jsonl = "jsonl" } })
-- 讓 json 的 treesitter parser 也負責 jsonl 的上色
pcall(vim.treesitter.language.register, "json", "jsonl")

vim.lsp.enable('pyright')
vim.lsp.enable('ts_ls')
vim.lsp.enable('jsonls')
-- jsonls (vscode-json-language-server, node) 只 attach .json/.jsonc
vim.lsp.config('jsonls', {
	on_attach = on_attach,
})

-- ============ JSON / JSONL pretty view (使用 jq) ============
-- 對整個 buffer 套用 jq filter（in-place 修改）
local function jq_filter_buffer(jq_args)
	if vim.fn.executable("jq") == 0 then
		vim.notify("找不到 jq 執行檔", vim.log.levels.ERROR)
		return
	end
	local input = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
	local cmd = { "jq" }
	vim.list_extend(cmd, jq_args or { "." })
	local out = vim.fn.systemlist(cmd, input)
	if vim.v.shell_error ~= 0 then
		vim.notify("jq 失敗: " .. table.concat(out, "\n"), vim.log.levels.ERROR)
		return
	end
	vim.api.nvim_buf_set_lines(0, 0, -1, false, out)
end

-- 把「當前這一行」pretty 印在浮動視窗（不改動原檔，適合 jsonl 逐行看）
local function jq_preview_line()
	if vim.fn.executable("jq") == 0 then
		vim.notify("找不到 jq 執行檔", vim.log.levels.ERROR)
		return
	end
	local out = vim.fn.systemlist({ "jq", "." }, vim.api.nvim_get_current_line())
	if vim.v.shell_error ~= 0 then
		vim.notify("jq 失敗: " .. table.concat(out, "\n"), vim.log.levels.ERROR)
		return
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
	vim.bo[buf].filetype = "json"
	local width = math.min(100, vim.o.columns - 4)
	local height = math.min(#out, vim.o.lines - 4)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " jq preview ",
	})
	vim.wo[win].wrap = false
	for _, k in ipairs({ "q", "<Esc>" }) do
		vim.keymap.set("n", k, "<cmd>close<CR>", { buffer = buf, nowait = true })
	end
end

vim.api.nvim_create_user_command("JqPretty", function() jq_filter_buffer({ "." }) end, {})
vim.api.nvim_create_user_command("JqCompact", function() jq_filter_buffer({ "-c", "." }) end, {})
vim.api.nvim_create_user_command("JqLine", jq_preview_line, {})

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "json", "jsonc", "jsonl" },
	callback = function(ev)
		local opt = { buffer = ev.buf }
		vim.keymap.set("n", "<leader>jp", jq_preview_line, vim.tbl_extend("force", opt, { desc = "jq: 預覽當前行 (float)" }))
		vim.keymap.set("n", "<leader>jq", "<cmd>JqPretty<CR>", vim.tbl_extend("force", opt, { desc = "jq: 整個 buffer pretty" }))
		vim.keymap.set("n", "<leader>jc", "<cmd>JqCompact<CR>", vim.tbl_extend("force", opt, { desc = "jq: 整個 buffer compact" }))
	end,
})
vim.lsp.config('pyright', {
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        diagnosticMode = "workspace",
        useLibraryCodeForTypes = true
      },
    },
    pyright = {
      -- Use ruff for organizing imports
      disableOrganizeImports = true
    }
  },
  single_file_support = true,
  on_attach = on_attach
})


require('ayu').setup({
    mirage = false, -- Set to `true` to use `mirage` variant instead of `dark` for dark background.
    terminal = true, -- Set to `false` to let terminal manage its own colors.
    overrides = {}, -- A dictionary of group names, each associated with a dictionary of parameters (`bg`, `fg`, `sp` and `style`) and colors in hex.
})
-- require()
-- vim.cmd("colorscheme vague")
vim.cmd("colorscheme ayu")
-- vim.cmd("colorscheme vscode")
vim.api.nvim_set_hl(0, "pmenu", {
    -- 將背景顏色 (bg) 設定為 nil 或 false 以實現透明
    bg = nil, 
    -- 前景/文字顏色 (fg) 保持不變，例如淺灰色
    fg = nil,
})
vim.api.nvim_set_hl(0, "pmenusel", {
    fg = nil,
    bg = "#4b5263", -- 例如: "#4b5263" (一個較淺的灰色)
})
vim.api.nvim_set_hl(0, "cmpitemmenu", {
    fg = "blue",   -- 白色文字 (type/text)
    bg = "blue",   -- 深灰色背景
})
vim.api.nvim_set_hl(0, "normalfloat", {
    -- 將背景顏色 (bg) 設定為 nil 或 false 以實現透明
    bg = nil, 
    -- 前景/文字顏色 (fg) 保持不變，例如淺灰色
    fg = nil,
})
vim.api.nvim_set_hl(0, "floatborder", {
    -- 邊框顏色 (fg)
    fg = "#02ba92", -- 例如，藍色
    -- 邊框背景顏色 (bg)
    bg = nil,
})


-- Hover 顯示LSP warning or Error
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
    callback = function()
        -- 確保只有在有診斷訊息時才開啟浮動視窗
        local current_diagnostics = vim.diagnostic.get(0, { lnum = vim.api.nvim_win_get_cursor(0)[1] - 1 })
        
        -- 只有當當前行有診斷訊息時，才執行 open_float
        if #current_diagnostics > 0 then
            vim.diagnostic.open_float(nil, { 
                focus = false, 
                scope = "line", -- 只顯示當前行的診斷
            })
        end
    end,
    -- 僅在支援診斷的緩衝區執行
    pattern = { "*" },
})


  
local nvim_tmux_nav = require("nvim-tmux-navigation")

local directions = {
  h = nvim_tmux_nav.NvimTmuxNavigateLeft,
  j = nvim_tmux_nav.NvimTmuxNavigateDown,
  k = nvim_tmux_nav.NvimTmuxNavigateUp,
  l = nvim_tmux_nav.NvimTmuxNavigateRight,
}

local modes = { "n", "i", "v" }

for _, mode in ipairs(modes) do
  for key, func in pairs(directions) do
    vim.keymap.set(mode, "<M-" .. key .. ">", func, {
      noremap = true,
      silent = true,
      desc = "tmux navigate " .. key,
    })
  end
end

vim.keymap.set("n", "<C-]>", vim.lsp.buf.definition, { desc = "Go to definition" })

----------------

vim.api.nvim_create_autocmd('LspAttach', {
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if client:supports_method('textDocument/completion') then
			vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
		end
	end,
})


local navic = require("nvim-navic").setup({
  lsp = { auto_attach = true, preference = nil },
  separator = "  ",
})
vim.opt.winbar = "%{%v:lua.require'nvim-navic'.get_location()%}"

-- vim.opt.statusline = "%{%v:lua.require'nvim-navic'.get_location()%}"




vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]
vim.o.foldcolumn = '0' -- '0' is not bad
vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
vim.o.foldlevelstart = 99
vim.o.foldenable = true
-- ufo 延遲到第一次讀進真實檔案才載入（開空 nvim 不需要 folding）。
-- 用 BufReadPost 而非 BufWinEnter：ufo 自己是掛 BufWinEnter attach 的，而
-- BufReadPost 早於 BufWinEnter，所以第一個開的 buffer 仍然吃得到 folding。
-- 上面那些 fold 選項是 vim.o 賦值，成本為零，維持在啟動時設定。
vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("UfoLazyLoad", { clear = true }),
  once = true,
  callback = function()
    require("ufo").setup({
      provider_selector = function(bufnr, filetype, buftype)
        return { 'treesitter', 'indent' }
      end
    })
  end,
})
vim.keymap.set("n", "{",  '<cmd>foldclose<CR>',{ desc = 'fold: close fold' } )
vim.keymap.set("n", "}",  '<cmd>foldopen<CR>',{ desc = 'fold: close fold' } )
-- vim.keymap.set("n", "{", function()
--     vim.cmd("normal! zk")
--
--     vim.cmd("foldclose")
-- end, { desc = 'fold: Go to prev and open fold' })
-- vim.keymap.set("n", "}", function()
--     vim.cmd("normal! zj")
--
--     vim.cmd("foldopen")
-- end, { desc = 'fold: Go to next and open fold' })


-- vim.keymap.set("n", "}", '<cmd> lua require("ufo").openFoldsExceptKinds()<cr>', { desc = 'fold: open fold' })


-- require "mini.cursorword".setup({})
-- require "mini.icons".setup({})



-- ============ mini.clue / mini.surround / mini.move（延遲載入）============
-- 這三個都是純按鍵驅動，開檔、上色、LSP 都用不到，可以整組延到第一次真的按下
-- 相關按鍵才 setup。
local mini_extras_loaded = false

-- mini.clue 的 trigger key 集合。載入前先由這些 key 的 bootstrap mapping 代打，
-- 載入後刪掉 bootstrap，再把該鍵 replay 回去交給真正的 handler。
local mini_lazy_triggers = {
	{ mode = "n", keys = "<Leader>" }, { mode = "x", keys = "<Leader>" },
	{ mode = "n", keys = "g" },        { mode = "x", keys = "g" },
	{ mode = "n", keys = "z" },        { mode = "x", keys = "z" },
	{ mode = "n", keys = "`" },        { mode = "x", keys = "`" },
	{ mode = "n", keys = "s" },
	{ mode = "n", keys = "[" },        { mode = "n", keys = "]" },
	{ mode = "n", keys = "<C-w>" },
	{ mode = "i", keys = "<C-x>" },
}

local function load_mini_extras()
	if mini_extras_loaded then return end
	mini_extras_loaded = true

	-- 先移除 bootstrap mapping，replay 的按鍵才會落到真正的 handler 上
	for _, t in ipairs(mini_lazy_triggers) do
		pcall(vim.keymap.del, t.mode, t.keys)
	end

	-- 順序有意義：surround 先建 sa/sd/sr…，clue 最後才把 s 註冊成 trigger
	require "mini.surround".setup({
	  mappings = {
	    add = "sa",
	    delete = "sd",
	    find = "sf",
	    find_left = "sF",
	    highlight = "sh",
	    replace = "sr",
	    update_n_lines = "sn",
	  },
	})

	require "mini.move".setup({
	  mappings = {
	    -- Move visual selection in Visual mode. Defaults are Alt (Meta) + hjkl.
	    left = '<',
	    right = '>',
	    down = '<S-j>',
	    up = '<S-k>',
	
	    -- Move current line in Normal mode
	    -- line_left = '<S-h>',
	    -- line_right = '<S-l>',
	    -- line_down = '<S-j>',
	    -- line_up = '<S-k>',
	
	    line_left = '',
	    line_right = '',
	    line_down = '',
	    line_up = '',
	  },
	})

	require("mini.clue").setup({
			-- Clue window settings
			window = {
				-- Floating window config
				config = {
					width = 40,
				},
	
				-- Delay before showing clue window
				delay = 100,
	
				-- Keys to scroll inside the clue window
	
				scroll_down = "down",
				scroll_up = "up",
			},
			triggers = {
	
				-- Folding triggers
				{ mode = "n", keys = "z" },
				{ mode = "x", keys = "z" },
	
				-- Leader triggers
				{ mode = "n", keys = "<Leader>" },
				{ mode = "x", keys = "<Leader>" },
	
				-- Built-in completion
				{ mode = "i", keys = "<C-x>" },
	
				-- `g` key
	
				{ mode = "n", keys = "g" },
				{ mode = "x", keys = "g" },
	
	
				-- Marks
				{ mode = "n", keys = "`" },
				{ mode = "x", keys = "`" },
	
	
				-- Window commands
				{ mode = "n", keys = "<C-w>" },
	
	
				-- Movements
				{ mode = "n", keys = "[" },
				{ mode = "n", keys = "]" },
	
				-- Surrounds
				{ mode = "n", keys = "s" },
			},
			clues = {
				-- Enhance this by adding descriptions for <Leader> mapping groups
				require("mini.clue").gen_clues.builtin_completion(),
				require("mini.clue").gen_clues.g(),
				require("mini.clue").gen_clues.marks(),
				require("mini.clue").gen_clues.registers(),
				require("mini.clue").gen_clues.windows(),
				require("mini.clue").gen_clues.z(),
			},
		})
end

for _, t in ipairs(mini_lazy_triggers) do
	vim.keymap.set(t.mode, t.keys, function()
		load_mini_extras()
		vim.api.nvim_feedkeys(vim.keycode(t.keys), "m", false)
	end, { desc = "lazy-load mini.clue/surround/move" })
end

-- 保險絲：mini.move 的鍵（visual 的 < > J K）不在上面的 trigger 集合裡；另外快速
-- 連打 <Leader>y 這類較長的 mapping 會直接命中長版、繞過 bootstrap。所以再補兩個
-- 觸發點：進 visual mode、以及第一次 CursorHold（updatetime 200ms）。
-- 實務上幾乎都是 CursorHold 先到，使用者根本按不到 bootstrap。
local mini_lazy_group = vim.api.nvim_create_augroup("MiniExtrasLazyLoad", { clear = true })
vim.api.nvim_create_autocmd("ModeChanged", {
	group = mini_lazy_group,
	pattern = "*:[vV\22]",
	once = true,
	callback = load_mini_extras,
})
vim.api.nvim_create_autocmd("CursorHold", {
	group = mini_lazy_group,
	once = true,
	callback = load_mini_extras,
})

-- vim.keymap.set("n", "<leader>E", "<Cmd>Neotree right toggle<CR>")
-- NOTE: mini.pick 的 setup() 是「預設值 + 傳入值」而非累加，所以只能呼叫一次，
-- 否則後一次會把前一次設的欄位靜默還原成預設值。
require "mini.pick".setup({
  options = {
    -- Whether to show content from bottom to top
    content_from_bottom = false,

    -- Whether to cache matches (more speed and memory on repeated prompts)

    use_cache = false,
  },
  window = {
    -- 視窗寬度貼齊當前 buffer 最長那行
    config = function()
      local buf = vim.api.nvim_get_current_buf()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local max_length = 0
      for _, line in ipairs(lines) do
        local length = vim.fn.strdisplaywidth(line)
        if length > max_length then
          max_length = length
        end
      end
      return {
        width = max_length + 1,
      }
    end,
  },
})

require "mini.files".setup({
  mappings = {
    close = "q",
    -- go_in = "<CR>",
    go_out = 'h',
    go_in  = 'l',

  },
  windows = {
    max_number = math.huge,
    preview = false,
    border = "solid",
    width_focus = 25,
    width_nofocus = 25,
    width_preview = 60,
  },
  options = {
    -- Whether to delete permanently or move into module-specific trash
    permanent_delete = true,
    -- Whether to use for editing directories
    use_as_default_explorer = true,
  },
})
do
  vim.api.nvim_create_autocmd('User', {
    pattern = 'MiniFilesBufferCreate',
    callback = function(args)
      vim.keymap.set('n', '<CR>', function()
        require('mini.files').go_in { close_on_file = true }
      end, {
        buffer = args.data.buf_id,
        desc = '[young] open cwd',
      })
      vim.keymap.set('n', 'l', function()
        local cur_file = require('mini.files').get_fs_entry()
        if cur_file and cur_file.fs_type == "directory" then
          require('mini.files').go_in {}
        end
      end, {
        buffer = args.data.buf_id,
      })
    end,
  })
end


local function open_mini_files()
  local buffer_name = vim.api.nvim_buf_get_name(0)
  local target_path
  
  if buffer_name == "" or string.match(buffer_name, "Starter") then
      target_path = vim.loop.cwd()
  else
      target_path = vim.api.nvim_buf_get_name(0)
  end
  
  -- 打开父目录，这样可以看到当前文件及其兄弟文件和祖父目录
  local parent_path = vim.fn.fnamemodify(target_path, ':h')
  require("mini.files").open(parent_path)
end

vim.keymap.set("n", "-", open_mini_files, { desc = "Find Manually" })
vim.api.nvim_set_hl(0, "MiniFilesBorder", { bg = "#111111" })
-- vim.api.nvim_set_hl(0, "MiniPickBorder", { bg = "#111111" })
vim.api.nvim_set_hl(0, "MiniPickMatchCurrent", { bg = "#B2B2B2", fg="black" })

-- require "fyler".setup({
--   mappings = {
--     ["q"] = "CloseView",
--     ["<CR>"] = "Select",
--     ["<C-t>"] = "SelectTab",
--     ["|"] = "",
--     ["-"] = "",
--     ["H"] = "GotoParent",
--     ["="] = "GotoCwd",
--     ["."] = "GotoNode",
--     ["#"] = "CollapseAll",
--     ["<BS>"] = "CollapseNode",
--   },
--
--   win = {
--     kind = "split_left_most",
--     kind_presets = {
--       split_left_most = {
--         width = "32abs",
--         win_opts = {
--           winfixwidth = true,
--         },
--       },
--     },
--   },
-- })
-- vim.keymap.set("n", "-", function()
--   require('fyler').toggle({ dir=vim.fn.expand('%:p:h'), kind = "split_left_most" }) 
-- end)
-- vim.keymap.set( "n", "<leader>e", function()  require("fyler").toggle({ kind = "split_left_most" }) end )
--
-- vim.keymap.set("n", "<C-b>", function()
--   local current_buf = vim.api.nvim_get_current_buf()
--   local current_bufname = vim.api.nvim_buf_get_name(current_buf)
--   local current_filetype = vim.bo[current_buf].filetype
--
--   local current_buftype = vim.bo[current_buf].buftype
--
--   -- Check if currently in Fyler window
--   if
--     current_bufname:match("fyler")
--     or current_filetype == "fyler"
--     or current_buftype == "acwrite"
--   then
--     -- We're in Fyler, go back to previous window
--     vim.cmd("wincmd p")
--     return
--   end
--
--   -- Check if Fyler is already open by looking for Fyler buffer names
--   for _, buf in ipairs(vim.api.nvim_list_bufs()) do
--     if vim.api.nvim_buf_is_valid(buf) then
--       local bufname = vim.api.nvim_buf_get_name(buf)
--       local filetype = vim.bo[buf].filetype
--       local buftype = vim.bo[buf].buftype
--
--       -- check for fyler by buffer name pattern or buffer type
--       if
--         bufname:match("fyler")
--         or filetype == "fyler"
--         or buftype == "acwrite"
--       then
--         local wins = vim.fn.win_findbuf(buf)
--         if #wins > 0 and vim.api.nvim_win_is_valid(wins[1]) then
--
--           -- fyler window exists, focus it
--           vim.api.nvim_set_current_win(wins[1])
--           return
--
--         end
--       end
--     end
--   end
--
--   -- Fyler not open, open it
--   local fyler = require("fyler")
--   fyler.open({ kind = "split_left_most" })
-- end)
--
-- local fyler_group = vim.api.nvim_create_augroup("FylerCustomSettings", { clear = true })
-- vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
--     group = fyler_group,
--     pattern = "*",
--     callback = function()
--         local current_buf = vim.api.nvim_get_current_buf()
--         local filetype = vim.bo[current_buf].filetype
--         local bufname = vim.api.nvim_buf_get_name(current_buf)
--
--         -- 邏輯：如果是 filetype 是 fyler 或者 檔名包含 fyler
--         if filetype == "fyler" or bufname:match("fyler") then
--             vim.opt_local.number = false        -- 關閉絕對行號
--             vim.opt_local.relativenumber = false -- 關閉相對行號
--         end
--     end,
-- })
-- local auto_close_group = vim.api.nvim_create_augroup("AutoCloseFyler", { clear = true })
-- vim.api.nvim_create_autocmd("BufEnter", {
--     group = auto_close_group,
--     -- 這裡使用 nested = true 是為了確保 quit 指令能正確觸發其他關閉事件（如果有需要的話）
--     nested = true, 
--     callback = function()
--         -- 1. 檢查目前視窗數量是否為 1
--         if vim.fn.winnr('$') == 1 then
--             -- 2. 獲取當前 Buffer 的資訊
--             local buf = vim.api.nvim_get_current_buf()
--             local ft = vim.bo[buf].filetype
--             local name = vim.api.nvim_buf_get_name(buf)
--
--             -- 3. 判斷邏輯：如果是 fyler (依據 filetype 或檔名)
--             if ft == "fyler" or name:match("fyler") then
--                 -- 4. 執行退出指令
--                 vim.cmd("quit")
--             end
--         end
--     end,
-- })



-- require "mini.indentscope".setup({
--   draw = {
--     delay = 50,
--   },
--
-- })
require "nvim-treesitter.configs".setup({ ensure_installed = { "python", "typescript", "tsx", "json" },
	highlight = { enable = true }
})

vim.keymap.set('n', '<c-t>', "<cmd>FzfLua files<CR>", { desc = "Find files" })
-- vim.keymap.set('n', '<leader>h', "<cmd>FzfLua helptags<CR>")
vim.keymap.set('n', '<c-f>', function()
  require('fzf-lua').live_grep({ cwd = vim.fn.expand('%:p:h') })
end, { desc = "Grep in current file directory" })



-- Colors are applied automatically based on user-defined highlight groups.
-- There is no default value.
-- vim.cmd.highlight('IndentLine guifg=#123456')
vim.api.nvim_set_hl(0, 'IndentLine', { fg = '#123456' })
-- Current indent line highlight
-- vim.cmd("lua IndentLineCurrent guifg=##00decf")
vim.api.nvim_set_hl(0, 'IndentLineCurrent', { fg = '#00decf' })

-- require("indentmini").setup()

-- blink.cmp 延遲到第一次進 insert mode 才 setup（補全只在插入模式用得到）。
-- 注意：blink 的 plugin/blink-cmp.lua 會在啟動時就跑 vim.lsp.config('*', {
-- capabilities = ... })，那 0.65 ms 省不掉也不該省 —— LSP client 在開檔時就啟動，
-- capabilities 必須在那之前註冊好。這裡延遲的只有 setup()（約 2.3 ms）。
vim.api.nvim_create_autocmd("InsertEnter", {
  group = vim.api.nvim_create_augroup("BlinkLazyLoad", { clear = true }),
  once = true,
  callback = function()
    require("blink.cmp").setup({
  signature = { enabled = true },
  completion = {
    documentation = { auto_show = true, auto_show_delay_ms = 100 },
    menu = {
      auto_show = true,
      draw = {
        treesitter = { "lsp" },
        columns = { { "kind_icon", "label", "label_description", gap = 1 }, { "kind" } },
      },
    },
  },
  fuzzy = {
  },
  keymap = {
    preset = 'none',
    ["<c-space>"] = { "show", "show_documentation", "hide_documentation" },
    ['<C-e>'] = { 'hide' },
    ['<CR>'] = { 'accept', 'fallback' },

    ["<tab>"] = {
      "select_next",
      "snippet_forward",
      "fallback",
    },
    ["<C-n>"] = {
      "select_next",
      "snippet_forward",
      "fallback",
    },
    ["<s-tab>"] = { "select_prev", "snippet_backward", "fallback" },
    ["<C-p>"] = { "select_prev", "snippet_backward", "fallback" },
    ["<down>"] = { "select_next", "fallback" },
    ["<up>"] = { "select_prev", "fallback" },
    ["<left>"] = { "fallback" },
    ["<right>"] = { "fallback" },

    ['<c-b>'] = { 'scroll_documentation_up', 'fallback' },
    ['<c-f>'] = { 'scroll_documentation_down', 'fallback' },
  },
  appearance = {
    -- use_nvim_cmp_as_default = true,
    nerd_font_variant = "mono",
  },
    })
  end,
})


require('hlchunk').setup({
  -- chunk = {
  --   enable = true
  -- },
  indent = {
    enable = true
  },
})

-- Copy over ssh
-- OSC52 clipboard: over SSH (SSH_TTY) and inside herdr (HERDR_ENV) — herdr
-- doesn't set SSH_TTY, so gate on it too or copy silently no-ops there.
if vim.env.SSH_TTY or vim.env.HERDR_ENV then
  local osc52 = require("vim.ui.clipboard.osc52")

  local function copy_reg(reg)
    local orig = osc52.copy(reg)
    return function(lines, regtype)
      -- Write to Vim's internal register
      vim.fn.setreg(reg, table.concat(lines, "\n"), regtype)

      -- Send OSC52 to local clipboard
      orig(lines, regtype)
    end
  end

	vim.g.clipboard = {
		name = "OSC 52 with register sync",
		copy = {
			["+"] = copy_reg("+"),
			["*"] = copy_reg("*"),
		},
		paste = {
			["+"] = function() return vim.fn.getreg("+"), "v" end,
			["*"] = function() return vim.fn.getreg("*"), "v" end,
		},
	}

	vim.o.clipboard = "unnamedplus"
end
