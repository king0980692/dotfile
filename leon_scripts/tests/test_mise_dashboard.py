"""Run with python3 -m unittest discover -s leon_scripts/tests -p 'test_mise_dashboard.py'."""
import importlib.util
import os
from pathlib import Path
import sqlite3
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('dashboard', Path(__file__).parents[1] / 'mise-dashboard.py')
dashboard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dashboard)


class UsageTests(unittest.TestCase):
    def names(self, command, aliases=None):
        return list(dashboard.command_names(command, aliases))

    def test_command_positions_and_wrappers(self):
        self.assertEqual(self.names('X=1 rg needle . | bat; sudo -u root fd x && env A=b nvim'),
                         ['rg', 'bat', 'fd', 'nvim'])
        self.assertEqual(self.names('sudo -n rg x; nice -n 10 fd .'), ['rg', 'fd'])
        self.assertEqual(self.names('rg x\nfd y\n\nbat z'), ['rg', 'fd', 'bat'])

    def test_arguments_and_scripts_are_not_counted(self):
        self.assertEqual(self.names("echo 'rg x | bat'; bash -c 'fd x'; cat < x > out"),
                         ['echo', 'bash', 'cat'])
        self.assertEqual(self.names("rg 'unfinished"), [])

    def test_aliases_and_self_reference(self):
        aliases = dashboard.aliases_from_shell("alias v='nvim'\nalias lg='lazygit'\nalias rg='rg --smart-case'")
        self.assertEqual(self.names('v file; lg; rg x', aliases), ['nvim', 'lazygit', 'rg'])

    def test_history_excludes_deleted_and_counts_recent(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'history.db'
            now = time.time_ns()
            with sqlite3.connect(path) as db:
                db.execute('CREATE TABLE history (command TEXT, timestamp INTEGER, hostname TEXT, deleted_at INTEGER)')
                db.executemany('INSERT INTO history VALUES (?, ?, ?, ?)', [
                    ('rg x | bat', now, 'one', None),
                    ('v file; echo rg', now - 40 * 86400 * 10**9, 'two', None),
                    ('rg secret', now, 'one', now),
                    ('/usr/bin/rg x', now, 'one', None),
                ])
            owners = {'rg': {'ripgrep'}, 'bat': {'bat'}, 'nvim': {'neovim'}}
            counts, recent, last, meta = dashboard.history_counts(owners, {'v': 'nvim'}, path)
            self.assertEqual(dict(counts), {'ripgrep': 1, 'bat': 1, 'neovim': 1})
            self.assertEqual(dict(recent), {'ripgrep': 1, 'bat': 1})
            self.assertEqual(meta['entries'], 3)
            self.assertEqual(meta['hosts'], 2)
            self.assertEqual(last['ripgrep'], now)
            self.assertTrue(meta['available'])

    def test_missing_history_is_unavailable_not_zero(self):
        *_, meta = dashboard.history_counts({}, {}, Path('/nonexistent/atuin/history.db'))
        self.assertFalse(meta['available'])

    def test_snapshot_keeps_global_missing_version_and_maps_real_executable(self):
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp)
            tools = {
                'ripgrep': [{'version': '15', 'installed': True, 'active': True,
                             'install_path': tmp + '/rg/15'}],
                'missing': [{'version': '2', 'installed': False, 'active': True}],
            }
            binaries = [{'name': 'rg', 'path': tmp + '/rg/15/bin/rg'}]
            with patch.object(dashboard, 'mise_json', side_effect=[tools, binaries]), \
                    patch.dict('os.environ', {'MISE_DASH_HISTORY_DB': tmp + '/absent'}):
                dashboard.snapshot(state)
            data = dashboard.json.loads((state / 'data.json').read_text())
            self.assertEqual(data['tools'][0]['commands'], ['rg'])
            self.assertFalse(data['tools'][1]['installed'])
            self.assertFalse(data['history']['available'])


class NavigationTests(unittest.TestCase):
    def test_actions_work_with_no_filtered_package(self):
        # fzf --expect prints the requested key but returns 1 on an empty list.
        # Exercise the actual shell controller without installing/removing tools.
        script = Path(__file__).parents[1] / 'mise-dashboard.sh'
        for key in ('ctrl-a', 'ctrl-r'):
            with self.subTest(key=key), tempfile.TemporaryDirectory() as tmp:
                directory = Path(tmp)
                stubs = {
                    'mise': '#!/bin/sh\nexit 0\n',
                    'python3': '#!/bin/sh\nexit 0\n',
                    'fzf': '#!/bin/sh\nif [ ! -f "$TEST_STATE/first" ]; then\n'
                           '  touch "$TEST_STATE/first"\n'
                           '  printf "%s\\n" "$TEST_KEY"\n  exit 1\nfi\n'
                           'touch "$TEST_STATE/returned"\nexit 130\n',
                    'bash': '#!/bin/sh\ncase "$1" in\n'
                            '  */mise-search-fzf.sh) touch "$TEST_STATE/installer" ;;\n'
                            '  *) exit 99 ;;\nesac\n',
                }
                for name, text in stubs.items():
                    path = directory / name
                    path.write_text(text)
                    path.chmod(0o755)
                env = dict(os.environ, PATH=tmp + ':' + os.environ['PATH'],
                           TEST_STATE=tmp, TEST_KEY=key)
                result = subprocess.run(['/bin/bash', str(script)], env=env,
                                        capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue((directory / 'returned').exists())
                self.assertEqual((directory / 'installer').exists(), key == 'ctrl-a')


if __name__ == '__main__':
    unittest.main()
