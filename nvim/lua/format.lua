-- 存檔自動格式化。
-- 規則：filetype 有對應的外部 formatter 且執行檔存在，就走 stdin/stdout；
-- 否則 fallback 到 LSP 的 textDocument/formatting。兩者都沒有就什麼都不做。
-- 由 init.lua 的 BufWritePre autocmd 在「第一次存檔」時才 require 進來。

local M = {}

-- filetype -> argv。"$FILE" 會換成 buffer 的實際路徑（prettier 這類靠副檔名決定
-- parser 的工具需要）。刻意用 list 而非字串：直接 exec，繞開 shell 跳脫問題。
-- 目前這些工具一個都沒裝，所以實際生效的是下面的 LSP fallback（ts_ls / jsonls）；
-- 哪天 mise install stylua / ruff 之後不用改這裡就會自動接上。
M.formatters = {
	lua = { "stylua", "-" },
	python = { "ruff", "format", "--stdin-filename", "$FILE", "-" },
	sh = { "shfmt", "-i", "4", "-" },
	bash = { "shfmt", "-i", "4", "-" },
	javascript = { "prettier", "--stdin-filepath", "$FILE" },
	javascriptreact = { "prettier", "--stdin-filepath", "$FILE" },
	typescript = { "prettier", "--stdin-filepath", "$FILE" },
	typescriptreact = { "prettier", "--stdin-filepath", "$FILE" },
	css = { "prettier", "--stdin-filepath", "$FILE" },
	html = { "prettier", "--stdin-filepath", "$FILE" },
	yaml = { "prettier", "--stdin-filepath", "$FILE" },
	markdown = { "prettier", "--stdin-filepath", "$FILE" },
}

-- 一律不碰的 filetype。jsonl 每行是獨立的一筆 JSON，任何 pretty printer 都會
-- 把整份檔案毀掉；gitcommit / gitrebase 則沒有格式化的意義。
M.ignore = {
	jsonl = true,
	gitcommit = true,
	gitrebase = true,
}

-- 只覆寫真正變動的那一段，頭尾相同的行原封不動。
-- 整份 nvim_buf_set_lines 會把 extmark（診斷、navic、hlchunk）連同 fold 一起重建，
-- 游標也會被推到奇怪的地方；這裡先剝掉共同前綴／後綴再寫回去。
local function apply(bufnr, new)
	local old = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	local s = 1
	while s <= #old and s <= #new and old[s] == new[s] do
		s = s + 1
	end
	if s > #old and s > #new then
		return -- 完全一樣，不用動
	end

	local e_old, e_new = #old, #new
	while e_old >= s and e_new >= s and old[e_old] == new[e_new] do
		e_old, e_new = e_old - 1, e_new - 1
	end

	local repl = {}
	for i = s, e_new do
		repl[#repl + 1] = new[i]
	end
	vim.api.nvim_buf_set_lines(bufnr, s - 1, e_old, false, repl)
end

function M.run(bufnr)
	if bufnr == nil or bufnr == 0 then
		bufnr = vim.api.nvim_get_current_buf()
	end

	local ft = vim.bo[bufnr].filetype
	if M.ignore[ft] then
		return
	end

	local cmd = M.formatters[ft]
	if cmd and vim.fn.executable(cmd[1]) == 1 then
		local argv = vim.deepcopy(cmd)
		local file = vim.api.nvim_buf_get_name(bufnr)
		for i, a in ipairs(argv) do
			if a == "$FILE" then
				argv[i] = file
			end
		end

		local input = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
		local out = vim.fn.systemlist(argv, input)

		if vim.v.shell_error ~= 0 then
			vim.notify(cmd[1] .. " 格式化失敗:\n" .. table.concat(out, "\n"), vim.log.levels.WARN)
			return
		end
		if out[#out] == "" then
			table.remove(out) -- stdout 結尾換行會多切出一個空字串
		end
		if #out == 0 then
			return -- 保險絲：formatter 沒吐東西時絕不清空 buffer
		end

		local view = vim.fn.winsaveview()
		apply(bufnr, out)
		vim.fn.winrestview(view)
		return
	end

	-- 沒有外部 formatter：問 LSP
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		if client:supports_method("textDocument/formatting") then
			vim.lsp.buf.format({ bufnr = bufnr, async = false })
			return
		end
	end
end

return M
