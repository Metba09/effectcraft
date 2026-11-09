#!/usr/bin/env bash
# Idempotent, non-interactive, offline installer for the sandbox bundle.
#   make setup            (or)   bash scripts/sandbox/setup.sh [BUNDLE_DIR]
# Re-running is safe: every step is skipped when its stamp matches the bundle checksum.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/env.sh"

say() { printf '[setup] %s\n' "$*"; }
die() { printf '[setup] error: %s\n' "$*" >&2; exit 1; }

# 1. Locate the bundle (first match wins).
bundle="${1:-${EFFECTCRAFT_BUNDLE_DIR:-}}"
if [ -z "$bundle" ]; then
  for c in "$EFFECTCRAFT_ROOT/.sandbox-bundle" /mnt/user-data/uploads/effectcraft-bundle \
           /mnt/user-data/uploads "$EFFECTCRAFT_ROOT/../effectcraft-bundle" "$HOME/effectcraft-bundle"; do
    if [ -f "$c/SHA256SUMS" ]; then bundle="$c"; break; fi
  done
fi
[ -n "$bundle" ] && [ -f "$bundle/SHA256SUMS" ] || die "bundle not found. Pass its directory or set EFFECTCRAFT_BUNDLE_DIR."
say "bundle: $bundle"

# 2. Reassemble split parts (name.part-aa, name.part-ab, ...) into $stage; checksums cover the parts.
home="$EFFECTCRAFT_SANDBOX_HOME"; stage="$home/stage"; mkdir -p "$home" "$stage"
( cd "$bundle" && sha256sum --quiet -c SHA256SUMS ) || die "checksum mismatch: the bundle is corrupt or incomplete."
sum="$(sha256sum "$bundle/SHA256SUMS" | cut -d' ' -f1)"
join_parts() { # $1 = base name, prints path of the joined archive
  local base="$1" out="$stage/$1"
  if [ -f "$bundle/$base" ]; then echo "$bundle/$base"; return; fi
  if [ ! -f "$out" ] || [ ! -f "$out.ok-$sum" ]; then
    cat "$bundle/$base".part-* > "$out" || die "missing parts for $base"
    : > "$out.ok-$sum"
  fi
  echo "$out"
}

# 3. Toolchain (rustc, cargo, clippy, rustfmt, std) into $home/toolchain.
if [ "$(cat "$home/.toolchain-stamp" 2>/dev/null)" != "$sum" ] || [ ! -x "$home/toolchain/bin/cargo" ]; then
  say "installing Rust toolchain..."
  tc="$(join_parts toolchain.tar.xz)"
  rm -rf "$home/toolchain"; mkdir -p "$home/toolchain"
  tar -xJf "$tc" -C "$home/toolchain"
  echo "$sum" > "$home/.toolchain-stamp"
else say "toolchain up to date"; fi

# 4. Vendored crates + source-replacement config into $home/vendor and $CARGO_HOME.
if [ "$(cat "$home/.vendor-stamp" 2>/dev/null)" != "$sum" ] || [ ! -f "$CARGO_HOME/config.toml" ]; then
  say "unpacking vendored crates..."
  vd="$(join_parts vendor.tar.xz)"
  rm -rf "$home/vendor" "$home/cargo-config.toml.in"; mkdir -p "$CARGO_HOME"
  tar -xJf "$vd" -C "$home"
  [ -f "$home/cargo-config.toml.in" ] || die "vendor archive lacks cargo-config.toml.in"
  sed "s#@VENDOR_DIR@#$home/vendor#g" "$home/cargo-config.toml.in" > "$CARGO_HOME/config.toml"
  cat >> "$CARGO_HOME/config.toml" <<CFG

[net]
offline = true

# Sandbox-only: unoptimised third-party crates compile far faster and use less disk on 1 core.
# The repository's own profile (opt-level 2 for dependencies) is unchanged for everyone else.
[profile.dev.package."*"]
opt-level = 0

[profile.dev]
debug = false
CFG
  echo "$sum" > "$home/.vendor-stamp"
else say "vendored crates up to date"; fi

# 5. Native libraries the workspace links against (ALSA headers for cpal), from bundled .deb files.
#    First choice: dpkg -i (root). Fallback: unpack into $home/alsa, picked up by env.sh.
if ! pkg-config --exists alsa 2>/dev/null && ls "$bundle"/libasound2*.deb >/dev/null 2>&1; then
  say "installing ALSA development files from the bundle..."
  if ! PATH="$PATH:/usr/sbin:/sbin" dpkg -i "$bundle"/libasound2t64_*.deb "$bundle"/libasound2-dev_*.deb >"$home/dpkg.log" 2>&1; then
    say "dpkg unavailable here: unpacking ALSA into $home/alsa instead"
    mkdir -p "$home/alsa"
    for d in "$bundle"/libasound2t64_*.deb "$bundle"/libasound2-dev_*.deb; do dpkg -x "$d" "$home/alsa"; done
  fi
fi

# 6. Prove the install: resolve the whole workspace offline against Cargo.lock.
. "$here/require-toolchain.sh"
say "verifying offline resolution..."
cargo metadata --offline --locked --format-version 1 >/dev/null 2>"$home/metadata.err" \
  || { cat "$home/metadata.err" >&2; die "cargo metadata failed offline"; }
say "ok: $(rustc --version), $(cargo --version | cut -d' ' -f1-2)"
say "next: make check | make test | make verify"
