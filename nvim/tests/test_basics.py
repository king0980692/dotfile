"""Run: python3 nvim/tests/test_basics.py. Uses installed selections; never downloads plugins."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

CONFIG = Path(__file__).resolve().parents[1] / 'init.lua'
NVIM = shutil.which('nvim')
PLUGIN_SHIM = '''
local allowed = {['neovim-ayu']=true, ['mini.files']=true, ['mini.pick']=true,
  ['mini.surround']=true, ['mini.move']=true, ['mini.clue']=true,
  ['mini.icons']=true, ['mini.cursorword']=true, ['barbar.nvim']=true,
  ['nvim-treesitter']=true, ['nvim-ufo']=true, ['promise-async']=true,
  ['nvim-lspconfig']=true}
_G.test_selected_plugins = {}
vim.pack.add = function(specs, opts)
  for _, spec in ipairs(specs) do
    local name = spec.src:match('/([^/]+)$')
    assert(allowed[name], 'Unexpected plugin: ' .. tostring(name))
    test_selected_plugins[name] = true
    vim.cmd.packadd({name, bang=opts ~= nil and opts.load == false})
  end
end
'''


@unittest.skipUnless(NVIM, 'Neovim is not installed')
class Basics(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='nvim-basics-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root/'cache'/'nvim').mkdir(parents=True)
        self.env = dict(os.environ, XDG_STATE_HOME=str(self.root/'state'),
                        XDG_CACHE_HOME=str(self.root/'cache'))
        self.env.pop('SSH_TTY', None)
        self.env.pop('HERDR_ENV', None)

    def run_nvim(self, code, file=None, shada=None, before=None, env=None):
        script = self.root/'check.lua'
        script.write_text(code)
        command = [NVIM, '--headless', '-u', str(CONFIG), '-i', str(shada) if shada else 'NONE',
                   '--cmd', 'lua ' + PLUGIN_SHIM]
        if before:
            command += ['--cmd', 'lua ' + before]
        if file:
            command.append(str(file))
        command += ['-c', 'lua dofile(' + json.dumps(str(script)) + ')', '-c', 'qa!']
        result = subprocess.run(command, cwd=self.root, env=env or self.env,
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('Error', result.stderr, result.stderr)
        self.assertNotIn('E5108', result.stderr, result.stderr)

    def test_options_and_reload(self):
        self.run_nvim('''
local expected = {undofile=true, undolevels=10000, number=true, cursorline=true,
  termguicolors=true, wrap=false, tabstop=4, shiftwidth=4, softtabstop=4,
  expandtab=true, autoindent=true, ignorecase=true, smartcase=true,
  splitright=true, splitbelow=true, swapfile=false, scrolloff=15,
  updatetime=200, clipboard='unnamedplus', signcolumn='yes'}
for key, value in pairs(expected) do assert(vim.o[key] == value, key) end
assert(vim.g.mapleader == ' ')
assert(vim.g.colors_name == 'ayu')
for _, name in ipairs({'rust_analyzer', 'pyright', 'ts_ls', 'jsonls'}) do
  assert(vim.lsp.is_enabled(name), name)
end
assert(not package.loaded.mason)
assert(not vim.env.PATH:find('/nvim/mason/bin', 1, true))
for _, command in ipairs({'pyright-langserver', 'typescript-language-server', 'vscode-json-language-server'}) do
  assert(vim.fn.executable(command) == 1, command)
  assert(not vim.fn.exepath(command):find('/nvim/mason/', 1, true), command)
end
assert(not vim.o.grepprg:find('-uu', 1, true))
assert(vim.g.autoformat == nil, 'Do not silently enable format-on-save')
assert(vim.fn.exists(':BufferNext') == 2)
assert(vim.tbl_count(test_selected_plugins) == 11)
assert(not package.loaded.ufo, 'UFO was loaded before opening a file')
for _, path in ipairs(vim.api.nvim_list_runtime_paths()) do
  assert(not path:find('nvim%-ufo') and not path:find('promise%-async'), path)
end
assert(MiniFiles and MiniPick and MiniSurround and MiniMove and MiniClue and MiniIcons and MiniCursorword)
vim.cmd.source(vim.env.MYVIMRC)
for _, group in ipairs({'HighlightYank', 'RestoreCursor', 'NativeLspCompletion'}) do
  assert(#vim.api.nvim_get_autocmds({group=group}) == 1, group)
end
assert(vim.fn.exists(':W') == 2 and vim.fn.exists(':Q') == 2)
''')

    def test_shared_mise_typescript_fallback(self):
        dotfiles = CONFIG.parent.parent
        installed = subprocess.check_output(['mise', 'where', 'npm:typescript'],
                                            cwd=self.root, text=True).strip()
        expected = str(Path(installed)/'node_modules/typescript/lib/tsserver.js')
        self.assertIn('tsserver.fallbackPath = ' + json.dumps(expected),
                      (dotfiles/'helix'/'languages.toml').read_text())
        self.assertTrue(Path(expected).is_file())
        self.run_nvim('''
local config = vim.lsp.config.ts_ls.init_options.tsserver
assert(config.path == nil, 'Project TypeScript must retain priority')
assert(config.fallbackPath == ''' + json.dumps(expected) + ''')
''')

    def test_highlighter_and_lazy_folds(self):
        fixture = self.root/'highlight.lua'
        fixture.write_text('local M = {}\nfunction M.answer()\n  return 42\nend\nreturn M\n')
        self.run_nvim('''
assert(package.loaded.ufo, 'UFO was not loaded on first real file')
assert(vim.tbl_count(test_selected_plugins) == 13)
assert(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()], 'Native highlighter is inactive')
local parser = vim.treesitter.get_parser(0, 'lua')
assert(parser:parse()[1]:root():type() == 'chunk')
assert(vim.fn.exists(':UfoEnable') == 2)
local ufo = require('ufo')
assert(vim.wait(2000, function()
  ufo.closeAllFolds()
  return vim.fn.foldclosed(2) == 2
end, 50), 'UFO did not close the function fold')
ufo.openAllFolds()
assert(vim.fn.foldclosed(2) == -1)
''', fixture)

    def test_surround_keys(self):
        self.run_nvim('''
vim.api.nvim_buf_set_lines(0, 0, -1, false, {'word'})
vim.api.nvim_win_set_cursor(0, {1, 0})
vim.api.nvim_feedkeys('saiw)', 'mx', false)
assert(vim.api.nvim_get_current_line() == '(word)')
vim.api.nvim_feedkeys('sd)', 'mx', false)
assert(vim.api.nvim_get_current_line() == 'word')
''')

    def test_file_browser_and_picker(self):
        self.run_nvim('''
MiniFiles.open(vim.uv.cwd(), false)
assert(MiniFiles.get_explorer_state())
assert(MiniFiles.close())
vim.defer_fn(function() vim.api.nvim_input('<Esc>') end, 20)
MiniPick.start({source={items={'alpha', 'beta'}, name='test only'}})
assert(not MiniPick.is_picker_active())
''')

    def test_persistent_undo_and_redo(self):
        fixture = self.root/'fixture.txt'
        fixture.write_text('original\n')
        self.run_nvim('''
vim.api.nvim_buf_set_lines(0, 0, -1, false, {'original', 'added'})
vim.cmd.write()
assert(vim.fn.filereadable(vim.fn.undofile(vim.api.nvim_buf_get_name(0))) == 1)
''', fixture)
        self.run_nvim('''
assert(vim.fn.undotree().seq_last > 0, 'Undo tree was not loaded')
vim.cmd('silent undo')
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), {'original'}))
vim.cmd('silent redo')
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), {'original', 'added'}))
''', fixture)

    def test_buffer_keys(self):
        self.run_nvim('''
local initial = vim.api.nvim_get_current_buf()
local first = vim.api.nvim_create_buf(true, false)
local second = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(first, 'first.txt')
vim.api.nvim_buf_set_name(second, 'second.txt')
vim.api.nvim_set_current_buf(first)
vim.api.nvim_buf_delete(initial, {force=true})
local function press(key)
  vim.api.nvim_feedkeys(vim.keycode(key), 'mx', false)
end
press('L'); assert(vim.api.nvim_get_current_buf() == second, vim.inspect({current=vim.api.nvim_get_current_buf(), first=first, second=second, buffers=require('barbar.state').buffers}))
press('H'); assert(vim.api.nvim_get_current_buf() == first)
press('<C-Tab>'); assert(vim.api.nvim_get_current_buf() == second)
press('<C-S-Tab>'); assert(vim.api.nvim_get_current_buf() == first)
''')

    def test_save_and_escape_keys(self):
        fixture = self.root/'keys.txt'
        fixture.write_text('original\n')
        self.run_nvim('''
vim.api.nvim_buf_set_lines(0, 0, -1, false, {'changed'})
vim.api.nvim_feedkeys(vim.keycode('<C-s>'), 'mx', false)
assert(vim.deep_equal(vim.fn.readfile(vim.api.nvim_buf_get_name(0)), {'changed'}))
vim.api.nvim_feedkeys('ijj', 'mx', false)
assert(vim.api.nvim_get_current_line() == 'changed')
assert(vim.api.nvim_get_mode().mode == 'n')
''', fixture)

    def test_clipboard_operator_keys(self):
        self.run_nvim('''
local copied = {}
vim.g.clipboard = {
  name='test only',
  copy={['+']=function(lines, kind) copied={lines, kind} end,
        ['*']=function(lines, kind) copied={lines, kind} end},
  paste={['+']=function() return copied[1] or {}, copied[2] or 'v' end,
         ['*']=function() return copied[1] or {}, copied[2] or 'v' end},
}
vim.api.nvim_buf_set_lines(0, 0, -1, false, {'alpha beta'})
vim.api.nvim_win_set_cursor(0, {1, 0})
vim.api.nvim_feedkeys(' yiw', 'mx', false)
assert(vim.deep_equal(copied[1], {'alpha'}))
assert(vim.api.nvim_get_current_line() == 'alpha beta')
vim.api.nvim_feedkeys(' diw', 'mx', false)
assert(vim.api.nvim_get_current_line() == ' beta')
''')

    def test_restore_cursor_across_restart(self):
        fixture = self.root/'cursor.txt'
        fixture.write_text('line\n' * 50)
        shada = self.root/'cursor.shada'
        # Neovim excludes temporary directories from ShaDa by default.
        allow_fixture = "vim.opt.shada:remove({'r/tmp/', 'r/private/'})"
        self.run_nvim("vim.api.nvim_win_set_cursor(0, {30, 2})", fixture, shada, before=allow_fixture)
        self.run_nvim("assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), {30, 2}), vim.inspect({cursor=vim.api.nvim_win_get_cursor(0), mark=vim.api.nvim_buf_get_mark(0, '\"')}))", fixture, shada, before=allow_fixture)

    def test_osc52_linewise_copy_and_paste(self):
        env = dict(self.env, HERDR_ENV='1')
        before = "package.loaded['vim.ui.clipboard.osc52']={copy=function(reg) return function(lines, kind) _G.sent={reg, lines, kind} end end}"
        self.run_nvim('''
assert(vim.g.clipboard.name:find('OSC'))
vim.g.clipboard.copy['+']({'alpha', 'beta'}, 'V')
local lines, kind = vim.g.clipboard.paste['+']()
assert(vim.deep_equal(type(lines)=='table' and lines or vim.split(lines, '\\n'), {'alpha', 'beta'}))
assert(kind == 'V', 'Linewise clipboard register type was lost')
assert(sent[1] == '+' and sent[3] == 'V')
local block = vim.fn.nr2char(22) .. '2'
vim.g.clipboard.copy['*']({'ab', 'cd'}, block)
local star, star_kind = vim.g.clipboard.paste['*']()
assert(vim.deep_equal(star, {'ab', 'cd'}) and star_kind == block)
local plus, plus_kind = vim.g.clipboard.paste['+']()
assert(vim.deep_equal(plus, {'alpha', 'beta'}) and plus_kind == 'V')
vim.fn.setreg('+', {'through', 'provider'}, 'V')
assert(vim.deep_equal(vim.fn.getreg('+', 1, true), {'through', 'provider'}))
assert(vim.fn.getregtype('+') == 'V')
''', before=before, env=env)


if __name__ == '__main__':
    unittest.main(verbosity=2)
