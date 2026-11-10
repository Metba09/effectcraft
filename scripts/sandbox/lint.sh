#!/usr/bin/env bash
# Bundle pointer check, then clippy with -D warnings (as the project's CI does), offline.   Scope: core (default) or full.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/require-toolchain.sh"; . "$(dirname "${BASH_SOURCE[0]}")/packages.sh"
# The bundle pointer must stay in step with Cargo.lock: fail fast, before the long clippy run.
python3 -m json.tool sandbox/BUNDLE.json >/dev/null || { echo "error: sandbox/BUNDLE.json is not valid JSON" >&2; exit 1; }
python3 scripts/sandbox/verify_bundle.py || { echo "error: bundle pointer is stale; see CLAUDE.md, 'Chat session'" >&2; exit 1; }
# shellcheck disable=SC2046
ec_run cargo clippy $(ec_select "${1:-core}") --all-targets --offline --locked -- -D warnings
