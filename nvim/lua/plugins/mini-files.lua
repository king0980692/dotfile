return {
	"echasnovski/mini.files",
	config = function()
		require("mini.files").setup({
			mappings = {
				close = "q",
				go_in_plus = "<CR>",
			},
			windows = {
				max_number = math.huge,
				preview = true,
				-- border = "solid",
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
	end,
}
