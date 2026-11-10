#!/usr/bin/env python3
"""Check that sandbox/BUNDLE.json still describes this repository. Standard library only, no network.

  verify_bundle.py                       lockfile hashes + rust-version against BUNDLE.json
  verify_bundle.py --livrable DIR        also the mirrored source tarball in DIR: its SHA-256 first,
                                         opened only afterwards, then the lockfiles it contains
  verify_bundle.py --archives DIR        also the offline archives (toolchain parts, vendor, ...)
                                         listed in BUNDLE.json, hashed from the files in DIR
  verify_bundle.py --pointer FILE        use another pointer file (tests)
  verify_bundle.py --print               print the current lockfile hashes as JSON (to update the pointer)

Exit code 0 = consistent, 1 = at least one "ECART". A damaged tarball never raises a traceback.
After `Cargo.lock` changes the pointer is stale on purpose: update BUNDLE.json and the mirror.
"""
import argparse
import hashlib
import json
import os
import re
import sys
import tarfile
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAX_MEMBER = 256 * 1024 * 1024  # a lockfile is far below this; refuse anything absurd
REQUIRED = ("schema", "upstream_base", "branch", "rust", "vendor", "lockfiles_sha256", "bundle")


def say(text=""):
    sys.stdout.write(text + "\n")


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def rust_version(cargo_toml):
    with open(cargo_toml, encoding="utf-8") as fh:
        m = re.search(r'^rust-version\s*=\s*"([^"]+)"', fh.read(), re.M)
    return m.group(1) if m else None


def load_pointer(path, gaps):
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError) as err:
        gaps.append(f"pointeur illisible ({path}) : {err}")
        return None
    missing = [k for k in REQUIRED if k not in data]
    if missing:
        gaps.append(f"{os.path.basename(path)} : clés manquantes : {', '.join(missing)}")
        return None
    if data["schema"] != 1:
        gaps.append(f"{os.path.basename(path)} : schema {data['schema']!r} inconnu (attendu 1)")
        return None
    return data


def check_lockfiles(data, gaps):
    for name, expected in sorted(data["lockfiles_sha256"].items()):
        path = os.path.join(ROOT, name)
        try:
            actual = sha256_file(path)
        except OSError as err:
            gaps.append(f"lockfile illisible {name} : {err}")
            continue
        if actual != expected:
            gaps.append(f"{name} : sha256 {actual[:16]}… ne correspond plus au pointeur {expected[:16]}…")
    declared = data["rust"].get("min_version")
    actual_rust = rust_version(os.path.join(ROOT, "Cargo.toml"))
    if declared != actual_rust:
        gaps.append(f"rust-version : Cargo.toml dit {actual_rust!r}, le pointeur dit {declared!r}")


def check_livrable(data, directory, gaps):
    bundle = data["bundle"]
    tar_path = os.path.join(directory, bundle["tarball"])
    try:
        actual = sha256_file(tar_path)
    except OSError as err:
        gaps.append(f"tarball illisible ({bundle['tarball']}) : {err}")
        return
    if actual != bundle["tarball_sha256"]:
        gaps.append(f"{bundle['tarball']} : sha256 {actual[:16]}… ≠ pointeur {bundle['tarball_sha256'][:16]}… (non ouvert)")
        return  # never open an archive whose hash is wrong
    try:
        with tarfile.open(tar_path, "r:gz") as tf:
            commit = tf.pax_headers.get("comment")
            if commit and commit != bundle["source_commit"]:
                gaps.append(f"tarball : commit archivé {commit[:12]}… ≠ source_commit {bundle['source_commit'][:12]}…")
            names = {m.name for m in tf.getmembers()}
            prefix = os.path.commonpath([n for n in names if n]) if names else ""
            for name, expected in sorted(data["lockfiles_sha256"].items()):
                member = f"{prefix}/{name}" if prefix else name
                if member not in names:
                    gaps.append(f"tarball : {name} absent")
                    continue
                info = tf.getmember(member)
                if not info.isfile() or info.size > MAX_MEMBER:
                    gaps.append(f"tarball : {name} n'est pas un fichier raisonnable")
                    continue
                h = hashlib.sha256()
                src = tf.extractfile(info)
                for chunk in iter(lambda: src.read(1 << 20), b""):
                    h.update(chunk)
                if h.hexdigest() != expected:
                    gaps.append(f"tarball : {name} sha256 {h.hexdigest()[:16]}… ≠ pointeur {expected[:16]}…")
    except (tarfile.TarError, KeyError, OSError, EOFError, zlib.error) as err:
        gaps.append(f"tarball illisible ({type(err).__name__}) : {err}")


def check_archives(data, directory, gaps):
    archives = data.get("offline_archives", {}).get("files", {})
    if not archives:
        gaps.append("pointeur : aucune archive hors-ligne déclarée")
    for name, expected in sorted(archives.items()):
        try:
            actual = sha256_file(os.path.join(directory, name))
        except OSError as err:
            gaps.append(f"archive illisible {name} : {err}")
            continue
        if actual != expected:
            gaps.append(f"{name} : sha256 {actual[:16]}… ≠ pointeur {expected[:16]}…")


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--livrable", metavar="DIR")
    ap.add_argument("--archives", metavar="DIR")
    ap.add_argument("--pointer", metavar="FILE", default=os.path.join(ROOT, "sandbox", "BUNDLE.json"))
    ap.add_argument("--print", action="store_true", dest="print_hashes")
    args = ap.parse_args(argv)

    if args.print_hashes:
        say(json.dumps({"Cargo.lock": sha256_file(os.path.join(ROOT, "Cargo.lock")),
                        "rust-version": rust_version(os.path.join(ROOT, "Cargo.toml"))}, indent=2))
        return 0

    gaps = []
    data = load_pointer(args.pointer, gaps)
    if data is not None:
        check_lockfiles(data, gaps)
        if args.livrable:
            check_livrable(data, args.livrable, gaps)
        if args.archives:
            check_archives(data, args.archives, gaps)
    if gaps:
        for gap in gaps:
            say(f"ÉCART : {gap}")
        say(f"{len(gaps)} écart(s) : mettre à jour sandbox/BUNDLE.json et le livrable miroir.")
        return 1
    parts = ["lockfiles", "rust-version"] + (["tarball"] if args.livrable else []) + (["archives"] if args.archives else [])
    say("OK : " + ", ".join(parts) + " conformes à " + os.path.relpath(args.pointer, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
