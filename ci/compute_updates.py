#!/usr/bin/env python3
"""Compare known versions (old_ver.json) against the latest upstream versions
found by nvchecker (new_ver.json) and print one record per package that needs
a bump.

Output: one line per update, pipe-delimited:

    category|name|old_version|new_version|release_url

Consumed by ci/version-check.sh, which turns each line into a version-bump
merge request.
"""
import json
import sys
import tomllib

OLD_VER = "ci/old_ver.json"
NEW_VER = "ci/new_ver.json"
CONFIG = "ci/nvchecker.toml"


def load_new(path):
    with open(path) as f:
        raw = json.load(f)
    # nvchecker v2 format: {"version": 2, "data": {atom: {"version": "..."}}}
    if "data" in raw:
        return {k: v["version"] for k, v in raw["data"].items()}
    return raw


def main():
    with open(OLD_VER) as f:
        old = json.load(f)
    new = load_new(NEW_VER)
    with open(CONFIG, "rb") as f:
        config = tomllib.load(f)
    config.pop("__config__", None)

    for atom, new_ver in new.items():
        old_ver = old.get(atom, "")
        if old_ver == new_ver:
            continue
        category, name = atom.split("/")
        pkg = config.get(atom, {})
        gh = pkg.get("github", "")
        gl = pkg.get("gitlab", "")
        prefix = pkg.get("prefix", "")
        if gh:
            url = f"https://github.com/{gh}/releases/tag/{prefix}{new_ver}"
        elif gl:
            url = f"https://gitlab.com/{gl}/-/releases/{prefix}{new_ver}"
        else:
            url = ""
        print(f"{category}|{name}|{old_ver}|{new_ver}|{url}")


if __name__ == "__main__":
    sys.exit(main())
