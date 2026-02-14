return {
    "jpalardy/vim-slime",
    event = "BufRead",
    config = function()
      vim.g.slime_target = "tmux"
      vim.g.slime_default_config = { socket_name = "default", target_pane = "{last}" }
      vim.g.slime_dont_ask_default = 1
      vim.g.slime_cell_delimiter = "# %%"
      vim.g.slimve_bracketed_paste = 1
      vim.g.slime_no_mappings = 1
      vim.g.slime_python_ipython = 0

      vim.keymap.set("n", "<C-c><C-c>", "<Plug>SlimeLineSend", { silent = false })
      vim.keymap.set("x", "<C-c><C-c>", "<Plug>SlimeRegionSend", { silent = false })

    end
}
