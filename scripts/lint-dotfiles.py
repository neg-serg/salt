#!/usr/bin/env python3
"""Lint dotfiles: shebang conventions and XDG path usage."""

import glob
import os
import re
import sys

DOTFILES_BIN = os.path.join("dotfiles", "dot_local", "bin")
DOTFILES_ROOT = "dotfiles"

# Shebangs allowed for non-shell scripts (Python, Nushell, etc.)
_NON_SHELL_SHEBANGS = {"#!/usr/bin/env python3", "#!/usr/bin/env nu"}

# Required shebang for shell scripts
_ZSH_SHEBANG = "#!/usr/bin/env zsh"

# Canonical XDG default paths that should NOT appear in dotfiles.
# Our convention uses short paths: ~/music, ~/pic, ~/vid, ~/doc, ~/dw
_CANONICAL_XDG = [
    "Music",
    "Pictures",
    "Documents",
    "Videos",
    "Downloads",
    "Desktop",
    "Templates",
    "Public",
]

# Patterns matching $HOME/Music, ~/Music, etc.
_XDG_PATTERNS = []
for name in _CANONICAL_XDG:
    _XDG_PATTERNS.append(re.compile(rf'(?:\$HOME|~|/home/\w+)/{name}(?:/|["\'\s\)]|$)'))


def check_shebangs():
    """Shell scripts in dot_local/bin/ must use #!/usr/bin/env zsh."""
    errors = 0
    checked = 0
    pattern = os.path.join(DOTFILES_BIN, "executable_*")
    for path in sorted(glob.glob(pattern)):
        if os.path.isdir(path):
            continue
        checked += 1
        with open(path, encoding="utf-8", errors="replace") as f:
            first_line = f.readline().rstrip("\n")
        if not first_line.startswith("#!"):
            print(f"\033[31mMissing shebang: {path}\033[0m")
            errors += 1
            continue
        if first_line in _NON_SHELL_SHEBANGS:
            continue
        if first_line != _ZSH_SHEBANG:
            print(f"\033[31mBad shebang: {path}: {first_line}\033[0m")
            errors += 1
    return errors, checked


def check_xdg_paths():
    """No canonical XDG defaults (~/Music, ~/Pictures, ...) in dotfiles."""
    errors = 0
    checked = 0
    for path in sorted(glob.glob(os.path.join(DOTFILES_ROOT, "**"), recursive=True)):
        if os.path.isdir(path):
            continue
        # Skip binary files
        try:
            with open(path, encoding="utf-8") as f:
                lines = f.readlines()
        except (UnicodeDecodeError, PermissionError):
            continue
        checked += 1
        for lineno, line in enumerate(lines, 1):
            # Skip comments explaining the convention
            stripped = line.lstrip()
            if stripped.startswith("#") or stripped.startswith("//"):
                continue
            for pat in _XDG_PATTERNS:
                if pat.search(line):
                    print(f"\033[31mCanonical XDG path: {path}:{lineno}: {line.rstrip()}\033[0m")
                    errors += 1
                    break
    return errors, checked


def main():
    total_errors = 0

    shebang_errors, scripts_checked = check_shebangs()
    total_errors += shebang_errors
    print(f"Shebangs: {scripts_checked} scripts, {shebang_errors} violations")

    xdg_errors, files_checked = check_xdg_paths()
    total_errors += xdg_errors
    print(f"XDG paths: {files_checked} files, {xdg_errors} violations")

    sys.exit(1 if total_errors else 0)


if __name__ == "__main__":
    main()
