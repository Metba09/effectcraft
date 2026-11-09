#!/usr/bin/env bash
# Entry point shipped INSIDE the bundle. From a brand-new sandbox (no repo, no toolchain):
#   bash /path/to/bundle/bootstrap.sh [TARGET_DIR]      # default TARGET_DIR=$HOME/effectcraft
# Unpacks the repository snapshot, then runs its idempotent installer. No network, no prompts.
set -euo pipefail
bundle="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="${1:-$HOME/effectcraft}"
( cd "$bundle" && sha256sum --quiet -c SHA256SUMS ) || { echo "bundle checksum mismatch" >&2; exit 1; }
if [ ! -f "$target/Cargo.toml" ]; then
  mkdir -p "$target"
  if [ -f "$bundle/repo.tar.xz" ]; then tar -xJf "$bundle/repo.tar.xz" -C "$target"
  else cat "$bundle"/repo.tar.xz.part-* | tar -xJ -C "$target"; fi
fi
cd "$target"
# xtask gates and normal review work expect a git checkout: make the snapshot one (local, offline).
if [ ! -d .git ]; then
  git init -q -b main
  git add -A
  git -c user.name=sandbox -c user.email=sandbox@localhost commit -q -m "sandbox snapshot ($(sed -n 's/^commit: *//p' "$bundle/MANIFEST.txt"))"
fi
bash scripts/sandbox/setup.sh "$bundle"
echo "repository ready in $target — try: cd $target && make verify"
