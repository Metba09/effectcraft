#!/usr/bin/env bash
# The project's own offline-capable gates from `cargo xtask`: crate layering and asset attribution.
# (xtask `wasm`, `web`, `aep-corpus`, `pdf-deps` and the ALSA probe in `ci` need extra targets or the network.)
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/require-toolchain.sh"
ec_run cargo xtask layers
ec_run cargo xtask assets
