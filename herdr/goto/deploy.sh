#!/usr/bin/env bash
# Build herdr-goto for this Mac and cross-compile it for the saved herdr
# machines, then copy the binaries to ~/.local/bin on each of them.
#
# herdr runs keybinding commands on the machine whose server the TUI is
# showing, so M-s on a remote needs the binary (and an alt+s binding in that
# machine's herdr config.toml) over there.
#
#   ./deploy.sh            build + install locally + push to all machines below
#   ./deploy.sh leon       only that machine
#
# Cross builds use cargo-zigbuild (zig comes from mise). One-time setup:
#   cargo install cargo-zigbuild
#   rustup target add x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu
set -euo pipefail
cd "$(dirname "$0")"

# ssh host -> rust target triple
declare -A TARGETS=(
  [leon]=x86_64-unknown-linux-gnu
  [gx10]=aarch64-unknown-linux-gnu
)

hosts=("$@")
[ ${#hosts[@]} -gt 0 ] || hosts=("${!TARGETS[@]}")

echo "== local"
cargo install --path . --root "$HOME/.local" --quiet

for h in "${hosts[@]}"; do
  t="${TARGETS[$h]:-}"
  [ -n "$t" ] || { echo "deploy.sh: unknown host '$h' (add it to TARGETS)" >&2; exit 1; }
  echo "== $h ($t)"
  cargo zigbuild --release --quiet --target "$t"
  ssh -o BatchMode=yes "$h" 'mkdir -p ~/.local/bin'
  scp -q "target/$t/release/herdr-goto" "$h:.local/bin/herdr-goto.new"
  ssh -o BatchMode=yes "$h" 'chmod +x ~/.local/bin/herdr-goto.new && mv -f ~/.local/bin/herdr-goto.new ~/.local/bin/herdr-goto'
done
echo "done"
