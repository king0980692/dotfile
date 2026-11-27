#!/bin/bash
# 精確比對工具名稱與 registry backend spec，不以 basename 猜測身分。
mise_matching_installed() {
  local tool=$1 registry_file=${MISE_FZF_STATE:+$MISE_FZF_STATE/registry}
  local installed_file=${MISE_FZF_STATE:+$MISE_FZF_STATE/installed}
  local registry installed
  if [[ -n $registry_file && -r $registry_file ]]; then
    registry=$(<"$registry_file")
  else
    registry=$(mise registry 2>/dev/null)
  fi
  if [[ -n $installed_file && -r $installed_file ]]; then
    installed=$(<"$installed_file")
  else
    installed=$(COLUMNS=1000 mise ls --installed 2>/dev/null)
  fi
  # registry 以檔案傳入: macOS 的 BSD awk 不接受 -v 值含換行
  awk -v tool="$tool" '
    BEGIN { allowed[tool] = 1 }
    FILENAME == ARGV[1] {
      if (tool !~ /^[a-z]+:/ && $1 == tool)
        for (j = 2; j <= NF; j++) allowed[$j] = 1
      next
    }
    $1 in allowed { print }
  ' <(printf '%s\n' "$registry") <(printf '%s\n' "$installed")
}
