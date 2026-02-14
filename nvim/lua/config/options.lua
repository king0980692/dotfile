vim.cmd("let g:netrw_liststyle = 3")

vim.g.ai_cmp = true

-- lsp_line: https://git.sr.ht/~whynothugo/lsp_lines.nvim
-- vim.diagnostic.config({
-- 	virtual_lines = { virtual_lines = false, only_current_line = true, highlight_whole_line = false },
-- })

local opt = vim.opt

opt.undofile = true
opt.undolevels = 10000
opt.updatetime = 200 -- Save swap file and trigger CursorHold

opt.viminfo:append("n")

-- opt.guicursor = 'n-v-c-sm-i-ci-ve:block,r-cr-o:hor20,a:blinkwait900-blinkoff000-blinkon850-Cursor/lCursor'
-- -- opt.guicursor = 'n-v-sm-ve:block,r-cr-o:hor20,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor'
-- opt.guicursor = 'n-v-c-sm:block,ci-ve:ver25,r-cr-o:hor20,i:block-blinkwait700-blinkoff400-blinkon250-Cursor/lCursor'
-- opt.guicursor = {
--   'n-v-sm-ve:block-Cursor/lCursor',
--   'r-cr-o:hor20-Cursor/lCursor',
--   'a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor',
-- }

-- opt.guicursor:append('v-sm:block-ModesVisual')
-- opt.guicursor:append('i-ci-ve:ver25-ModesInsert')
-- opt.guicursor:append('r-cr-o:hor20-ModesOperator')

opt.scrolloff = 5
opt.colorcolumn = "80" -- Line lenght marker at 80 columns

opt.relativenumber = false
opt.number = true

-- tabs & indentation
-- opt.tabstop = 2 -- 2 spaces for tabs (prettier default)
-- opt.shiftwidth = 2 -- 2 spaces for indent width
opt.expandtab = true -- expand tab to spaces
opt.autoindent = true -- copy indent from current line when starting new one
opt.softtabstop = 4 -- number of spaces a <Tab> counts for. When 0, feature is off (sts).

opt.tabstop = 4 -- size of a hard tabstop (ts).
opt.shiftwidth = 4 -- size of an indentation (sw).

opt.wrap = false

-- search settings
opt.ignorecase = true -- ignore case when searching
opt.smartcase = true -- if you include mixed case in your search, assumes you want case-sensitive

opt.cursorline = true

-- turn on termguicolors for tokyonight colorscheme to work
-- (have to use iterm2 or any other true color terminal)
opt.termguicolors = true
opt.background = "dark" -- colorschemes that can be light or dark will be made dark
opt.signcolumn = "yes" -- show sign column so that text doesn't shift

-- backspace
opt.backspace = "indent,eol,start" -- allow backspace on indent, end of line or insert mode start position

-- clipboard
-- opt.clipboard:append("unnamedplus") -- use system clipboard as default register

-- split windows
opt.splitright = true -- split vertical window to the right
opt.splitbelow = true -- split horizontal window to the bottom

-- turn off swapfile
-- opt.swapfile = false
