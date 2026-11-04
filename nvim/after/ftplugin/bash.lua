-- buffer-local（vim.bo），避免縮排設定洩漏到其他 buffer。
-- 'smarttab' 是 global-only，已移到 init.lua。
vim.bo.expandtab = true
vim.bo.autoindent = true
vim.bo.smartindent = true
vim.bo.shiftwidth = 2
vim.bo.softtabstop = 2
vim.bo.tabstop = 2
