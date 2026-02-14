-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.g.mapleader = " "

vim.keymap.set({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })
vim.keymap.set("i", "jj", "<Esc>")

-- xnoremap p "_dP轉換成 neovim lua
vim.keymap.set("x", "p", '"_dP', { noremap = true, silent = true })
vim.keymap.set("n", "<M-w>n", "<cmd>bp <CR>", { silent = false })
vim.keymap.set("n", "<M-w>m", "<cmd>bp <CR>", { silent = false })
vim.keymap.set("n", "<M-w>.", "<cmd>bn <CR>", { silent = false })
vim.keymap.set("n", "<M-w>/", "<cmd>bn <CR>", { silent = false })
vim.keymap.set("n", "<M-w>x", "<cmd>bd <CR>", { silent = false })

vim.keymap.set("n", "H", "<cmd>bp <CR>", { silent = false })
vim.keymap.set("n", "L", "<cmd>bn <CR>", { silent = false })

vim.keymap.set("n", "<C-b>", "Obreakpoint()<Esc>", { noremap = true, silent = true })
vim.keymap.set("i", "<C-b>", "breakpoint()<Esc>", { noremap = true, silent = true })

vim.keymap.set("n", "<C-d>", "<C-d>zz", { noremap = true, silent = true })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { noremap = true, silent = true })

vim.keymap.set("n", "<F3>", "<cmd>set clipboard+=unnamedplus<cr>")


vim.keymap.set("n", "<M-h>", require("nvim-tmux-navigation").NvimTmuxNavigateLeft)
vim.keymap.set("n", "<M-j>", require("nvim-tmux-navigation").NvimTmuxNavigateDown)
vim.keymap.set("n", "<M-k>", require("nvim-tmux-navigation").NvimTmuxNavigateUp)
vim.keymap.set("n", "<M-l>", require("nvim-tmux-navigation").NvimTmuxNavigateRight)

vim.keymap.set("i", "<M-h>", require("nvim-tmux-navigation").NvimTmuxNavigateLeft)
vim.keymap.set("i", "<M-j>", require("nvim-tmux-navigation").NvimTmuxNavigateDown)
vim.keymap.set("i", "<M-k>", require("nvim-tmux-navigation").NvimTmuxNavigateUp)
vim.keymap.set("i", "<M-l>", require("nvim-tmux-navigation").NvimTmuxNavigateRight)

vim.keymap.set("n", "<C-c><C-c>", "<Plug>SlimeLineSend", { silent = false })
vim.keymap.set("x", "<C-c><C-c>", "<Plug>SlimeRegionSend", { silent = false })
