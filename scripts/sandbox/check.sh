#!/usr/bin/env bash
# cargo check, offline. Scope: core (default, fits the sandbox) or full.   EC_TIMEOUT=270 for resumable runs.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/require-toolchain.sh"; . "$(dirname "${BASH_SOURCE[0]}")/packages.sh"
# shellcheck disable=SC2046
ec_run cargo check $(ec_select "${1:-core}") --all-targets --offline --locked
