#!/usr/bin/env bash
# Format (default) or verify (--check) the whole workspace with rustfmt.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/require-toolchain.sh"
if [ "${1:-}" = "--check" ]; then cargo fmt --all -- --check; else cargo fmt --all; fi
