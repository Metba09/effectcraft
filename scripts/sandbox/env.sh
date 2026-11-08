#!/usr/bin/env bash
# Source me:  . scripts/sandbox/env.sh
# Offline Rust environment for an isolated chat sandbox. Idempotent, prints nothing,
# changes nothing outside this shell. `make setup` must have run once per session.

_ec_here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export EFFECTCRAFT_ROOT="${EFFECTCRAFT_ROOT:-$(cd "$_ec_here/../.." && pwd)}"
export EFFECTCRAFT_SANDBOX_HOME="${EFFECTCRAFT_SANDBOX_HOME:-$HOME/.effectcraft-sandbox}"

export PATH="$EFFECTCRAFT_SANDBOX_HOME/toolchain/bin:$PATH"
# A private CARGO_HOME holds the source-replacement config (vendored crates) and nothing else:
# no registry cache, no network credentials.
export CARGO_HOME="$EFFECTCRAFT_SANDBOX_HOME/cargohome"
# Build output lives outside the checkout so snapshots of the repo stay small.
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$EFFECTCRAFT_SANDBOX_HOME/target}"
export CARGO_NET_OFFLINE=true
export CARGO_INCREMENTAL=0
export CARGO_TERM_COLOR=never
export RUST_BACKTRACE="${RUST_BACKTRACE:-1}"
# ALSA unpacked by setup.sh when dpkg -i was not possible (cpal links against it).
if [ -d "$EFFECTCRAFT_SANDBOX_HOME/alsa/usr/lib/x86_64-linux-gnu/pkgconfig" ]; then
  export PKG_CONFIG_PATH="$EFFECTCRAFT_SANDBOX_HOME/alsa/usr/lib/x86_64-linux-gnu/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  export PKG_CONFIG_SYSROOT_DIR="$EFFECTCRAFT_SANDBOX_HOME/alsa"
fi
# Features that need models, a GPU or the network are skipped when these stay unset.
export EFFECTCRAFT_OFFLINE=1
unset _ec_here
