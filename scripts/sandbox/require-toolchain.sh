#!/usr/bin/env bash
# Sourced by the other scripts: load the offline env and fail early with an actionable message.
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
if ! command -v cargo >/dev/null 2>&1 || [ ! -f "$CARGO_HOME/config.toml" ]; then
  echo "error: offline toolchain not installed. Run:  make setup" >&2
  echo "       (needs the sandbox bundle; see the 'Chat session' section of CLAUDE.md)" >&2
  exit 3
fi
cd "$EFFECTCRAFT_ROOT" || exit 3

# ec_run CMD...: run with an optional wall-clock cap (EC_TIMEOUT seconds). Exit code 124 means
# "not finished, run again": Cargo keeps everything it already compiled, so a re-run resumes.
ec_run() {
  if [ -n "${EC_TIMEOUT:-}" ]; then timeout --foreground "$EC_TIMEOUT" "$@"; else "$@"; fi
}
