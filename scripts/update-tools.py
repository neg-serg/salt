#!/usr/bin/env python3
"""Update tools defined in data/installers.yaml.

Usage:
    update-tools.py                  # list all tools with install status
    update-tools.py --check          # check latest GitHub release tags vs pinned
    update-tools.py --check --ci     # same, but markdown output + exit 1 if updates
    update-tools.py --update name..  # update specific tools
    update-tools.py --update --all   # update all tools
"""

import argparse
import json
import os
import subprocess
import sys
import urllib.request

import yaml

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
YAML_PATH = os.path.join(PROJECT_ROOT, "states/data/installers.yaml")
VERSIONS_PATH = os.path.join(PROJECT_ROOT, "states/data/versions.yaml")
SALT_CONFIG = os.path.join(PROJECT_ROOT, ".salt_runtime")
SLS_NAME = "installers"

HOME = os.path.expanduser("~")
BIN = f"{HOME}/.local/bin"
CARGO_BIN = f"{HOME}/.local/share/cargo/bin"
VER_DIR = f"{HOME}/.cache/salt-versions"
SYS_VER_DIR = "/var/cache/salt/versions"

# Mapping from versions.yaml keys to GitHub repos (for --check)
GITHUB_REPOS = {
    "ssh_to_age": "Mic92/ssh-to-age",
    "tdl": "iyear/tdl",
    "xray": "XTLS/Xray-core",
    "loki": "grafana/loki",
    "promtail": "grafana/loki",
    "adguardhome": "AdguardTeam/AdGuardHome",
    "mpv_mpris": "hoyon/mpv-mpris",
    "uosc": "tomasklaen/uosc",
    "nyxt": "atlas-engineer/nyxt",
    "modern_steam": "SleepDaemon/Modern-Steam",
    "fira_code_nerd": "ryanoasis/nerd-fonts",
    "proxypilot": "Finesssee/ProxyPilot",
}

# Mapping from versions.yaml keys to npm package names (for --check)
NPM_PACKAGES = {
    "openclaw": "openclaw",
}

# Custom (non-YAML) tools from installers.sls: name -> (guard_path, sls_name)
CUSTOM_TOOLS = {
    "zi": (f"{HOME}/.config/zi/bin/zi.zsh", "installers"),
    "hyprevents": (f"{BIN}/hyprevents", "installers"),
    "dr14_tmeter": (f"{BIN}/dr14_tmeter", "installers"),
    "tailray": (f"{CARGO_BIN}/tailray", "installers"),
    "blesh": (f"{HOME}/.local/share/ble.sh", "installers"),
    "mpv-scripts": (f"{HOME}/.config/mpv/scripts/thumbfast.lua", "installers"),
    "qmk-udev": ("/etc/udev/rules.d/50-qmk.rules", "installers"),
}


def load_tools():
    with open(YAML_PATH) as f:
        return yaml.safe_load(f)


def load_versions():
    with open(VERSIONS_PATH) as f:
        return yaml.safe_load(f)


def tool_guard(name, category, opts):
    """Return the guard file path for a tool.

    Checks version markers first (~/.cache/salt-versions/) — these are
    written by macros and are the single source of truth for versioned tools.
    Falls back to simple binary paths for unversioned tools (pip, cargo, etc).
    """
    if isinstance(opts, str):
        opts = {}
    # Version markers written by install macros (covers all versioned tools,
    # including curl_extract_zip/tar with complex binary paths)
    for d in (VER_DIR, SYS_VER_DIR):
        marker = f"{d}/{name}"
        if os.path.isfile(marker):
            return marker
    # Fallback for tools without version markers
    if category == "cargo_pkg":
        return f"{CARGO_BIN}/{opts.get('bin', name)}"
    return f"{BIN}/{opts.get('bin', name)}"


def state_id(name):
    return f"install_{name.replace('-', '_')}"


def fetch_latest_tag(repo):
    """Fetch latest release tag from GitHub API."""
    url = f"https://api.github.com/repos/{repo}/releases/latest"
    headers = {"Accept": "application/vnd.github.v3+json"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"token {token}"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            return data.get("tag_name", "?")
    except Exception:
        return "?"


def fetch_latest_npm(package):
    """Fetch latest version from npm registry."""
    url = f"https://registry.npmjs.org/{package}/latest"
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            return data.get("version", "?")
    except Exception:
        return "?"


def build_tool_map(tools):
    """Build flat map: name -> {category, opts, guard, installed, sls}."""
    result = {}
    for category, entries in tools.items():
        for name, opts in entries.items():
            gp = tool_guard(name, category, opts)
            result[name] = {
                "category": category,
                "opts": opts if isinstance(opts, dict) else {},
                "guard": gp,
                "installed": os.path.exists(gp) if gp else False,
                "sls": SLS_NAME,
            }
    # Add custom tools
    for name, (gp, sls) in CUSTOM_TOOLS.items():
        result[name] = {
            "category": "custom",
            "opts": {},
            "guard": gp,
            "installed": os.path.exists(gp),
            "sls": sls,
        }
    return result


def cmd_list(tool_map):
    """List all tools with install status."""
    # Group by category
    by_cat = {}
    for name, info in sorted(tool_map.items()):
        cat = info["category"]
        by_cat.setdefault(cat, []).append((name, info))

    for cat in [
        "curl_bin",
        "github_tar",
        "pip_pkg",
        "cargo_pkg",
        "curl_extract_zip",
        "curl_extract_tar",
        "custom",
    ]:
        if cat not in by_cat:
            continue
        print(f"\n  \033[1m{cat}\033[0m")
        for name, info in by_cat[cat]:
            mark = "\033[32m+\033[0m" if info["installed"] else "\033[31m-\033[0m"
            print(f"    {mark} {name}")


def cmd_check(ci=False):
    """Check latest GitHub versions against pinned versions.yaml.

    When ci=True, outputs a markdown table of outdated tools and returns
    exit code 1 if any updates are available.
    """
    versions = load_versions()

    results = []
    for key, repo in sorted(GITHUB_REPOS.items()):
        pinned = versions.get(key, "?")
        latest = fetch_latest_tag(repo)
        latest_clean = latest.lstrip("v") if latest != "?" else "?"
        pinned_clean = str(pinned).lstrip("v")
        results.append((key, repo, pinned_clean, latest_clean, latest))

    # npm package checks
    for key, pkg in sorted(NPM_PACKAGES.items()):
        pinned = versions.get(key, "?")
        latest = fetch_latest_npm(pkg)
        pinned_clean = str(pinned)
        results.append((key, f"npm:{pkg}", pinned_clean, latest, latest))

    if ci:
        outdated = [(k, r, p, lc, tag) for k, r, p, lc, tag in results if lc not in ("?", p)]
        if not outdated:
            print("All pinned versions are up to date.")
            return 0
        print("| Tool | Pinned | Latest | Source |")
        print("|------|--------|--------|--------|")
        for key, repo, pinned, _, tag in outdated:
            print(f"| {key} | {pinned} | {tag} | {repo} |")
        return 1

    print("Checking pinned versions against latest releases...\n")
    for key, repo, pinned_clean, latest_clean, latest in results:
        if latest_clean == "?":
            status = "\033[33m?\033[0m"
        elif latest_clean == pinned_clean:
            status = "\033[32m=\033[0m"
        else:
            status = "\033[31m!\033[0m"
        print(f"  {status} {key:20s} pinned: {pinned_clean:12s} latest: {latest:12s} ({repo})")
    return 0


def update_with_salt(name, info):
    """Remove guard file and re-run Salt state."""
    gp = info["guard"]
    sid = state_id(name)
    sls = info["sls"]

    if gp and os.path.exists(gp):
        print(f"  Removing {gp}")
        try:
            os.remove(gp)
        except PermissionError:
            try:
                subprocess.run(["sudo", "rm", "-f", gp], check=True)
            except subprocess.CalledProcessError:
                print(f"  \033[31mFailed to remove {gp} (permission denied)\033[0m")
                return False

    print(f"  Running {sid} from {sls}...")
    result = subprocess.run(
        [
            "sudo",
            "salt-call",
            "--local",
            f"--config-dir={SALT_CONFIG}",
            "state.sls_id",
            sid,
            sls,
        ],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        print("  \033[31mFAILED\033[0m")
        stderr = result.stderr.strip()
        if stderr:
            for line in stderr.split("\n")[:5]:
                print(f"    {line}")
        return False

    if gp and os.path.exists(gp):
        print("  \033[32mOK\033[0m")
    else:
        print("  \033[33mDone (no guard file)\033[0m")
    return True


def update_pip(name, opts):
    """Update pip package via pipx."""
    pkg = opts.get("pkg", name)
    print(f"  pipx upgrade {pkg}")
    result = subprocess.run(["pipx", "upgrade", pkg])
    if result.returncode != 0:
        print("  \033[31mFAILED\033[0m")
        return False
    print("  \033[32mOK\033[0m")
    return True


def update_cargo(name, opts):
    """Update cargo package."""
    git = opts.get("git")
    if git:
        cmd = ["cargo", "install", "--git", git]
    else:
        pkg = opts.get("pkg", name)
        cmd = ["cargo", "install", pkg]
    print(f"  {' '.join(cmd)}")
    result = subprocess.run(cmd)
    if result.returncode != 0:
        print("  \033[31mFAILED\033[0m")
        return False
    print("  \033[32mOK\033[0m")
    return True


def cmd_update(names, tool_map):
    """Update specified tools."""
    failed = 0
    for name in names:
        if name not in tool_map:
            print(f"\033[31mUnknown tool: {name}\033[0m")
            print("  Use --list to see available tools")
            failed += 1
            continue

        info = tool_map[name]
        cat = info["category"]
        print(f"\033[1m{name}\033[0m ({cat})")

        if cat == "pip_pkg":
            ok = update_pip(name, info["opts"])
        elif cat == "cargo_pkg":
            ok = update_cargo(name, info["opts"])
        else:
            ok = update_with_salt(name, info)

        if not ok:
            failed += 1

    return failed


def main():
    parser = argparse.ArgumentParser(
        description="Manage tools from data/installers.yaml",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Examples:\n"
        "  %(prog)s                    List all tools\n"
        "  %(prog)s --check            Check pinned vs latest GitHub versions\n"
        "  %(prog)s --check --ci       Markdown output, exit 1 if updates\n"
        "  %(prog)s --update sops eza  Update specific tools\n"
        "  %(prog)s --update --all     Update everything\n",
    )
    parser.add_argument(
        "--check", action="store_true", help="check pinned vs latest GitHub versions"
    )
    parser.add_argument(
        "--ci", action="store_true", help="CI mode: markdown output, exit 1 if updates available"
    )
    parser.add_argument("--update", nargs="*", metavar="TOOL", help="update tools (or --all)")
    parser.add_argument("--all", action="store_true", help="update all tools (with --update)")
    args = parser.parse_args()

    os.chdir(PROJECT_ROOT)
    tools = load_tools()
    tool_map = build_tool_map(tools)

    if args.check:
        sys.exit(cmd_check(ci=args.ci))
    elif args.update is not None:
        if args.all:
            names = sorted(tool_map.keys())
        elif args.update:
            names = args.update
        else:
            parser.error("--update requires tool names or --all")
        failed = cmd_update(names, tool_map)
        sys.exit(1 if failed else 0)
    else:
        cmd_list(tool_map)


if __name__ == "__main__":
    main()
