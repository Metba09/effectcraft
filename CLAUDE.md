@AGENTS.md


## Chat session (isolated sandbox: offline, 1 core, ~4 GB RAM)

For an agent session in a sandbox without general network access. Everything below is a plain
script or `make` target, so it works the same from a shell, an agent or CI; nothing depends on
Claude Code. This repository has no `.claude/` hooks or slash commands. The rules in `AGENTS.md`
still apply, including "report only what ran".

**Install (once per session, idempotent, no prompts, no network)** from the offline bundle
(toolchain, vendored crates, ALSA `.deb` files, repository snapshot):

```sh
bash <bundle>/bootstrap.sh          # empty sandbox: unpack the repo, then run setup
make setup                          # repo already present; BUNDLE=<dir> if not auto-detected
```

The bundle is found in `$EFFECTCRAFT_BUNDLE_DIR`, `./.sandbox-bundle`, or
`/mnt/user-data/uploads[/effectcraft-bundle]`. Rust, `cargo`, `clippy` and `rustfmt` land in
`~/.effectcraft-sandbox`; build output goes there too, not into the checkout. Plain `cargo`
needs `. scripts/sandbox/env.sh` first (the `make` targets and scripts do it themselves).

**Test and check (run `make verify` by hand before concluding)**

```sh
make verify                        # fmt check + layers/assets gates + cargo check (core crates)
make verify VERIFY_ARGS="--with-lint --with-test"
make check|lint|test               # SCOPE=core (default) or SCOPE=full
make test TEST_ARGS="-p effectcraft-keyframe"    # one crate
make fmt                           # apply rustfmt
```

`core` is every workspace crate except `effectcraft` (desktop app), `effectcraft-web`,
`effectcraft-ui-egui` and `effectcraft-cli`. `full` adds them and is hours of CPU on one core.
A tool call lasts about five minutes: set `EC_TIMEOUT=270` and re-run on exit code 124 (Cargo
keeps what it compiled), or run `bash scripts/sandbox/bg.sh start NAME <cmd>` and poll with
`bg.sh status` / `bg.sh tail NAME`. `cargo-nextest` is not bundled; `cargo test` is used instead.

**Not usable in the sandbox**
- Docker, a GPU (wgpu has no adapter: never set `EFFECTCRAFT_REQUIRE_GPU`), a display, audio output.
- The desktop app window (`cargo run -p effectcraft`) and its update checks (`craft-update`).
- `cargo xtask wasm|web` (no wasm32 target, no trunk), `cargo xtask aep-corpus` and the shared
  corpora in `storytold/photocraft-corpus` (network), `cargo xtask ci` as a whole (it runs the
  wasm job); use `make verify` for the offline subset.
- Models and fixtures behind `EFFECTCRAFT_SAM2_DIR`, `EFFECTCRAFT_MOBILESAM`,
  `EFFECTCRAFT_FACE_LANDMARKER`, `EFFECTCRAFT_AEP_FIXTURES`: leave them unset, those tests skip.
  `.env.example` lists every optional variable; none is required.
- Any secret. None is needed offline; never write one into a file or a log.

**Where to read on demand:** `docs/architecture.md` (layers), `docs/testing.md` (oracles),
`docs/agents.md` and `docs/mcp.md` (driving the app), `docs/gaps.md`. `.mcp.sandbox.json` starts
the headless MCP server through `scripts/sandbox/run-cli.sh` (it builds the CLI first; long on 1 core).

**Rebuilding the bundle** (online, once, by a maintainer or a runner): `make bundle OUT=dir`
(`scripts/sandbox/build-bundle.sh`). It vendors `Cargo.lock` as is, replaces Windows-only crates
by empty stubs, adds stubs for `[patch]` entries that `Cargo.lock` does not use, packs the
toolchain, and writes `SHA256SUMS`. Rebuild it whenever `Cargo.lock` or `rust-version` changes.
