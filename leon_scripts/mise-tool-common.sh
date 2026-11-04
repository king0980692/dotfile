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
  awk -v tool="$tool" -v registry="$registry" '
    BEGIN {
      allowed[tool] = 1
      if (tool !~ /^[a-z]+:/) {
        n = split(registry, lines, "\n")
        for (i = 1; i <= n; i++) {
          count = split(lines[i], fields, " ")
          if (fields[1] == tool)
            for (j = 2; j <= count; j++) allowed[fields[j]] = 1
        }
      }
    }
    $1 in allowed { print }
  ' <<< "$installed"
}
