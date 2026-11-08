#!/usr/bin/env bash
# Long jobs in the background with a log, so one chat tool call is not the limit.
#   bg.sh start NAME CMD...   |  bg.sh status [NAME]  |  bg.sh tail NAME [LINES]  |  bg.sh stop NAME
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
logs="$EFFECTCRAFT_SANDBOX_HOME/logs"; mkdir -p "$logs"
case "${1:-}" in
  start) name="${2:?name}"; shift 2
         setsid nohup bash -c 'echo $$ > "$0.pid"; "$@"; echo "exit=$?" > "$0.exit"' "$logs/$name" "$@" \
           > "$logs/$name.log" 2>&1 < /dev/null &
         sleep 1; echo "started $name (log: $logs/$name.log)" ;;
  status) for f in ${2:+"$logs/$2.pid"} ${2:-$logs/*.pid}; do
            [ -f "$f" ] || continue; n="$(basename "$f" .pid)"
            if [ -f "$logs/$n.exit" ]; then echo "$n: finished ($(cat "$logs/$n.exit"))"
            elif kill -0 "$(cat "$f")" 2>/dev/null; then echo "$n: running (pid $(cat "$f"))"
            else echo "$n: stopped without exit code"; fi
          done ;;
  tail) tail -n "${3:-30}" "$logs/${2:?name}.log" ;;
  stop) kill "$(cat "$logs/${2:?name}.pid")" 2>/dev/null && echo "stopped $2" || echo "not running" ;;
  *) echo "usage: bg.sh start NAME CMD... | status [NAME] | tail NAME [N] | stop NAME" >&2; exit 2 ;;
esac
