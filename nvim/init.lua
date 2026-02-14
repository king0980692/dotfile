-- require("config.lazy")
-- require("config.option")

-- vim.o.statuscolumn = "%!v:lua.require('mystcol').statuscolumn()"
-- vim.o.statusline = "%#Normal#" .. "" .. "%="
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
  { src = "https://github.com/dstein64/nvim-scrollview" }

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


vim.keymap.set("n", "<leader>e", "<Cmd>Neotree left toggle<CR>")
vim.keymap.set("n", "<C-b>", "<Cmd>Neotree left toggle reveal_force_cwd<CR>")
vim.keymap.set("n", "<leader>E", "<Cmd>Neotree right toggle<CR>")

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
	}
})

vim.lsp.enable('pyright')
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
-- vim.cmd("colorscheme vague")
vim.cmd("colorscheme zaibatsu")
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
require "nvim-treesitter.configs".setup({ ensure_installed = { "python" },
	highlight = { enable = true }
})

vim.keymap.set('n', '<c-t>', ":Pick files<CR>")
-- vim.keymap.set('n', '<leader>h', ":Pick help<CR>")
vim.keymap.set('n', '<c-f>', ":Pick grep_live<CR>" )

 
vim.keymap.set('n', '<c-f>', function()
  require('mini.pick').builtin.grep_live({}, { source = { cwd = vim.fn.expand('%:p:h') } })
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
    -- Do NOT use OSC52 paste, just use internal registers paste = {
      ["+"] = function() return vim.fn.getreg('+'), 'v' end,
      ["*"] = function() return vim.fn.getreg('*'), 'v' end,
    
  }

  vim.o.clipboard = "unnamedplus"
  end
