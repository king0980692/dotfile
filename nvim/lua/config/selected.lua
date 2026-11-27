-- Selected plugins only; versions match the pre-migration lockfile.
vim.g.barbar_auto_setup = false
vim.pack.add({
  { src = 'https://github.com/Shatur/neovim-ayu', version = 'e5a9f0fa2918d6b5f57c21b3ac014314ee5e41c8' },
  { src = 'https://github.com/echasnovski/mini.files', version = 'dce9a4e' },
  { src = 'https://github.com/echasnovski/mini.pick', version = '08a7220' },
  { src = 'https://github.com/echasnovski/mini.surround', version = '88c5229' },
  { src = 'https://github.com/echasnovski/mini.move', version = '4d21420' },
  { src = 'https://github.com/echasnovski/mini.clue', version = 'd846600' },
  { src = 'https://github.com/echasnovski/mini.icons', version = 'ff2e4f1' },
  { src = 'https://github.com/echasnovski/mini.cursorword', version = 'dda0f57' },
  { src = 'https://github.com/romgrk/barbar.nvim', version = '337ecfadb8bf005050990bf2f624dc4fc828dabd' },
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = '42fc28ba' },
  { src = 'https://github.com/neovim/nvim-lspconfig', version = '2010fc6' },
})
-- Herdr/tmux can swallow the terminal's OSC 11 appearance query.
if vim.env.HERDR_ENV or vim.env.TMUX then
  local path = (vim.env.XDG_RUNTIME_DIR or '/tmp') .. '/term-appearance'
  if vim.uv.fs_stat(path) then
    local appearance = (vim.fn.readfile(path) or {})[1]
    if appearance == 'light' or appearance == 'dark' then
      vim.o.background = appearance
    end
  end
end
require('ayu').setup({ mirage = false })
vim.cmd.colorscheme('ayu')

require('mini.icons').setup()
require('mini.icons').mock_nvim_web_devicons()
require('mini.cursorword').setup()
require('mini.files').setup({
  mappings = { go_in = 'l', go_out = 'h' },
  options = { use_as_default_explorer = true },
})
require('mini.pick').setup({ options = { use_cache = false } })
require('mini.surround').setup({
  mappings = { add = 'sa', delete = 'sd', replace = 'sr', find = 'sf',
    find_left = 'sF', highlight = 'sh', update_n_lines = 'sn' },
})
require('mini.move').setup({
  mappings = { left = '<', right = '>', down = '<S-j>', up = '<S-k>',
    line_left = '', line_right = '', line_down = '', line_up = '' },
})
local clue = require('mini.clue')
clue.setup({
  window = { delay = 100 },
  triggers = {
    { mode = 'n', keys = '<Leader>' }, { mode = 'x', keys = '<Leader>' },
    { mode = 'n', keys = 'g' }, { mode = 'x', keys = 'g' },
    { mode = 'n', keys = 'z' }, { mode = 'x', keys = 'z' },
    { mode = 'n', keys = "`" }, { mode = 'x', keys = "`" },
    { mode = 'n', keys = '[' }, { mode = 'n', keys = ']' },
    { mode = 'n', keys = 's' }, { mode = 'n', keys = '<C-w>' },
    { mode = 'i', keys = '<C-x>' },
  },
  clues = { clue.gen_clues.builtin_completion(), clue.gen_clues.g(),
    clue.gen_clues.marks(), clue.gen_clues.registers(),
    clue.gen_clues.windows(), clue.gen_clues.z() },
})
vim.keymap.set('n', '-', function()
  local path = vim.api.nvim_buf_get_name(0)
  MiniFiles.open(path ~= '' and path or vim.uv.cwd(), false)
end, { desc = 'Browse files' })
vim.keymap.set('n', '<C-t>', MiniPick.builtin.files, { desc = 'Find files' })
vim.keymap.set('n', '<C-f>', MiniPick.builtin.grep_live, { desc = 'Live grep' })

require('barbar').setup()
vim.keymap.set('n', 'H', '<Cmd>BufferPrevious<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', 'L', '<Cmd>BufferNext<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', '<C-Tab>', '<Cmd>BufferNext<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', '<C-S-Tab>', '<Cmd>BufferPrevious<CR>', { desc = 'Previous buffer' })

-- Keep the pinned parser installer, but use Neovim's native highlighter on 0.13.
require('nvim-treesitter.configs').setup({ auto_install = false })
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('SelectedTreesitter', { clear = true }),
  pattern = { 'rust', 'python', 'typescript', 'typescriptreact', 'javascript',
    'javascriptreact', 'json', 'jsonc', 'lua', 'sh', 'bash' },
  callback = function(args)
    -- Missing parsers must not prevent editing before explicit installation.
    pcall(vim.treesitter.start, args.buf)
  end,
})

vim.o.foldcolumn = '0'
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true
vim.api.nvim_create_autocmd('BufReadPost', {
  group = vim.api.nvim_create_augroup('UfoLazyLoad', { clear = true }),
  once = true,
  callback = function()
    vim.pack.add({
      { src = 'https://github.com/kevinhwang91/promise-async', version = '119e896' },
      { src = 'https://github.com/kevinhwang91/nvim-ufo', version = '72d54c3' },
    })
    require('ufo').setup({
      provider_selector = function() return { 'treesitter', 'indent' } end,
    })
    vim.keymap.set('n', '{', '<Cmd>foldclose<CR>', { desc = 'Close fold' })
    vim.keymap.set('n', '}', '<Cmd>foldopen<CR>', { desc = 'Open fold' })
    vim.keymap.set('n', 'zR', require('ufo').openAllFolds, { desc = 'Open all folds' })
    vim.keymap.set('n', 'zM', require('ufo').closeAllFolds, { desc = 'Close all folds' })
  end,
})

vim.lsp.config('pyright', {
  settings = {
    python = { analysis = { autoSearchPaths = true, diagnosticMode = 'workspace', useLibraryCodeForTypes = true } },
    pyright = { disableOrganizeImports = true },
  },
})
vim.lsp.config('ts_ls', {
  -- shortcut: pinned mise fallback; update both editor paths when upgrading TypeScript.
  init_options = { tsserver = {
    fallbackPath = vim.fn.expand('~/.local/share/mise/installs/npm-typescript/6.0.3/node_modules/typescript/lib/tsserver.js'),
  } },
})
vim.lsp.enable({ 'pyright', 'ts_ls', 'jsonls' })
