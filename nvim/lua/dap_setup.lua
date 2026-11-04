-- ============================================================================
-- DAP 設定（延遲載入）
--
-- 這個檔案在第一次 require("dap_setup") 時才會執行 —— Lua 的 require 本身就有
-- lazy + memoize 的特性，所以不需要包 wrapper function，也不用改 vim.pack.add。
-- 觸發點在 init.lua 的 <F5> / <leader>b / <leader>w / x-mode w 這幾個 keymap。
--
-- 回傳的 table 是給 init.lua 的 bootstrap keymap 用的 action 入口。
-- ============================================================================

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
-- 必須前向宣告：DapSessionQuit 這個 user command（下方）在 clear_dap_mode_window_keymaps
-- 的 local 定義之前就引用它。少了這行，closure 會編譯成 _G 查找 → nil → 呼叫
-- :DapSessionQuit（或 dap 模式下按 :q）會噴 "attempt to call a nil value"。
local clear_dap_mode_window_keymaps
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

clear_dap_mode_window_keymaps = function()
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

-- session 開始時被 DAP 蓋掉的原有映射，結束時要還原回去。
-- Vim 沒有 mapping 堆疊，單純 vim.keymap.del 會把原本的映射直接刪掉
-- （例如 init.lua 的 <leader>o = :update|:source，debug 過一次就永久失效）。
local saved_maps = {}

local function set_dap_session_keymaps()
	for lhs, rhs in pairs(dap_session_keymaps) do
		local old = vim.fn.maparg(lhs, "n", false, true)
		saved_maps[lhs] = (type(old) == "table" and not vim.tbl_isempty(old)) and old or nil
		vim.keymap.set("n", lhs, rhs[1], { desc = rhs[2], silent = true })
	end
end

clear_dap_session_keymaps = function()
	for lhs, _ in pairs(dap_session_keymaps) do
		pcall(vim.keymap.del, "n", lhs)
		-- 原本有映射的還原回去；原本沒有的就維持刪除狀態
		if saved_maps[lhs] then
			pcall(vim.fn.mapset, saved_maps[lhs])
		end
	end
	saved_maps = {}
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

return {
	continue = dap_continue_with_picker,
	toggle_breakpoint = dap.toggle_breakpoint,
	watch_cword = function()
		add_watch_expression(vim.fn.expand("<cword>"))
	end,
	watch_selection = function()
		add_watch_expression(get_visual_selection_text())
	end,
}
