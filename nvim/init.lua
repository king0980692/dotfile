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
	{ src = "https://github.com/vague2k/vague.nvim" },
	{ src = "https://github.com/nyoom-engineering/oxocarbon.nvim" },
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
	{ src = "https://github.com/echasnovski/mini.icons" },
	{ src = "https://github.com/echasnovski/mini.cursorword" },
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
  { src = "https://github.com/Mofiqul/vscode.nvim" },
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


require('mason').setup()
require('mason-lspconfig').setup()
require('mason-tool-installer').setup({
	ensure_installed = {
		"pyright",
		"ts_ls",
		"jsonls",
		"js-debug-adapter",
	}
})

local dap = require("dap")
local dapui = require("dapui")

local js_debug_path = vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js"

dap.adapters["pwa-node"] = {
	type = "server",
	host = "127.0.0.1",
	port = "${port}",
	executable = {
		command = "node",
		args = { js_debug_path, "${port}" },
	},
}

local node_launch_config = {
	type = "pwa-node",
	request = "launch",
	name = "Launch current file (Node)",
	program = "${file}",
	cwd = "${workspaceFolder}",
	stopOnEntry = true,
	console = "integratedTerminal",
	terminalWinCmd = "botright vertical 80new",
	sourceMaps = true,
	skipFiles = { "<node_internals>/**" },
}

local tsx_launch_config = {
	type = "pwa-node",
	request = "launch",
	name = "Launch current file (tsx)",
	runtimeExecutable = "npx",
	runtimeArgs = { "tsx" },
	program = "${file}",
	cwd = "${workspaceFolder}",
	stopOnEntry = true,
	console = "integratedTerminal",
	terminalWinCmd = "botright vertical 80new",
	sourceMaps = true,
	skipFiles = { "<node_internals>/**" },
}

for _, filetype in ipairs({ "javascript", "javascriptreact" }) do
	dap.configurations[filetype] = {
		vim.deepcopy(node_launch_config),
		{
			type = "pwa-node",
			request = "attach",
			name = "Attach to process",
			processId = require("dap.utils").pick_process,
			cwd = "${workspaceFolder}",
			sourceMaps = true,
			skipFiles = { "<node_internals>/**" },
		},
		{
			type = "pwa-node",
			request = "attach",
			name = "Attach to :9229",
			address = "localhost",
			port = 9229,
			cwd = "${workspaceFolder}",
			sourceMaps = true,
			skipFiles = { "<node_internals>/**" },
		},
	}
end

for _, filetype in ipairs({ "typescript", "typescriptreact" }) do
	dap.configurations[filetype] = {
		vim.deepcopy(tsx_launch_config),
		{
			type = "pwa-node",
			request = "attach",
			name = "Attach to process",
			processId = require("dap.utils").pick_process,
			cwd = "${workspaceFolder}",
			sourceMaps = true,
			skipFiles = { "<node_internals>/**" },
		},
		{
			type = "pwa-node",
			request = "attach",
			name = "Attach to :9229",
			address = "localhost",
			port = 9229,
			cwd = "${workspaceFolder}",
			sourceMaps = true,
			skipFiles = { "<node_internals>/**" },
		},
	}
end

dap.defaults.fallback.terminal_win_cmd = "botright vnew"

dapui.setup({
	layouts = {
		{
			elements = {
				{ id = "stacks", size = 0.55 },
				{ id = "watches", size = 0.45 },
			},
			size = 24,
			position = "left",
		},
		{
			elements = {
				{ id = "console", size = 0.35 },
				{ id = "repl", size = 0.65 },
			},
			size = 14,
			position = "bottom",
		},
	},
})
require("nvim-dap-virtual-text").setup()

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("DapUiWrap", { clear = true }),
	pattern = { "dapui_console", "dapui_watches", "dap-repl", "dap-float" },
	callback = function()
		vim.opt_local.wrap = true
		vim.opt_local.linebreak = true
	end,
})

vim.g.dap_mode_active = false
local dap_locked_buffers = {}
local clear_dap_session_keymaps
local unlock_dap_buffers
local dap_auto_zoomed_tmux = false

local function tmux_current_pane()
	return vim.env.TMUX_PANE
end

local function tmux_is_zoomed()
	local pane = tmux_current_pane()
	if pane == nil or pane == "" then
		return false
	end

	local result = vim.system({ "tmux", "display-message", "-p", "-t", pane, "#{window_zoomed_flag}" }, { text = true }):wait()
	return result.code == 0 and vim.trim(result.stdout or "") == "1"
end

local function enter_dap_tmux_zoom()
	local pane = tmux_current_pane()
	if pane == nil or pane == "" or tmux_is_zoomed() then
		return
	end

	local result = vim.system({ "tmux", "resize-pane", "-Z", "-t", pane }, { text = true }):wait()
	if result.code == 0 then
		dap_auto_zoomed_tmux = true
	end
end

local function leave_dap_tmux_zoom()
	local pane = tmux_current_pane()
	if not dap_auto_zoomed_tmux or pane == nil or pane == "" then
		return
	end

	vim.system({ "tmux", "resize-pane", "-Z", "-t", pane }, { text = true }):wait()
	dap_auto_zoomed_tmux = false
end

vim.api.nvim_create_user_command("DapSessionQuit", function()
	vim.g.dap_mode_active = false
	if dap.session() ~= nil then
		dap.terminate()
	else
		clear_dap_session_keymaps()
		clear_dap_mode_window_keymaps()
		unlock_dap_buffers()
		leave_dap_tmux_zoom()
		dapui.close()
	end
end, {})

vim.cmd([[cnoreabbrev <expr> q getcmdtype() == ':' && getcmdline() ==# 'q' && luaeval('vim.g.dap_mode_active') ? 'DapSessionQuit' : 'q']])

local dap_session_keymaps = {
	["<leader>o"] = { dap.step_out, "DAP step out" },
	["<leader>B"] = {
		function()
			dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
		end,
		"DAP conditional breakpoint",
	},
	["<leader>u"] = { dapui.toggle, "DAP UI toggle" },
	["<leader>t"] = { dap.terminate, "DAP terminate" },
	["<leader>p"] = { dap.repl.toggle, "DAP REPL toggle" },
}

local dap_mode_window_keymaps = {
	["<M-h>"] = "h",
	["<M-j>"] = "j",
	["<M-k>"] = "k",
	["<M-l>"] = "l",
}

local function set_dap_mode_window_keymaps()
	for lhs, direction in pairs(dap_mode_window_keymaps) do
		vim.keymap.set("n", lhs, function()
			vim.cmd("wincmd " .. direction)
		end, { silent = true, desc = "DAP local window move" })
		vim.keymap.set("i", lhs, function()
			vim.cmd("stopinsert")
			vim.cmd("wincmd " .. direction)
		end, { silent = true, desc = "DAP local window move" })
	end
end

local function clear_dap_mode_window_keymaps()
	for lhs, _ in pairs(dap_mode_window_keymaps) do
		pcall(vim.keymap.del, "n", lhs)
		pcall(vim.keymap.del, "i", lhs)
	end
end

local function get_visual_selection_text()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local start_row, start_col = start_pos[2], start_pos[3]
	local end_row, end_col = end_pos[2], end_pos[3]

	if start_row == 0 or end_row == 0 then
		return nil
	end

	if start_row > end_row or (start_row == end_row and start_col > end_col) then
		start_row, end_row = end_row, start_row
		start_col, end_col = end_col, start_col
	end

	local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
	if #lines == 0 then
		return nil
	end

	lines[1] = string.sub(lines[1], start_col)
	lines[#lines] = string.sub(lines[#lines], 1, end_col)
	return table.concat(lines, "\n")
end

local function add_watch_expression(expr)
	local text = expr and vim.trim(expr) or ""
	if text == "" then
		return
	end

	require("dapui.elements.watches").add(text)
	if vim.g.dap_mode_active then
		dapui.open()
	end
end

local function dap_next_or_search_next()
	if vim.v.hlsearch == 1 and vim.fn.getreg("/") ~= "" then
		vim.cmd("normal! n")
		return
	end

	dap.step_over()
end

local function is_dap_code_buffer(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end

	return vim.bo[bufnr].buftype == "" and vim.api.nvim_buf_get_name(bufnr) ~= ""
end

local function lock_dap_buffer(bufnr)
	if not is_dap_code_buffer(bufnr) then
		return
	end

	if dap_locked_buffers[bufnr] == nil then
		dap_locked_buffers[bufnr] = {
			modifiable = vim.bo[bufnr].modifiable,
			readonly = vim.bo[bufnr].readonly,
		}
	end

	vim.bo[bufnr].modifiable = false
	vim.bo[bufnr].readonly = true

	local opts = { buffer = bufnr, silent = true }
	vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR><Esc>", vim.tbl_extend("force", opts, { desc = "DAP clear search" }))
	vim.keymap.set("n", "n", dap_next_or_search_next, vim.tbl_extend("force", opts, { desc = "DAP next / search next" }))
	vim.keymap.set("n", "s", dap.step_into, vim.tbl_extend("force", opts, { desc = "DAP step into" }))
	vim.keymap.set("n", "c", dap.continue, vim.tbl_extend("force", opts, { desc = "DAP continue" }))
	vim.keymap.set("n", "b", dap.toggle_breakpoint, vim.tbl_extend("force", opts, { desc = "DAP breakpoint" }))
	vim.keymap.set("n", "L", dap.focus_frame, vim.tbl_extend("force", opts, { desc = "DAP focus current line" }))
end

unlock_dap_buffers = function()
	for bufnr, state in pairs(dap_locked_buffers) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.bo[bufnr].modifiable = state.modifiable
			vim.bo[bufnr].readonly = state.readonly
			pcall(vim.keymap.del, "n", "n", { buffer = bufnr })
			pcall(vim.keymap.del, "n", "<Esc>", { buffer = bufnr })
			pcall(vim.keymap.del, "n", "s", { buffer = bufnr })
			pcall(vim.keymap.del, "n", "c", { buffer = bufnr })
			pcall(vim.keymap.del, "n", "b", { buffer = bufnr })
			pcall(vim.keymap.del, "n", "L", { buffer = bufnr })
		end
	end

	dap_locked_buffers = {}
end

local function lock_all_dap_code_buffers()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		lock_dap_buffer(bufnr)
	end
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
	group = vim.api.nvim_create_augroup("DapSessionBufferLock", { clear = true }),
	callback = function(args)
		if vim.g.dap_mode_active then
			lock_dap_buffer(args.buf)
		end
	end,
})

local function set_dap_session_keymaps()
	for lhs, rhs in pairs(dap_session_keymaps) do
		vim.keymap.set("n", lhs, rhs[1], { desc = rhs[2], silent = true })
	end
end

clear_dap_session_keymaps = function()
	for lhs, _ in pairs(dap_session_keymaps) do
		pcall(vim.keymap.del, "n", lhs)
	end
end

dap.listeners.after.event_initialized["dapui_config"] = function()
	vim.g.dap_mode_active = true
	set_dap_session_keymaps()
	set_dap_mode_window_keymaps()
	lock_all_dap_code_buffers()
	enter_dap_tmux_zoom()
	dapui.open()
end
dap.listeners.before.event_terminated["dapui_config"] = function()
	if not vim.g.dap_mode_active then
		clear_dap_session_keymaps()
		clear_dap_mode_window_keymaps()
		unlock_dap_buffers()
		leave_dap_tmux_zoom()
		dapui.close()
	end
end
dap.listeners.before.event_exited["dapui_config"] = function()
	if not vim.g.dap_mode_active then
		clear_dap_session_keymaps()
		clear_dap_mode_window_keymaps()
		unlock_dap_buffers()
		leave_dap_tmux_zoom()
		dapui.close()
	end
end
dap.listeners.before.disconnect["dapui_config"] = function()
	vim.g.dap_mode_active = false
	clear_dap_session_keymaps()
	clear_dap_mode_window_keymaps()
	unlock_dap_buffers()
	leave_dap_tmux_zoom()
	dapui.close()
end

local function dap_continue_with_picker()
	if dap.session() ~= nil then
		dap.continue()
		return
	end

	if vim.g.dap_mode_active then
		dap.run_last()
		return
	end

	local configs = dap.configurations[vim.bo.filetype] or {}
	if #configs <= 1 then
		dap.continue()
		return
	end

	MiniPick.ui_select(configs, {
		prompt = "Debug configuration",
		format_item = function(item)
			return item.name
		end,
	}, function(choice)
		if choice ~= nil then
			dap.run(choice)
		end
	end, {
		window = {
			config = {
				width = math.max(50, math.floor(vim.o.columns * 0.3)),
				height = 7,
			},
		},
	})
end

vim.keymap.set("n", "<F5>", dap_continue_with_picker, { desc = "DAP continue" })
vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { desc = "DAP toggle breakpoint" })
vim.keymap.set("n", "<leader>w", function()
	add_watch_expression(vim.fn.expand("<cword>"))
end, { desc = "DAP add watch" })
vim.keymap.set("x", "w", function()
	add_watch_expression(get_visual_selection_text())
end, { desc = "DAP add watch from selection" })

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



-- require()
vim.cmd("colorscheme vague")
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
require "ufo".setup({
  provider_selector = function(bufnr, filetype, buftype)
    return {'treesitter', 'indent'}
  end
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

-- vim.keymap.set("n", "<leader>E", "<Cmd>Neotree right toggle<CR>")
require "mini.pick".setup({
  options = {
    -- Whether to show content from bottom to top
    content_from_bottom = false,

    -- Whether to cache matches (more speed and memory on repeated prompts)

    use_cache = false,
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

-- require "mini.indentscope".setup({
--   draw = {
--     delay = 50,
--   },
--
-- })
require "mini.pick".setup({
  window = {
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


require('hlchunk').setup({
  -- chunk = {
  --   enable = true
  -- },
  indent = {
    enable = true
  },
})

-- Copy over ssh
if vim.env.SSH_TTY then
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
