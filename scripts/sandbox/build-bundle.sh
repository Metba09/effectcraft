#!/usr/bin/env bash
# ONLINE step, run once by a maintainer (or a CI runner) to produce the offline bundle.
#   bash scripts/sandbox/build-bundle.sh OUT_DIR
# Env: SKIP_EXISTING=1  keep an already packed toolchain.tar.xz / vendor.tar.xz (re-pack only the repo)
#      TOOLCHAIN_SRC  Rust prefix to pack (default: the active rustc's prefix)
#      DEB_DIR        directory with libasound2t64_*.deb and libasound2-dev_*.deb (optional)
#      SPLIT_MB       split archives into parts of this size (default 0 = no split)
# Output: toolchain.tar.xz, vendor.tar.xz, repo.tar.xz, *.deb, bootstrap.sh, MANIFEST.txt, SHA256SUMS
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
out="${1:?usage: build-bundle.sh OUT_DIR}"; mkdir -p "$out"; out="$(cd "$out" && pwd)"
split_mb="${SPLIT_MB:-0}"
cd "$root"
command -v cargo >/dev/null || { echo "error: no cargo in PATH (need a toolchain to vendor)" >&2; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

echo "[bundle] vendoring crates (needs crates.io + github.com)..."
env -u CARGO_NET_OFFLINE cargo vendor --locked "$tmp/vendor" > "$tmp/vendor-config.toml"
# Template the absolute vendor path so setup.sh can relocate it.
sed "s#directory = \".*\"#directory = \"@VENDOR_DIR@\"#" "$tmp/vendor-config.toml" > "$tmp/cargo-config.toml.in"
# Patches declared in Cargo.toml but unused (not in Cargo.lock) are not vendored; Cargo still wants them.
stubs=()
for name in $(sed -n '/^\[patch\./,/^\[/p' Cargo.toml | grep -oE '^[A-Za-z0-9_-]+ *=' | tr -d ' ='); do
  [ -d "$tmp/vendor/$name" ] || stubs+=("$name")
done
python3 "$here/prune_vendor.py" "$tmp/vendor" "${stubs[@]}"
cp "$here/prune_vendor.py" "$tmp/prune_vendor.py"

if [ "${SKIP_EXISTING:-0}" = 1 ] && [ -s "$out/vendor.tar.xz" ]; then echo "[bundle] keeping existing vendor.tar.xz"; else
  echo "[bundle] packing vendor ($(du -sh "$tmp/vendor" | cut -f1))..."
  tar -C "$tmp" -cf - vendor cargo-config.toml.in | xz -T0 -6 > "$out/vendor.tar.xz"
fi

src="${TOOLCHAIN_SRC:-$(dirname "$(dirname "$(command -v rustc)")")}"
if [ "${SKIP_EXISTING:-0}" = 1 ] && [ -s "$out/toolchain.tar.xz" ]; then echo "[bundle] keeping existing toolchain.tar.xz"; else
echo "[bundle] packing toolchain from $src..."
tar -C "$src" --exclude='./conda-meta' --exclude='./share/doc' --exclude='./share/man' --exclude='./bin/rust-gdb*' \
    --exclude='./bin/rust-lldb' --exclude='./lib/rustlib/*/analysis' -cf - . | xz -T0 -6 > "$out/toolchain.tar.xz"
fi

echo "[bundle] packing repository snapshot (git archive HEAD + local changes)..."
git add -N scripts Makefile .env.example CLAUDE.md .mcp.sandbox.json 2>/dev/null || true
git ls-files -z --cached --others --exclude-standard | tar --null -T - -cf - | xz -T0 -6 > "$out/repo.tar.xz"

[ -n "${DEB_DIR:-}" ] && cp "$DEB_DIR"/libasound2*.deb "$out"/ 2>/dev/null || true
cp "$here/bootstrap.sh" "$out/bootstrap.sh"

if [ "$split_mb" -gt 0 ]; then
  for f in toolchain.tar.xz vendor.tar.xz repo.tar.xz; do
    [ "$(stat -c%s "$out/$f")" -gt $((split_mb * 1048576)) ] || continue
    split -b "${split_mb}m" -d -a 2 "$out/$f" "$out/$f.part-" && rm "$out/$f"
  done
fi

{
  echo "effectcraft sandbox bundle"
  echo "commit:      $(git rev-parse HEAD)"
  echo "rust:        $("$src/bin/rustc" --version)"
  echo "cargo:       $("$src/bin/cargo" --version)"
  echo "lockfile:    $(sha256sum Cargo.lock | cut -d' ' -f1)"
  echo "vendored:    $(ls "$tmp/vendor" | wc -l) crate directories"
  echo "stubbed:     Windows-only crates + unused patches (${stubs[*]:-none})"
  echo "built:       $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$out/MANIFEST.txt"
( cd "$out" && rm -f SHA256SUMS && sha256sum $(ls | grep -v '^SHA256SUMS$') > SHA256SUMS )
echo "[bundle] done: $out"; du -sh "$out"/* | sed 's/^/  /'
