#!/usr/bin/env python3
"""Offline dashboard data and rendering; Atuin is opened read-only.

Counts estimate direct shell invocations in all retained, non-deleted Atuin
history (including synced hosts), not process telemetry. No history text is
written to the dashboard snapshot. Python 3.9+; no third-party dependencies.
"""
import collections
import datetime as dt
import json
import os
from pathlib import Path
import re
import shlex
import sqlite3
import subprocess
import sys
import unicodedata


def clean(value):
    # Tool metadata must not inject terminal controls or fzf field separators.
    return ''.join(c for c in str(value) if unicodedata.category(c)[0] != 'C')


def mise_json(*args):
    result = subprocess.run(['mise', *args], capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise RuntimeError(clean(result.stderr.strip()) or 'mise 無法讀取套件狀態')
    return json.loads(result.stdout)


def aliases_from_shell(text):
    aliases = {}
    for line in text.splitlines():
        try:
            parts = shlex.split(line)
            if len(parts) == 2 and parts[0] == 'alias' and '=' in parts[1]:
                name, expansion = parts[1].split('=', 1)
                aliases[name] = expansion
        except ValueError:
            pass
    return aliases


def command_names(command, aliases=None, seen=()):
    """Conservative best effort: command positions, pipes, assignments, wrappers.

    Do not evaluate history or count argument strings such as `echo rg` or
    `bash -c 'rg ...'`. Shell functions/substitutions are not expanded.
    """
    aliases = aliases or {}
    try:
        lex = shlex.shlex(command, posix=True, punctuation_chars=';&|()<>\n')
        lex.whitespace = lex.whitespace.replace('\n', '')
        tokens = list(lex)
    except ValueError:
        return
    start, redirect = True, False
    wrapper_arg, wrapper = False, ''
    for token in tokens:
        if token in (';', ';;', '&&', '||', '|', '|&', '&', '(', ')') or token.strip('\n') == '':
            start, redirect, wrapper_arg = True, False, False
            wrapper = ''
            continue
        if token in ('>', '>>', '<', '<<', '<<<', '>&', '<&', '&>'):
            redirect = True
            continue
        if redirect:
            redirect = False
            continue
        if not start:
            continue
        if wrapper_arg:
            wrapper_arg = False
            continue
        if re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', token):
            continue
        if token in ('if', 'then', 'elif', 'else', 'do', 'while', 'until', '!', '{', '}'):
            continue
        if token in ('sudo', 'env', 'command', 'exec', 'nohup', 'time', 'nice'):
            # Common wrappers; option operands such as sudo -u are skipped below.
            wrapper = token
            continue
        if token.startswith('-'):
            wrapper_arg = token in {
                'sudo': ('-u', '-g', '-C', '--user', '--group', '--chdir'),
                'env': ('-u', '-C', '--unset', '--chdir'),
                'nice': ('-n', '--adjustment'),
            }.get(wrapper, ())
            continue
        start = False
        if token in aliases and token not in seen:
            yield from command_names(aliases[token], aliases, (*seen, token))
        else:
            yield token


def history_counts(owners, aliases, db_path):
    counts, recent, last = collections.Counter(), collections.Counter(), {}
    cutoff = int((dt.datetime.now().timestamp() - 30 * 86400) * 1e9)
    meta = {'available': False, 'entries': 0, 'hosts': 0, 'since': None}
    if not db_path.is_file():
        meta['error'] = '找不到 Atuin history.db；使用量顯示 —'
        return counts, recent, last, meta
    try:
        with sqlite3.connect(db_path.resolve().as_uri() + '?mode=ro', uri=True, timeout=1) as db:
            entries, hosts, since = db.execute(
                'SELECT count(*), count(DISTINCT hostname), min(timestamp) '
                'FROM history WHERE deleted_at IS NULL').fetchone()
            meta.update(available=True, entries=entries, hosts=hosts, since=since)
            for command, stamp in db.execute(
                    'SELECT command, timestamp FROM history WHERE deleted_at IS NULL'):
                for name in command_names(command, aliases):
                    # Explicit paths outside mise are not evidence of mise usage.
                    if '/' in name:
                        matches = owners.get(os.path.realpath(os.path.expanduser(name)), ()) if name.startswith(('/', '~')) else ()
                    else:
                        matches = owners.get(name, ())
                    for tool in matches:
                        counts[tool] += 1
                        if stamp >= cutoff:
                            recent[tool] += 1
                        last[tool] = max(last.get(tool, 0), stamp)
    except (sqlite3.Error, OSError) as error:
        meta.update(available=False, error='無法讀取 Atuin 歷史：' + clean(error))
        counts, recent, last = collections.Counter(), collections.Counter(), {}
    return counts, recent, last, meta


def snapshot(state):
    tools = mise_json('ls', '--global', '--json')
    rows, roots = [], {}
    for name, versions in tools.items():
        # Retain all installed versions, and prefer the globally selected version.
        selected = next((v for v in versions if v.get('active')), versions[-1])
        installed = [v for v in versions if v.get('installed')]
        row = dict(name=name, version=selected['version'],
                   requested=selected.get('requested_version', ''),
                   installed=bool(selected.get('installed')), versions=[v['version'] for v in installed],
                   path=selected.get('install_path', ''),
                   source=(selected.get('source') or {}).get('path', ''), commands=[])
        rows.append(row)
        for version in installed:
            path = version.get('install_path')
            if path:
                roots[os.path.realpath(path)] = name
    # Resolve executable ownership from mise rather than guessing rg/ripgrep etc.
    specs = [name + '@' + v['version'] for name, versions in tools.items()
             for v in versions if v.get('installed')]
    bins = mise_json('bin-paths', '--json', *specs) if specs else []
    owners = collections.defaultdict(set)
    by_name = {r['name']: r for r in rows}
    for binary in bins:
        path = os.path.realpath(binary['path'])
        parent = Path(path).parent
        tool = None
        # A binary may itself be a symlink outside its install root (e.g. rustup).
        for candidate in (Path(binary['path']).parent, parent):
            for ancestor in (candidate, *candidate.parents):
                tool = roots.get(os.path.realpath(ancestor))
                if tool:
                    break
            if tool:
                break
        if tool:
            owners[binary['name']].add(tool)
            owners[path].add(tool)
            by_name[tool]['commands'].append(binary['name'])
    data_home = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share')))
    db_path = Path(os.environ.get('MISE_DASH_HISTORY_DB', str(data_home / 'atuin/history.db'))).expanduser()
    aliases = aliases_from_shell(os.environ.get('MISE_DASH_ALIASES', ''))
    counts, recent, last, history = history_counts(owners, aliases, db_path)
    for row in rows:
        name = row['name']
        row.update(uses=counts[name], recent=recent[name], last=last.get(name),
                   commands=sorted(set(row['commands'])))
    data = {'tools': rows, 'history': history}
    (state / 'data.json').write_text(json.dumps(data))


def color(text, code):
    return '\033[' + code + 'm' + clean(text) + '\033[0m'


def date(stamp):
    return dt.datetime.fromtimestamp(stamp / 1e9).strftime('%Y-%m-%d') if stamp else '—'


def render_rows(data, sort):
    rows = data['tools']
    keys = {'usage': lambda r: (-r['uses'], r['name']),
            'name': lambda r: r['name'], 'recent': lambda r: (-r['recent'], -r['uses'], r['name'])}
    rows = sorted(rows, key=keys[sort])
    cols = int(os.environ.get('MISE_DASH_COLUMNS', '100'))
    width = max(16, min(32, (int(cols * .62) if cols >= 125 else cols) - 62))
    graph_width = 8 if cols >= 90 else 4
    peak = max((r['uses'] for r in rows), default=0)
    title = {'usage': '總次數 ↓', 'recent': '30 天 ↓', 'name': '名稱 ↑'}[sort]
    print('id\t' + f'{"PACKAGE":<{width}}  {"VERSION":<13}  {"STATUS":<9}  {"USES":>6}  {"30D":>5}  {title}')
    available = data['history']['available']
    for row in rows:
        name = row['name']
        display = name if len(name) <= width else name[:width - 1] + '…'
        status = color('installed', '32') if row['installed'] else color('missing  ', '31')
        uses = str(row['uses']) if available else '—'
        recent = str(row['recent']) if available else '—'
        size = max(1, round(row['uses'] / peak * graph_width)) if peak and row['uses'] else 0
        graph = color('▰' * size, '36') + color('▱' * (graph_width - size), '90')
        print(clean(name) + '\t' + f'{display:<{width}}  {clean(row["version"])[:13]:<13}  {status}  {uses:>6}  {recent:>5}  {graph}')


def render_header(data):
    rows, h = data['tools'], data['history']
    installed = sum(r['installed'] for r in rows)
    used = sum(r['uses'] > 0 for r in rows)
    print(color(' GLOBAL PACKAGES', '1;36') + color('  /  Installed & usage overview', '90'))
    print(f' {len(rows)} packages   ·   {installed} installed   ·   {len(rows) - installed} missing   ·   ' +
          (f'{used} seen in history' if h['available'] else 'usage unavailable'))
    if h['available']:
        print(color(f' Atuin  {h["entries"]:,} 筆 · {h["hosts"]} 台主機 · 自 {date(h["since"])} · 指令使用量估計', '90'))
    else:
        print(color(' ' + h.get('error', '歷史紀錄不可用'), '33'))


def render_preview(data, name):
    row = next((r for r in data['tools'] if r['name'] == name), None)
    if not row:
        print('選取套件以查看詳細資料；Ctrl-A 搜尋安裝新套件。')
        return
    print(color(row['name'], '1;36'))
    print(color('● 已安裝' if row['installed'] else '○ 全域版本尚未安裝', '32' if row['installed'] else '31'))
    print('\n' + color('USAGE · Atuin 歷史估計', '1'))
    if data['history']['available']:
        print(f'總使用次數  {row["uses"]:,}\n最近 30 天  {row["recent"]:,}\n最後使用    {date(row["last"])}')
    else:
        print('— 歷史紀錄不可用')
    print('\n' + color('VERSION', '1'))
    print('目前版本  ' + clean(row['version']))
    print('版本設定  ' + clean(row['requested']))
    print('已裝版本  ' + clean(', '.join(row['versions']) or '—'))
    print('\n' + color('COMMANDS', '1'))
    print(clean(', '.join(row['commands']) or '—'))
    print('\n' + color('LOCATION', '1'))
    print(clean(row['path']) + '\n' + clean(row['source']))
    print()
    for line in ('統計依保留的 Atuin 紀錄，包含同步主機；',
                 '識別目前 alias、管線與常見指令前綴。',
                 '不含 shell 函式與程式內部啟動的工具；',
                 '同名指令無法確認當時來自 mise。',
                 '0 代表未在紀錄中辨識到，非從未使用。'):
        print(color(line, '90'))


def main():
    state = Path(os.environ['MISE_DASH_STATE'])
    action = sys.argv[1]
    if action == 'snapshot':
        snapshot(state)
        return
    data = json.loads((state / 'data.json').read_text())
    sort = (state / 'sort').read_text().strip()
    if action == 'cycle':
        modes = ['usage', 'recent', 'name']
        sort = modes[(modes.index(sort) + 1) % len(modes)]
        (state / 'sort').write_text(sort)
    if action in ('rows', 'cycle'):
        render_rows(data, sort)
    elif action == 'header':
        render_header(data)
    elif action == 'preview':
        render_preview(data, sys.argv[2] if len(sys.argv) > 2 else '')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print('mise dashboard: ' + clean(error), file=sys.stderr)
        sys.exit(1)
