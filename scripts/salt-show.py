#!/usr/bin/env python3
"""Show which states a Salt SLS would apply, without executing anything.

Usage: salt-show.py <state>           # e.g. group.core, desktop, system_description
       salt-show.py group/core        # slash syntax also works

Outputs a compact list grouped by source .sls file.
"""

import json
import os
import subprocess
import sys
from collections import defaultdict

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
RUNTIME_DIR = os.path.join(PROJECT_DIR, ".salt_runtime")
VENV_PYTHON = os.path.join(PROJECT_DIR, ".venv", "bin", "python3")
SALT_RUNNER = os.path.join(SCRIPT_DIR, "salt-runner.py")


def main():
    if len(sys.argv) < 2:
        print("Usage: salt-show.py <state>", file=sys.stderr)
        sys.exit(1)

    state = sys.argv[1].replace("/", ".")

    # Use salt-runner to call state.show_sls in JSON output
    cmd = [
        "sudo",
        VENV_PYTHON,
        "-u",
        SALT_RUNNER,
        f"--config-dir={RUNTIME_DIR}",
        "--local",
        "--log-level=error",
        "--out=json",
        "state.show_sls",
        state,
    ]

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    if result.returncode != 0:
        # Try to extract useful error from stderr
        err = result.stderr.strip().split("\n")
        for line in err:
            if "Rendering SLS" in line or "not found" in line.lower():
                print(f"Error: {line.strip()}", file=sys.stderr)
                sys.exit(1)
        print(f"salt-call failed (exit {result.returncode})", file=sys.stderr)
        if result.stderr:
            print(result.stderr[:500], file=sys.stderr)
        sys.exit(1)

    # Parse JSON output — salt outputs {"local": {state_id: {...}, ...}}
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        # Output might have non-JSON preamble (deprecation warnings)
        # Try to find the JSON object
        stdout = result.stdout
        start = stdout.find("{")
        if start >= 0:
            try:
                data = json.loads(stdout[start:])
            except json.JSONDecodeError:
                print("Failed to parse salt output", file=sys.stderr)
                sys.exit(1)
        else:
            print("No JSON output from salt", file=sys.stderr)
            sys.exit(1)

    states = data.get("local", data)
    if isinstance(states, list):
        # Error response
        print(f"Error: {states}", file=sys.stderr)
        sys.exit(1)

    # Group state IDs by source .sls file
    by_sls = defaultdict(list)
    for state_id, state_data in states.items():
        if not isinstance(state_data, dict):
            continue
        sls = state_data.get("__sls__", "?")
        # Extract the function (e.g. "pkg.installed", "file.managed")
        funcs = []
        for key, val in state_data.items():
            if key.startswith("__"):
                continue
            if isinstance(val, list):
                for item in val:
                    if isinstance(item, str) and "." not in item:
                        funcs.append(f"{key}.{item}")
                        break
                else:
                    funcs.append(key)
            else:
                funcs.append(key)
        func_str = ", ".join(funcs[:2])
        by_sls[sls].append((state_id, func_str))

    # Print summary
    total = sum(len(v) for v in by_sls.values())
    sls_count = len(by_sls)
    print(f"\n  {state}  →  {total} states from {sls_count} SLS files\n")

    for sls in sorted(by_sls.keys()):
        items = by_sls[sls]
        print(f"  {sls}  ({len(items)} states)")
        for state_id, func in items:
            print(f"    · {state_id}  [{func}]")
        print()


if __name__ == "__main__":
    main()
