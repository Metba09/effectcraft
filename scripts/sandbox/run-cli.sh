#!/usr/bin/env bash
# Run the headless CLI (builds it first if needed; the first build is long on 1 core).
#   run-cli.sh --help | run-cli.sh mcp --demo | ...
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/require-toolchain.sh"
exec cargo run --quiet --offline --locked -p effectcraft-cli -- "$@"
