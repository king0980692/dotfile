#!/bin/bash

set -u

for cmd in gum git tmux zoxide; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'Missing dependency: %s\n' "$cmd" >&2
    exit 1
  fi
done

session_exists() {
  tmux has-session -t "$1" 2>/dev/null
}

project_root_for_path() {
  git -C "$1" rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$1"
}

ranked_directory_candidates() {
  declare -A counts=()
  declare -A first_seen=()
  local path root idx=0

  while IFS= read -r path; do
    [ -z "$path" ] && continue
    root=$(project_root_for_path "$path")
    counts["$root"]=$(( ${counts["$root"]:-0} + 1 ))
    if [ -z "${first_seen[$root]:-}" ]; then
      first_seen["$root"]=$idx
      idx=$((idx + 1))
    fi
  done < <(zoxide query -l)

  for root in "${!counts[@]}"; do
    printf '%s\t%s\t%s\n' "${counts[$root]}" "${first_seen[$root]}" "$root"
  done | sort -t $'\t' -k1,1rn -k2,2n | while IFS=$'\t' read -r _ _ root; do
    printf '%s\n' "$root"
  done
}

select_directory() {
  ranked_directory_candidates | gum filter \
    --value "$1" \
    --placeholder "Choose directory..." \
    --header "Select a project directory for the new session" \
    --select-if-one
}

repo_name_from_url() {
  local repo_name
  repo_name=${1%/}
  repo_name=${repo_name##*/}
  repo_name=${repo_name%.git}
  printf '%s\n' "$repo_name"
}

create_session() {
  tmux new-session -d -s "$1" -c "$2" 2>/dev/null && tmux switch-client -t "$1"
}

if [ -n "${1:-}" ]; then
  session_name=$1
else
  session_name=$(gum input --placeholder "Session name..." --char-limit 30 --header "Create tmux session")
fi

if [ -z "$session_name" ]; then
  exit 0
fi

if session_exists "$session_name"; then
  gum style --foreground 196 "Session '$session_name' already exists"
  sleep 1
  exit 1
fi

action=$(gum choose "enter" "clone")
if [ -z "$action" ]; then
  exit 0
fi

if [ "$action" = "enter" ]; then
  target_dir=$(select_directory "$session_name")
  if [ -z "$target_dir" ]; then
    exit 0
  fi

  create_session "$session_name" "$target_dir"
  exit $?
fi

clone_root=$HOME

git_url=""
while :; do
  git_url=$(gum input \
    --value "$git_url" \
    --placeholder "https://github.com/user/repo.git" \
    --header "Clone into $clone_root")

  if [ -z "$git_url" ]; then
    exit 0
  fi

  if git ls-remote "$git_url" >/dev/null 2>&1; then
    break
  fi

  gum style --foreground 196 "Invalid git URL"
  sleep 1
done

repo_name=$(repo_name_from_url "$git_url")
if [ -z "$repo_name" ]; then
  gum style --foreground 196 "Could not derive repository name from URL"
  sleep 1
  exit 1
fi

target_dir="$clone_root/$repo_name"
if [ -e "$target_dir" ]; then
  gum style --foreground 196 "Target already exists: $target_dir"
  sleep 1
  exit 1
fi

if ! gum spin --spinner dot --title "Cloning $git_url" -- git -C "$clone_root" clone "$git_url"; then
  gum style --foreground 196 "Clone failed"
  sleep 1
  exit 1
fi

create_session "$session_name" "$target_dir"
