#!/usr/bin/env python3
"""Lint systemd unit files via systemd-analyze verify.

Skips:
- Jinja2 templates (.j2 extension or {{ }} markers)
- Drop-in overrides (.conf) — not standalone units
- "not executable" / "No such file" errors (binaries may not be installed)
"""

import glob
import os
import re
import subprocess
import sys

UNITS_DIR = os.path.join("states", "units")

# Errors that are expected on dev/CI machines where binaries aren't installed
_NOISE = re.compile(
    r"is not executable: No such file|"
    r"No such file or directory|"
    r"ananicy-cpp\.service"
)

# Jinja2 template marker
_JINJA = re.compile(r"\{\{|\{%")


def find_units():
    """Find verifiable unit files (.service, .timer)."""
    units = []
    for pattern in ("**/*.service", "**/*.timer"):
        for path in sorted(glob.glob(os.path.join(UNITS_DIR, pattern), recursive=True)):
            if path.endswith(".j2"):
                continue
            # Check for inline Jinja2 templating (e.g. ollama.service)
            try:
                with open(path, encoding="utf-8") as f:
                    content = f.read()
            except (OSError, UnicodeDecodeError):
                continue
            if _JINJA.search(content):
                continue
            units.append(path)
    return units


def verify_unit(path):
    """Run systemd-analyze verify, return real errors (filtered)."""
    result = subprocess.run(
        ["systemd-analyze", "verify", path],
        capture_output=True,
        text=True,
    )
    lines = []
    for line in (result.stderr + result.stdout).splitlines():
        if not line.strip():
            continue
        if _NOISE.search(line):
            continue
        lines.append(line)
    return lines


def main():
    units = find_units()
    if not units:
        print("No verifiable unit files found")
        return

    errors = 0
    for path in units:
        issues = verify_unit(path)
        if issues:
            errors += 1
            print(f"\033[31m{path}:\033[0m")
            for line in issues:
                print(f"  {line}")

    skipped_j2 = len(glob.glob(os.path.join(UNITS_DIR, "**/*.j2"), recursive=True))
    skipped_conf = len(glob.glob(os.path.join(UNITS_DIR, "**/*.conf"), recursive=True))
    # Count inline-jinja skips
    all_svc_timer = set(
        glob.glob(os.path.join(UNITS_DIR, "**/*.service"), recursive=True)
        + glob.glob(os.path.join(UNITS_DIR, "**/*.timer"), recursive=True)
    )
    skipped_inline = len(all_svc_timer) - len(units) - skipped_j2

    print(
        f"Systemd units: {len(units)} verified, "
        f"{errors} with errors"
        f" (skipped: {skipped_j2} .j2, {skipped_conf} .conf"
        f"{f', {skipped_inline} inline-jinja' if skipped_inline > 0 else ''})"
    )
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
