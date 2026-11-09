# effectcraft offline sandbox bundle (orphan branch)

No source history here: this branch only carries the offline bundle built by
`scripts/sandbox/build-bundle.sh` (see `bundle/MANIFEST.txt` for the commit it was built from).

Use in an isolated sandbox with no network:

    git clone --depth 1 --branch <this-branch> <fork-url> effectcraft-bundle-src
    bash effectcraft-bundle-src/bundle/bootstrap.sh      # unpacks the repo, installs toolchain + vendored crates

`bootstrap.sh` verifies `SHA256SUMS` first. Large archives are split into parts of at most 45 MB.
