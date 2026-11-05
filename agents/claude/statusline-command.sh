#!/usr/bin/env bash
# Claude Code statusline mirroring the starship prompt:
#   - [model][dir][ branch][git status][5h/7d/F usage gauges]
input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -n "$cwd" ] || cwd=$PWD

# directory: ~ for home, last 4 components (starship truncation_length = 4)
dir=${cwd/#$HOME/\~}
IFS=/ read -ra parts <<<"$dir"
if [ "${#parts[@]}" -gt 4 ]; then
	dir=$(IFS=/; printf '%s' "${parts[*]: -4}")
fi
model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // empty')
model_id=$(printf '%s' "$input" | jq -r '.model.id // empty')
effort=$(printf '%s' "$input" | jq -r '.model.effort_level // .effort_level // empty')
if [ -z "$effort" ] && [ -n "$model_id" ]; then
	effort=$(jq -r --arg id "$model_id" '.modelSettings[$id].effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)
fi
out=""
if [ -n "$model" ]; then
	out=$(printf '[\033[1;33m%s\033[0m' "$model")
	[ -n "$effort" ] && out+=$(printf ' · \033[36m%s\033[0m' "$effort")
	out+=']'
fi
out+=$(printf '[\033[36m%s\033[0m]' "$dir")

# git branch + status (no optional locks)
if branch=$(bash "$HOME/.config/leon_scripts/git-branch-short.sh" 32 "$cwd"); then
	out+=$(printf '[\033[35m %s\033[0m]' "$branch")
	st=$(git -C "$cwd" --no-optional-locks status --porcelain=v1 -b 2>/dev/null)
	flags=""
	untracked=$(grep -c '^??' <<<"$st")
	staged=$(grep -c '^[MADRC]' <<<"$st")
	modified=$(grep -c '^.[MD]' <<<"$st")
	renamed=$(grep -c '^R' <<<"$st")
	conflicted=$(grep -c -E '^(UU|AA|DD|AU|UA|DU|UD)' <<<"$st")
	[ "$untracked" -gt 0 ] && flags+=$'\033[31m?\033[0m'
	[ "$staged" -gt 0 ] && flags+=$'\033[32m+\033[0m'
	[ "$modified" -gt 0 ] && flags+=$'\033[33m!\033[0m'
	[ "$renamed" -gt 0 ] && flags+=$'\033[34m»\033[0m'
	[ "$conflicted" -gt 0 ] && flags+=$'\033[1;31m✖\033[0m'
	ahead=$(sed -n '1s/.*ahead \([0-9]*\).*/\1/p' <<<"$st")
	behind=$(sed -n '1s/.*behind \([0-9]*\).*/\1/p' <<<"$st")
	[ -n "$ahead" ] && flags+=$'\033[36m⇡'"$ahead"$'\033[0m'
	[ -n "$behind" ] && flags+=$'\033[33m⇣'"$behind"$'\033[0m'
	[ -n "$flags" ] && out+="[$flags]"
fi

# Claude plan usage gauges (cached, ~7ms)
usage=$("$HOME/.config/leon_scripts/claude-usage.sh" 2>/dev/null)
[ -n "$usage" ] && out+="[$usage]"

printf '%s\n' "$out"
