#!/usr/bin/env bash
# Package selection shared by check/test/lint.
#   core : every workspace crate that builds without egui/winit/wgpu windows or audio output
#          (layers L0-L4 plus the headless pieces). This is what fits a 1-core, 4 GB sandbox.
#   full : the whole default workspace, desktop app and CLI included (hours on 1 core).
EC_EXCLUDE_CORE=(effectcraft effectcraft-web effectcraft-ui-egui effectcraft-cli)
ec_select() { # prints cargo selection flags for $1 = core|full
  case "${1:-core}" in
    full) echo "--workspace" ;;
    core) printf -- '--workspace'; for p in "${EC_EXCLUDE_CORE[@]}"; do printf -- ' --exclude %s' "$p"; done; echo ;;
    *) echo "error: unknown scope '$1' (core|full)" >&2; return 2 ;;
  esac
}
