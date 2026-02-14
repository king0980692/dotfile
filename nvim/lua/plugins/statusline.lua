return {
	{
		"nvim-lualine/lualine.nvim",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
			"arkav/lualine-lsp-progress",
			"AndreM222/copilot-lualine",
		},
		event = "VeryLazy",
		opts = {
			extensions = { "lazy" },
			options = {
				component_separators = "",
				section_separators = "",
			},
			sections = {
				-- lualine_c = { 'filename', '%{coc#status()}' },
				lualine_c = { "filename", "lsp_progress" },
				lualine_x = { "copilot", "encoding", "filetype" },
				lualine_y = {},
				lualine_z = {},
			},
		},
	},
}
-- return {
--   { 'AndreM222/copilot-lualine' },
--   { 'arkav/lualine-lsp-progress' },
--   {
--   "nvim-lualine/lualine.nvim",
--   event = "VeryLazy",
--   dependencies = { "nvim-tree/nvim-web-devicons" },
--   config = function()
--     local lualine = require("lualine")
--     local lazy_status = require("lazy.status") -- to configure lazy pending updates count
--     local empty = require('lualine.component'):extend()
--
--     local colors = {
--       blue = "#65D1FF",
--       green = "#3EFFDC",
--       violet = "#FF61EF",
--       yellow = "#FFDA7B",
--       red = "#FF4A4A",
--       fg = "#c3ccdc",
--       bg = "#112638",
--       inactive_bg = "#2c3043",
--     }
--
--     local theme = {
--       normal = {
--         a = { bg = colors.blue, fg = colors.bg, gui = "bold" },
--         b = { bg = colors.bg, fg = colors.fg },
--         c = { bg = colors.bg, fg = colors.fg },
--       },
--       insert = {
--         a = { bg = colors.green, fg = colors.bg, gui = "bold" },
--         b = { bg = colors.bg, fg = colors.fg },
--         c = { bg = colors.bg, fg = colors.fg },
--       },
--       visual = {
--         a = { bg = colors.violet, fg = colors.bg, gui = "bold" },
--         b = { bg = colors.bg, fg = colors.fg },
--         c = { bg = colors.bg, fg = colors.fg },
--       },
--       command = {
--         a = { bg = colors.yellow, fg = colors.bg, gui = "bold" },
--         b = { bg = colors.bg, fg = colors.fg },
--         c = { bg = colors.bg, fg = colors.fg },
--       },
--       replace = {
--         a = { bg = colors.red, fg = colors.bg, gui = "bold" },
--         b = { bg = colors.bg, fg = colors.fg },
--         c = { bg = colors.bg, fg = colors.fg },
--       },
--       inactive = {
--         a = { bg = colors.inactive_bg, fg = colors.semilightgray, gui = "bold" },
--         b = { bg = colors.inactive_bg, fg = colors.semilightgray },
--         c = { bg = colors.inactive_bg, fg = colors.semilightgray },
--       },
--     }
--     -- Put proper separators and gaps between components in sections
--     local function process_sections(sections)
--       for name, section in pairs(sections) do
--         local left = name:sub(9, 10) < 'x'
--         for pos = 1, name ~= 'lualine_z' and #section or #section - 1 do
--           table.insert(section, pos * 2, { empty, color = { fg = colors.white, bg = colors.white } })
--         end
--         for id, comp in ipairs(section) do
--           if type(comp) ~= 'table' then
--             comp = { comp }
--             section[id] = comp
--           end
--           comp.separator = left and { right = '' } or { left = '' }
--         end
--       end
--       return sections
--     end
--
--     local function modified()
--       if vim.bo.modified then
--         return '+'
--       elseif vim.bo.modifiable == false or vim.bo.readonly == true then
--         return '-'
--       end
--       return ''
--     end
--
--     local function search_result()
--       if vim.v.hlsearch == 0 then
--         return ''
--       end
--       local last_search = vim.fn.getreg('/')
--       if not last_search or last_search == '' then
--         return ''
--       end
--       local searchcount = vim.fn.searchcount { maxcount = 9999 }
--       return last_search .. '(' .. searchcount.current .. '/' .. searchcount.total .. ')'
--     end
--
--     -- configure lualine with modified theme
--     lualine.setup({
--       options = {
--         theme = theme,
--         component_separators = '',
--         section_separators = { left = '', right = '' },
--       },
--       sections = process_sections {
--         lualine_a = { 'mode' },
--         lualine_b = {
--           { 'filename', file_status = false, path = 1 },
--           'branch',
--           -- 'diff',
--           function ()
--             return '󰅭 ' .. vim.pesc(tostring(#vim.tbl_keys(vim.lsp.buf_get_clients())) or '')
--           end,
--           { 'diagnostics', sources = { 'nvim_diagnostic' } },
--           { modified, color = { bg = colors.red } },
--           {
--             '%w',
--             cond = function()
--               return vim.wo.previewwindow
--             end,
--           },
--           {
--             '%r',
--             cond = function()
--               return vim.bo.readonly
--             end,
--           },
--           {
--             '%q',
--             cond = function()
--               return vim.bo.buftype == 'quickfix'
--             end,
--           },
--         },
--         lualine_c = {},
--         lualine_x = {
--           {
--             'copilot',
--             -- Default values
--             symbols = {
--               status = {
--                 icons = {
--                   enabled = " ",
--                   sleep = " ",   -- auto-trigger disabled
--                   disabled = " ",
--                   warning = " ",
--                   unknown = " "
--                 },
--                 hl = {
--                   -- enabled = "#50FA7B",
--                   enabled = require('copilot-lualine.colors').get_hl_value(0, "DiagnosticWarn", "fg"), -- hl value
--                   sleep = "#AEB7D0",
--                   disabled = "#6272A4",
--                   warning = "#FFB86C",
--                   unknown = "#FF5555"
--                 }
--               },
--               spinners = require("copilot-lualine.spinners").dots,
--               spinner_color = "#6272A4"
--             },
--             show_colors = false,
--             show_loading = true,
--             'fileformat',
--             'filetype',
--             'lsp_progress'
--           },
--
--         },
--         lualine_y = { search_result, 'filetype' },
--         lualine_z = {},
--       },
--       inactive_sections = {
--         lualine_c = { '%f %y %m' },
--         lualine_x = {},
--       }
--     })
--     end,
--   }
-- }
