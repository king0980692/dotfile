#!/usr/bin/env bash
# Print the current git branch (or short sha when detached), eliding the
# middle when it is longer than $1 (default 32) chars:
#   feature/very-long-branch-name-for-testing -> feature/very-l…e-for-testing
# Shared by the starship prompt and the Claude Code statusline.
max=${1:-32}
dir=${2:-.}
b=$(git -C "$dir" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null ||
	git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null) || exit 1
if [ "${#b}" -gt "$max" ]; then
	tail=$(((max - 1) / 2))
	head=$((max - 1 - tail))
	b="${b:0:head}…${b: -tail}"
fi
printf '%s' "$b"
