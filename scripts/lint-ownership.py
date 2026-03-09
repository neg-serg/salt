#!/usr/bin/env python3
"""Lint file ownership: detect salt://dotfiles/ refs not covered by .chezmoiignore."""

import glob
import os
import re
import sys

STATES_DIR = "states"
CHEZMOIIGNORE = os.path.join("dotfiles", ".chezmoiignore")

# Matches salt://dotfiles/... URIs in .sls files (inside quotes or bare)
_SALT_DOTFILES_RE = re.compile(r"salt://dotfiles/([\w./_-]+)")

# Prefix map: chezmoi dot_ prefix → actual dot path
_PREFIX_MAP = [
    ("dot_config/", ".config/"),
    ("dot_local/", ".local/"),
]


def convert_to_chezmoi_path(salt_rel: str) -> str:
    """Convert a salt://dotfiles/ relative path to a chezmoi-relative path.

    Example: dot_config/mpd/mpd.conf → .config/mpd/mpd.conf
    """
    for prefix, replacement in _PREFIX_MAP:
        if salt_rel.startswith(prefix):
            return replacement + salt_rel[len(prefix) :]
    return salt_rel


def load_chezmoiignore() -> list[str]:
    """Load .chezmoiignore entries, stripping comments and blank lines."""
    if not os.path.isfile(CHEZMOIIGNORE):
        return []
    entries = []
    with open(CHEZMOIIGNORE) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                entries.append(line)
    return entries


def is_covered(chezmoi_path: str, ignore_entries: list[str]) -> bool:
    """Check if a chezmoi path is covered by any .chezmoiignore entry.

    Supports exact match and parent-directory match (entry ends with /).
    """
    for entry in ignore_entries:
        if chezmoi_path == entry:
            return True
        # Directory entry covers all files underneath
        if entry.endswith("/") and chezmoi_path.startswith(entry):
            return True
    return False


def main() -> int:
    ignore_entries = load_chezmoiignore()
    errors = 0

    for sls_path in sorted(glob.glob(os.path.join(STATES_DIR, "*.sls"))):
        with open(sls_path) as f:
            for lineno, line in enumerate(f, 1):
                for match in _SALT_DOTFILES_RE.finditer(line):
                    salt_rel = match.group(1)
                    chezmoi_path = convert_to_chezmoi_path(salt_rel)
                    if not is_covered(chezmoi_path, ignore_entries):
                        print(
                            f"{sls_path}:{lineno}: salt://dotfiles/{salt_rel} "
                            f"→ {chezmoi_path} not in .chezmoiignore"
                        )
                        errors += 1

    if errors:
        print(f"\n{errors} ownership violation(s) found.")
        print("Add missing paths to dotfiles/.chezmoiignore")
    else:
        print("lint-ownership: all salt://dotfiles/ refs covered by .chezmoiignore")

    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
