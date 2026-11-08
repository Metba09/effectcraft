#!/usr/bin/env python3
"""Shrink a `cargo vendor` directory for Linux-only offline use.

Crates that can never compile on Linux (Windows import libraries, winapi) are replaced by an
empty stub that keeps Cargo.toml, so Cargo can still resolve Cargo.lock offline. Patches that are
declared in [patch] but unused (absent from Cargo.lock) get a minimal stub too.
Usage: prune_vendor.py VENDOR_DIR [patch-stub-name ...]
"""
import json, os, re, shutil, sys

WINDOWS = re.compile(r"^(windows($|[-_])|winapi-(i686|x86_64)-pc-windows-gnu$)")


def stub_windows(vendor: str) -> tuple[int, int]:
    saved = count = 0
    for name in sorted(os.listdir(vendor)):
        if not WINDOWS.match(name):
            continue
        path = os.path.join(vendor, name)
        meta = json.load(open(os.path.join(path, ".cargo-checksum.json")))
        saved += sum(os.path.getsize(os.path.join(r, f)) for r, _, fs in os.walk(path) for f in fs)
        for entry in os.listdir(path):
            if entry in ("Cargo.toml", ".cargo-checksum.json"):
                continue
            target = os.path.join(path, entry)
            shutil.rmtree(target) if os.path.isdir(target) else os.remove(target)
        os.makedirs(os.path.join(path, "src"), exist_ok=True)
        with open(os.path.join(path, "src", "lib.rs"), "w") as fh:
            fh.write("//! Stub: Windows-only crate, never compiled on Linux (sandbox bundle).\n#![no_std]\n")
        json.dump({"files": {}, "package": meta.get("package")}, open(os.path.join(path, ".cargo-checksum.json"), "w"))
        count += 1
    return count, saved


def stub_unused_patches(vendor: str, names: list[str], version: str = "0.37.0") -> None:
    for name in names:
        path = os.path.join(vendor, name)
        shutil.rmtree(path, ignore_errors=True)
        os.makedirs(os.path.join(path, "src"))
        with open(os.path.join(path, "Cargo.toml"), "w") as fh:
            fh.write(f'[package]\nname = "{name}"\nversion = "{version}"\nedition = "2024"\n'
                     'description = "Sandbox bundle stub: declared in [patch] but never resolved (absent from Cargo.lock)."\n'
                     'license = "MIT OR Apache-2.0"\n')
        with open(os.path.join(path, "src", "lib.rs"), "w") as fh:
            fh.write("//! stub (unused patch)\n")
        with open(os.path.join(path, ".cargo-checksum.json"), "w") as fh:
            fh.write('{"files":{},"package":null}')


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    n, saved = stub_windows(sys.argv[1])
    stub_unused_patches(sys.argv[1], sys.argv[2:])
    print(f"stubbed {n} Windows crates ({saved // 2**20} MiB), {len(sys.argv) - 2} unused patch stubs")
