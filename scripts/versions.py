#!/usr/bin/env python3
"""Query and update states/data/versions.yaml."""

import argparse
import json
import re
import sys
from pathlib import Path

import yaml

VERSION_FILE = Path("states/data/versions.yaml")


def load_versions() -> dict:
    if not VERSION_FILE.is_file():
        raise SystemExit(f"Version file not found: {VERSION_FILE}")
    data = yaml.safe_load(VERSION_FILE.read_text())
    return data or {}


def list_versions(versions: dict, keys=None) -> dict:
    if not keys:
        return versions
    return {k: versions[k] for k in keys if k in versions}


def write_versions(updates: dict) -> None:
    text = VERSION_FILE.read_text()
    for key, value in updates.items():
        pattern = re.compile(rf"^({re.escape(key)}:\s*)" + r'"[^"]*"(.*)$', re.MULTILINE)
        replacement = rf'\1"{value}"\2'
        if pattern.search(text):
            text = pattern.sub(replacement, text, count=1)
        else:
            if not text.endswith("\n"):
                text += "\n"
            text += f'{key}: "{value}"\n'
    VERSION_FILE.write_text(text)


def cmd_list(args):
    versions = load_versions()
    if args.filter:
        versions = {k: v for k, v in versions.items() if args.filter in k}
    if args.json:
        json.dump(versions, fp=sys.stdout, indent=2)
        sys.stdout.write("\n")
        return
    for key in sorted(versions):
        print(f"{key}: {versions[key]}")


def cmd_get(args):
    versions = load_versions()
    missing = [k for k in args.keys if k not in versions]
    if missing:
        raise SystemExit(f"Unknown key(s): {', '.join(missing)}")
    data = {k: versions[k] for k in args.keys}
    if args.json:
        json.dump(data, fp=sys.stdout, indent=2)
        sys.stdout.write("\n")
    else:
        for key in args.keys:
            print(f"{key}: {versions[key]}")


def cmd_set(args):
    updates = {}
    for pair in args.pairs:
        if "=" not in pair:
            raise SystemExit(f"Invalid pair '{pair}', expected key=value")
        key, value = pair.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not key or not value:
            raise SystemExit(f"Invalid pair '{pair}', empty key/value")
        updates[key] = value
    write_versions(updates)
    for key, value in updates.items():
        print(f"Set {key} = {value}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Manage states/data/versions.yaml")
    parser.set_defaults(func=cmd_list)
    parser.add_argument("--json", action="store_true", help="Output JSON for list command")
    parser.add_argument(
        "--filter", metavar="SUBSTR", help="Filter list output to keys containing substring"
    )

    subparsers = parser.add_subparsers(dest="command")

    get_parser = subparsers.add_parser("get", help="Get specific key(s)")
    get_parser.add_argument("keys", nargs="+", help="Keys to fetch")
    get_parser.add_argument("--json", action="store_true", help="Output JSON")
    get_parser.set_defaults(func=cmd_get)

    set_parser = subparsers.add_parser("set", help="Set key=value pairs")
    set_parser.add_argument("pairs", nargs="+", help="Assignments like key=value")
    set_parser.set_defaults(func=cmd_set)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
