#!/usr/bin/env bash
# install-goto.sh — the "minimal" tier: herdr-goto and its alt+s binding only.
#
# For machines whose ~/.config is not managed by these dotfiles (e.g. a node
# you only reach through `herdr --machine`). Needs curl, tar and a sha256 tool;
# no mise, no Rust, no clone. Safe to re-run: it upgrades the binary and leaves
# an existing alt+s binding alone.
#
#   curl -fsSL https://raw.githubusercontent.com/king0980692/dotfile/main/herdr/scripts/install-goto.sh | bash
#   … | bash -s -- v0.1.0        # a specific release instead of the latest
#
# BIN_DIR (default ~/.local/bin) and HERDR_CONFIG (default
# ${XDG_CONFIG_HOME:-~/.config}/herdr/config.toml) can be overridden.

set -euo pipefail
repo=king0980692/herdr-goto
bin_dir=${BIN_DIR:-$HOME/.local/bin}
config=${HERDR_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}
say() { printf '\033[1;34m[goto]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[goto]\033[0m %s\n' "$*" >&2; exit 1; }

case "$(uname -s)-$(uname -m)" in
	Linux-x86_64) triple=x86_64-unknown-linux-musl ;;
	Linux-aarch64 | Linux-arm64) triple=aarch64-unknown-linux-musl ;;
	Darwin-x86_64) triple=x86_64-apple-darwin ;;
	Darwin-arm64) triple=aarch64-apple-darwin ;;
	*) die "no release build for $(uname -s) $(uname -m)" ;;
esac

tag=${1:-}
if [ -z "$tag" ]; then
	auth=()
	token=${GITHUB_TOKEN:-${MISE_GITHUB_TOKEN:-}}
	[ -n "$token" ] && auth=(-H "Authorization: Bearer $token")
	tag=$(curl -fsSL ${auth[@]+"${auth[@]}"} "https://api.github.com/repos/$repo/releases/latest" |
		sed -n 's/^ *"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)
	[ -n "$tag" ] || die "could not find the latest release of $repo"
fi

marker="$bin_dir/.herdr-goto-version"
old=$(cat "$marker" 2>/dev/null || echo none)
if [ "$old" = "$tag" ] && [ -x "$bin_dir/herdr-goto" ]; then
	say "herdr-goto $tag already installed in $bin_dir"
else
	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' EXIT
	asset="herdr-goto-$tag-$triple.tar.gz"
	base="https://github.com/$repo/releases/download/$tag"
	curl -fsSL -o "$tmp/$asset" "$base/$asset" || die "download failed: $base/$asset"
	curl -fsSL -o "$tmp/SHA256SUMS" "$base/SHA256SUMS" || die "download failed: $base/SHA256SUMS"
	want=$(grep " $asset\$" "$tmp/SHA256SUMS" | cut -d' ' -f1)
	if command -v sha256sum >/dev/null 2>&1; then
		got=$(sha256sum "$tmp/$asset" | cut -d' ' -f1)
	else
		got=$(shasum -a 256 "$tmp/$asset" | cut -d' ' -f1)
	fi
	[ -n "$want" ] && [ "$want" = "$got" ] || die "checksum mismatch for $asset"
	tar -xzf "$tmp/$asset" -C "$tmp"
	mkdir -p "$bin_dir"
	install -m 755 "$tmp/herdr-goto" "$bin_dir/herdr-goto"
	printf '%s\n' "$tag" >"$marker"
	say "herdr-goto $old → $tag ($triple) in $bin_dir"
fi

# alt+s binding. Keybinding commands run on the machine whose server the TUI is
# showing, so this machine needs its own copy of the binding.
mkdir -p "$(dirname "$config")"
touch "$config"
if grep -q '"alt+s"' "$config"; then
	say "alt+s already bound in $config (left unchanged)"
	exit 0
fi
cp -p "$config" "$config.bak.$(date +%Y%m%d-%H%M%S)"
# free alt+s from herdr's built-in navigator; `goto` must sit inside [keys]
if ! grep -q '^goto *=' "$config"; then
	if grep -q '^\[keys\]' "$config"; then
		tmpc=$(mktemp)
		awk '{ print } /^\[keys\][[:space:]]*$/ && !done { print "goto = \"\""; done = 1 }' "$config" >"$tmpc"
		cat "$tmpc" >"$config"
		rm -f "$tmpc"
	else
		printf '\n[keys]\ngoto = ""\n' >>"$config"
	fi
fi
cat >>"$config" <<EOF

[[keys.command]]
key = "alt+s"
type = "popup"
description = "Go to"
command = "$bin_dir/herdr-goto"
width = "80%"
height = "80%"
EOF
say "bound alt+s in $config (restart herdr or reload its config)"
