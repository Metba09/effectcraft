#!/usr/bin/env bash
# clippy with -D warnings, as the project's CI does, offline.   Scope: core (default) or full.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/require-toolchain.sh"; . "$(dirname "${BASH_SOURCE[0]}")/packages.sh"
# shellcheck disable=SC2046
ec_run cargo clippy $(ec_select "${1:-core}") --all-targets --offline --locked -- -D warnings
