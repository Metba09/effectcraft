#!/usr/bin/env bash
# One explicit command to run by hand before concluding a task (replaces any hook):
# format check, layering + asset gates, then cargo check on the core crates.
#   verify.sh [--with-lint] [--with-test]
# Reports every step; exits non-zero if any failed. Exit 124 on a step = timed out, run again.
set -uo pipefail
d="$(dirname "${BASH_SOURCE[0]}")"
steps=("fmt:$d/fmt.sh --check" "gates:$d/gates.sh" "check:$d/check.sh core")
for a in "$@"; do
  case "$a" in
    --with-lint) steps+=("lint:$d/lint.sh core") ;;
    --with-test) steps+=("test:$d/test.sh core") ;;
    *) echo "usage: verify.sh [--with-lint] [--with-test]" >&2; exit 2 ;;
  esac
done
rc=0; summary=()
for s in "${steps[@]}"; do
  name="${s%%:*}"; cmd="${s#*:}"
  echo "=== $name: $cmd"
  # shellcheck disable=SC2086
  if bash $cmd; then summary+=("PASS $name"); else r=$?; summary+=("FAIL $name (exit $r)"); rc=1; fi
done
printf '\n--- verify summary ---\n'; printf '%s\n' "${summary[@]}"; exit $rc
