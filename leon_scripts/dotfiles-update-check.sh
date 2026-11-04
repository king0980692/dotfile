#!/usr/bin/env bash
# Check origin/main without fetching or modifying the dotfiles worktree.
# The shell displays the cached result on the next prompt.
set -u

[ "${DOTFILES_UPDATE_CHECK:-1}" != 0 ] || exit 0
repo=${XDG_CONFIG_HOME:-$HOME/.config}
cache=${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-update
interval=${DOTFILES_UPDATE_INTERVAL:-3600}
case "$interval" in ''|*[!0-9]*) interval=3600 ;; esac
interval=$((10#$interval))
[ -d "$repo/.git" ] || exit 0
command -v git >/dev/null 2>&1 || exit 0
mkdir -p "$cache" || exit 0

now=$(date +%s) || exit 0
last=0
[ ! -r "$cache/last-check" ] || IFS= read -r last < "$cache/last-check" || :
case "$last" in ''|*[!0-9]*) last=0 ;; esac
if [ "$now" -ge "$last" ] && [ $((now - last)) -lt "$interval" ]; then
    exit 0
fi
# Throttle failed checks too; several shells can race harmlessly, but they only
# update the cache and never the repository. Use per-process temporary files.
tmp=$(mktemp "$cache/check.XXXXXXXX") || exit 0
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$now" > "$tmp" && mv -f "$tmp" "$cache/last-check"

# Do not prompt for credentials or host confirmation in the background.
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=5}"
if ! remote=$(git -C "$repo" ls-remote --exit-code origin refs/heads/main 2>/dev/null); then
    # A public GitHub repo can still be checked when the SSH agent is absent.
    url=$(git -C "$repo" remote get-url origin 2>/dev/null) || exit 0
    case "$url" in
        git@github.com:*) url="https://github.com/${url#git@github.com:}" ;;
        *) exit 0 ;;
    esac
    remote=$(git -C "$repo" -c credential.helper= ls-remote --exit-code "$url" refs/heads/main 2>/dev/null) || exit 0
fi
remote=${remote%%[[:space:]]*}
case "$remote" in ''|*[!0-9a-fA-F]*) exit 0 ;; esac
[ "${#remote}" -eq 40 ] || [ "${#remote}" -eq 64 ] || exit 0
printf '%s\n' "$remote" > "$tmp" && mv -f "$tmp" "$cache/origin-main"
