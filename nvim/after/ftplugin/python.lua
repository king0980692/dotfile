-- 用 vim.bo（buffer-local）而非 vim.opt，否則縮排設定會漏到之後所有沒有
-- ftplugin 的 buffer（txt / markdown / gitcommit …）。
-- 'smarttab' 是 global-only 選項，已移到 init.lua 設一次。
vim.bo.expandtab = true
vim.bo.autoindent = true
vim.bo.smartindent = true
vim.bo.shiftwidth = 4
vim.bo.softtabstop = 4
vim.bo.tabstop = 4
