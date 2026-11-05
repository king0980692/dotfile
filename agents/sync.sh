#!/usr/bin/env bash
# agents/sync.sh — put the coding agents' dotfile-managed settings in place.
#
#   agents/sync.sh          link / merge everything below (safe to re-run)
#   agents/sync.sh --check  only report what is in place and what is not
#   agents/sync.sh --copy   copy instead of symlink (also: --link to force links)
#
# Link or copy is decided by this machine's tier, a one-word file at
# ${XDG_STATE_HOME:-~/.local/state}/dotfiles/tier (minimal | medium | max,
# absent = max). max links, so an agent's edits land in the dotfiles and can be
# committed; medium and minimal copy, so the agents' own edits stay on that
# machine and are replaced (backed up first) by the next sync. Shared changes
# are made in agents/ on the max machine and pulled everywhere else.
#
# Linked or copied (one copy per machine, owned by agents/):
#   ~/.claude/{CLAUDE.md,RTK.md,statusline-command.sh}
#   ~/.pi/agent/{settings.json,keybindings.json,extensions/claude-style-status.ts}
#   ~/.claude/skills/<s>, ~/.codex/skills/<s>   for each agents/skills/<s>
#
# Merged (the agent and other tools write machine-specific data there too):
#   ~/.claude/settings.json = agents/claude/settings.base.json
#       + hooks this machine added itself (herdr's agent-state hook, which
#         herdr always writes with this machine's absolute path)
#       + keys the base does not have, e.g. autoMode, whose environment notes
#         name private repos and internal hosts — kept out of the (public) repo
#   ~/.codex/config.toml    = agents/codex/config.base.toml
#       + this machine's [projects.*], [hooks.state.*], [mcp_servers.*] and
#         [tui.model_availability_nux] sections, which Codex keeps adding to
#
# Never touched: credentials (auth.json, .credentials.json), history,
# sessions, Codex rules (per-machine approvals, may hold secrets), and the
# hook scripts rtk / herdr generate (re-create with `herdr integration
# install claude codex pi`).
#
# What a run replaces is kept under ~/.local/state/agents-sync-backups/<time>/
# at the same path relative to $HOME — not next to it, where an agent would
# load a backed-up skill or extension as a second copy.

set -u
here=$(cd "$(dirname "$0")" && pwd)
check=false
tier_file=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/tier
tier=$(cat "$tier_file" 2>/dev/null || echo max)
case $tier in max) copy=false ;; *) copy=true ;; esac
for arg in "$@"; do
	case $arg in
	--check) check=true ;;
	--copy) copy=true ;;
	--link) copy=false ;;
	*) echo "usage: $0 [--check] [--copy|--link]" >&2; exit 2 ;;
	esac
done
stamp=$(date +%Y%m%d-%H%M%S)
backups=${XDG_STATE_HOME:-$HOME/.local/state}/agents-sync-backups/$stamp
status=0

backup() { # backup <path under $HOME> — move it (mv) or copy it (cp) aside
	local how=$1 path=$2 to
	to="$backups/${path#"$HOME"/}"
	mkdir -p "$(dirname "$to")"
	"$how" -p "$path" "$to" 2>/dev/null || "$how" "$path" "$to"
	say backup "$path → $to"
}

say() { printf '  %-8s %s\n' "$1" "$2"; }

same() { # same <src> <dst> — dst is a real copy (not a link) with src's content
	[ ! -L "$2" ] && [ -e "$2" ] && diff -rq "$1" "$2" >/dev/null 2>&1
}

link() { # link <source in agents/> <target in $HOME> — or copy, see the top
	local src=$1 dst=$2
	if $copy; then
		if same "$src" "$dst"; then
			say ok "$dst (copy)"
			return
		fi
		if $check; then
			say STALE "$dst is not a current copy of $src"
			status=1
			return
		fi
		mkdir -p "$(dirname "$dst")"
		if [ -e "$dst" ] || [ -L "$dst" ]; then
			backup mv "$dst"
		fi
		cp -Rp "$src" "$dst"
		say copied "$dst"
		return
	fi
	if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
		say ok "$dst"
		return
	fi
	if $check; then
		say MISSING "$dst → $src"
		status=1
		return
	fi
	mkdir -p "$(dirname "$dst")"
	if [ -e "$dst" ] || [ -L "$dst" ]; then
		backup mv "$dst"
	fi
	ln -s "$src" "$dst"
	say linked "$dst"
}

merge() { # merge <kind> <base> <target>
	local kind=$1 base=$2 dst=$3 tmp
	tmp=$(mktemp)
	if ! python3 - "$kind" "$base" "$dst" >"$tmp" <<'PY'; then
import json, os, re, sys
kind, base, dst = sys.argv[1:4]
home = os.path.expanduser("~")
current = open(dst).read() if os.path.exists(dst) else ""

if kind == "claude":
    b = json.load(open(base))
    local = json.loads(current) if current.strip() else {}
    def norm(cmd):  # compare commands regardless of $HOME vs absolute path and quoting
        return re.sub(r"[\"']", "", cmd.replace("$HOME", home))
    base_cmds = {norm(h["command"]) for groups in b.get("hooks", {}).values()
                 for g in groups for h in g.get("hooks", [])}
    merged = dict(local)
    merged.update({k: v for k, v in b.items() if k != "hooks"})
    hooks = {k: list(v) for k, v in b.get("hooks", {}).items()}
    for event, groups in local.get("hooks", {}).items():
        for g in groups:
            extra = [h for h in g.get("hooks", []) if norm(h.get("command", "")) not in base_cmds]
            if extra:
                hooks.setdefault(event, []).append({**g, "hooks": extra})
    merged["hooks"] = hooks
    sys.stdout.write(json.dumps(merged, indent=2, ensure_ascii=False) + "\n")

elif kind == "codex":
    LOCAL = re.compile(r"^\[(projects\.|hooks\.state|tui\.model_availability_nux|mcp_servers\.)")
    blocks, cur = [], []
    for line in current.splitlines(keepends=True):
        if line.startswith("[") and cur:
            blocks.append(cur); cur = []
        cur.append(line)
    blocks.append(cur)
    local = [b for b in blocks if b and LOCAL.match(b[0])]
    out = open(base).read().rstrip() + "\n"
    if local:
        out += "\n# ---- machine-local: kept from this machine by agents/sync.sh ----\n\n"
        out += "".join("".join(b) for b in local).rstrip() + "\n"
    sys.stdout.write(out)
PY
		say ERROR "$dst: merge failed"
		rm -f "$tmp"
		status=1
		return
	fi
	if [ -f "$dst" ] && cmp -s "$tmp" "$dst"; then
		say ok "$dst (merged)"
		rm -f "$tmp"
		return
	fi
	if $check; then
		say STALE "$dst differs from agents/ — run agents/sync.sh"
		rm -f "$tmp"
		status=1
		return
	fi
	mkdir -p "$(dirname "$dst")"
	[ -e "$dst" ] && backup cp "$dst"
	cat "$tmp" >"$dst"
	rm -f "$tmp"
	say merged "$dst"
}

echo "(tier: $tier, $($copy && echo copying || echo linking))"
echo "Claude Code"
for f in CLAUDE.md RTK.md statusline-command.sh; do
	link "$here/claude/$f" "$HOME/.claude/$f"
done
merge claude "$here/claude/settings.base.json" "$HOME/.claude/settings.json"

echo "Codex"
merge codex "$here/codex/config.base.toml" "$HOME/.codex/config.toml"

echo "pi"
for f in settings.json keybindings.json extensions/claude-style-status.ts; do
	link "$here/pi/$f" "$HOME/.pi/agent/$f"
done

echo "Skills (Claude Code and Codex)"
for s in "$here"/skills/*/; do
	s=$(basename "$s")
	link "$here/skills/$s" "$HOME/.claude/skills/$s"
	link "$here/skills/$s" "$HOME/.codex/skills/$s"
done

exit $status
