#!/usr/bin/env bash
# cargo test, offline (cargo-nextest is not bundled).   test.sh [core|full] [-- extra test args]
#   test.sh core                      all core crates
#   test.sh -p effectcraft-keyframe   one crate (any cargo selection flags work too)
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/require-toolchain.sh"; . "$(dirname "${BASH_SOURCE[0]}")/packages.sh"
case "${1:-core}" in
  core|full) scope="$1"; shift || true; sel="$(ec_select "$scope")" ;;
  *) sel="" ;;   # caller passed explicit cargo flags such as -p <crate>
esac
# shellcheck disable=SC2086
ec_run cargo test $sel --offline --locked "$@"
