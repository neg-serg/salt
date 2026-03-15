"""
PoC port of states/installers.sls to pyinfra — migration research only.

This file demonstrates what a real Salt→pyinfra migration looks like for a
data-driven state file with macros, retry logic, and idempotency guards.

SALT ORIGINAL: states/installers.sls (112 lines of Jinja+YAML)
PYINFRA PORT:  this file (~200 lines of Python)

Key observations documented inline as # MIGRATION NOTE comments.
"""

import os
from pathlib import Path

import yaml
from pyinfra.operations import files, server

# ---------------------------------------------------------------------------
# Constants (equivalent of _macros_common.jinja exports)
# ---------------------------------------------------------------------------
USER = "neg"
HOME = f"/home/{USER}"
LOCAL_BIN = f"{HOME}/.local/bin"
VER_DIR = f"{HOME}/.local/share/salt-versions"
DOWNLOAD_CACHE = f"{HOME}/.cache/salt-downloads"
RETRY_ATTEMPTS = 3
RETRY_DELAY = 10

# ---------------------------------------------------------------------------
# Data loading (equivalent of import_yaml)
# ---------------------------------------------------------------------------
# MIGRATION NOTE: In Salt, `import_yaml` is a built-in Jinja tag.
# In pyinfra, we use standard Python. This is arguably cleaner.
STATES_DIR = Path(__file__).resolve().parent.parent.parent.parent / "states"
DATA_DIR = STATES_DIR / "data"

with open(DATA_DIR / "installers.yaml") as f:
    tools = yaml.safe_load(f)

with open(DATA_DIR / "versions.yaml") as f:
    ver = yaml.safe_load(f)


# ---------------------------------------------------------------------------
# Macro equivalents (replacing _macros_install.jinja)
# ---------------------------------------------------------------------------


def curl_bin(name: str, url: str, version: str | None = None, hash: str | None = None):
    """
    Equivalent of {{ curl_bin(name, url, version, hash) }} macro.

    SALT VERSION (rendered from macro, ~30 lines of Jinja):
        install_rofi_systemd:
          cmd.run:
            - name: |
                set -eo pipefail
                curl -fsSL '...' -o /tmp/...
                chmod +x ...
                mv ... ~/.local/bin/rofi-systemd
            - runas: neg
            - creates: /home/neg/.local/bin/rofi-systemd
            - parallel: True
            - retry: {attempts: 3, interval: 10}

    MIGRATION NOTE: pyinfra has NO `parallel: True` for single-host.
    This is the critical regression — all downloads become sequential.
    """
    bin_path = f"{LOCAL_BIN}/{name}"
    cache_key = f"{name}-{version or 'latest'}"
    cache_path = f"{DOWNLOAD_CACHE}/{cache_key}"
    ver_marker = f"{VER_DIR}/{name}@{version}" if version else None
    creates = ver_marker or bin_path

    # MIGRATION NOTE: Salt's `creates:` becomes a Python lambda in `_if`.
    # More verbose, but functionally equivalent.
    hash_check = f'echo "{hash}  $cache.tmp" | sha256sum -c --strict' if hash else ""

    server.shell(
        name=f"install_{name.replace('-', '_')}",
        commands=[
            f"""
            set -eo pipefail
            cache='{cache_path}'
            mkdir -p "$(dirname "$cache")"
            if [ ! -f "$cache" ]; then
              curl -fsSL '{url}' -o "$cache.tmp"
              {hash_check}
              mv -f "$cache.tmp" "$cache"
            fi
            cp "$cache" {bin_path}.tmp
            chmod +x {bin_path}.tmp
            mv -f {bin_path}.tmp {bin_path}
            {f"mkdir -p {VER_DIR} && touch {ver_marker}" if version else ""}
        """
        ],
        _su_user=USER,
        _shell_executable="/bin/bash",
        _if=lambda: not os.path.exists(creates),
        _retries=RETRY_ATTEMPTS,
        _retry_delay=RETRY_DELAY,
    )


def pip_pkg(name: str, pkg: str | None = None, bin: str | None = None, env: str | None = None):
    """
    Equivalent of {{ pip_pkg(name, pkg, bin, env) }} macro.

    MIGRATION NOTE: Almost identical logic. The `_if` guard replaces `creates:`.
    """
    binary = bin or name
    package = pkg or name
    env_prefix = f"{env} " if env else ""

    server.shell(
        name=f"install_{name.replace('-', '_')}",
        commands=[
            f"""
            {env_prefix}pipx install {package} 2>/dev/null || true
            test -x {LOCAL_BIN}/{binary} || {env_prefix}pipx reinstall {package}
        """
        ],
        _su_user=USER,
        _if=lambda: not os.path.exists(f"{LOCAL_BIN}/{binary}"),
        _retries=RETRY_ATTEMPTS,
        _retry_delay=RETRY_DELAY,
    )


def cargo_pkg(name: str, pkg: str | None = None, bin: str | None = None, git: str | None = None):
    """
    Equivalent of {{ cargo_pkg(name, pkg, bin, git) }} macro.
    """
    binary = bin or name
    if git:
        install_cmd = f"cargo install --git {git}"
    else:
        install_cmd = f"cargo install {pkg or name}"

    server.shell(
        name=f"install_{name.replace('-', '_')}",
        commands=[install_cmd],
        _su_user=USER,
        _if=lambda: not os.path.exists(f"{LOCAL_BIN}/{binary}"),
        _retries=RETRY_ATTEMPTS,
        _retry_delay=RETRY_DELAY,
    )


def git_clone_deploy(name: str, repo: str, dest: str, creates: str | None = None):
    """
    Equivalent of {{ git_clone_deploy(name, repo, dest) }} macro.
    """
    server.shell(
        name=f"install_{name.replace('-', '_')}",
        commands=[f"git clone {repo} {dest}"],
        _su_user=USER,
        _if=lambda: not os.path.exists(creates or dest),
        _retries=RETRY_ATTEMPTS,
        _retry_delay=RETRY_DELAY,
    )


def paru_install(name: str, pkg: str):
    """
    Equivalent of {{ paru_install(name, pkg) }} macro.

    MIGRATION NOTE: pyinfra has NO built-in AUR support. Must shell out to paru.
    Salt also shells out (via paru_install macro), so functionally equivalent.
    """
    server.shell(
        name=f"install_{name.replace('-', '_')}",
        commands=[f"paru -S --noconfirm --needed {pkg}"],
        _su_user=USER,
        _if=lambda: os.popen(f"pacman -Q {pkg} 2>/dev/null").read().strip() == "",
        _retries=RETRY_ATTEMPTS,
        _retry_delay=RETRY_DELAY,
    )


def http_file(name: str, url: str, dest: str, mode: str = "0644"):
    """
    Equivalent of {{ http_file(name, url, dest) }} macro.
    """
    server.shell(
        name=f"install_{name.replace('-', '_')}",
        commands=[f"curl -fsSL '{url}' -o '{dest}'", f"chmod {mode} '{dest}'"],
        _if=lambda: not os.path.exists(dest),
        _retries=RETRY_ATTEMPTS,
        _retry_delay=RETRY_DELAY,
    )


# ===========================================================================
# Data-driven installs (equivalent of Jinja for-loops over tools dict)
# ===========================================================================

# MIGRATION NOTE: In Salt, these are Jinja for-loops that generate YAML states.
# In pyinfra, they're Python for-loops calling functions. This is cleaner.
# However, ALL operations run sequentially — Salt's `parallel: True` is lost.

# --- Direct binary downloads ---
for name, raw in tools.get("curl_bin", {}).items():
    _v = ver.get(name.replace("-", "_"), "")
    if isinstance(raw, dict):
        resolved_url = raw["url"].replace("${VER}", str(_v))
        curl_bin(name, resolved_url, version=_v or None, hash=raw.get("hash"))
    else:
        resolved_url = raw.replace("${VER}", str(_v))
        curl_bin(name, resolved_url, version=_v or None)

# --- GitHub tar.gz archives ---
# (currently empty in installers.yaml, but the pattern is preserved)
for name, raw in tools.get("github_tar", {}).items():
    _v = ver.get(name.replace("-", "_"), "")
    if isinstance(raw, dict):
        resolved_url = raw["url"].replace("${VER}", str(_v))
    else:
        resolved_url = raw.replace("${VER}", str(_v))
    # github_tar would be similar to curl_extract_tar — omitted for brevity

# --- pip installs ---
for name, opts in tools.get("pip_pkg", {}).items():
    pip_pkg(name, pkg=opts.get("pkg"), bin=opts.get("bin"))

# --- cargo installs ---
for name, opts in tools.get("cargo_pkg", {}).items():
    cargo_pkg(name, pkg=opts.get("pkg"), bin=opts.get("bin"), git=opts.get("git"))

# --- ZIP/tar extractions ---
# (currently empty or skipped in installers.yaml)

# ===========================================================================
# AUR installs
# ===========================================================================
paru_install("tdl", "tdl-bin")

# One-time cleanup: remove old manually-installed binary
# MIGRATION NOTE: Salt's `file.absent` + `onlyif` becomes files.file + _if
files.file(
    name="tdl_legacy_cleanup",
    path=f"{LOCAL_BIN}/tdl",
    present=False,
    _if=lambda: os.path.exists(f"{LOCAL_BIN}/tdl"),
)

# ===========================================================================
# Custom installs
# ===========================================================================

# --- Shell frameworks ---
git_clone_deploy(
    "zi",
    "https://github.com/z-shell/zi.git",
    "~/.config/zi/bin",
    creates=f"{HOME}/.config/zi/bin/zi.zsh",
)

# --- aider (AI coding assistant) ---
# MIGRATION NOTE: Salt version has `parallel: True` — lost in pyinfra.
server.shell(
    name="aider_install",
    commands=["uv tool install aider-chat --python 3.12"],
    _su_user=USER,
    _if=lambda: not os.path.exists(f"{LOCAL_BIN}/aider"),
    _retries=RETRY_ATTEMPTS,
    _retry_delay=RETRY_DELAY,
)

# --- dr14_tmeter ---
pip_pkg(
    "dr14_tmeter",
    pkg="git+https://github.com/simon-r/dr14_t.meter.git",
    env="GIT_CONFIG_GLOBAL=/dev/null",
)

# --- QMK udev rules ---
http_file(
    "qmk_udev_rules",
    "https://raw.githubusercontent.com/qmk/qmk_firmware/master/util/udev/50-qmk.rules",
    "/etc/udev/rules.d/50-qmk.rules",
)

# MIGRATION NOTE: Salt's `onchanges:` for udev reload becomes manual change tracking.
# This is the MOST VERBOSE migration pattern — 5 lines of Python vs 3 lines of YAML.
# In Salt:
#   qmk_udev_rules_reload:
#     cmd.run:
#       - name: udevadm control --reload-rules
#       - onchanges:
#         - cmd: qmk_udev_rules
#
# In pyinfra, we'd need to check the previous operation's change state:
# (pyinfra v3.0+ OperationMeta approach)
# qmk_op = http_file(...)  # would need to return OperationMeta
# with qmk_op.did_change:
#     server.shell(commands=["udevadm control --reload-rules"])
#
# BUT: http_file is our custom function, not a pyinfra operation that returns
# OperationMeta. We'd need to restructure all macros to return OperationMeta
# objects, which adds complexity throughout the codebase.
#
# For now, unconditionally reload (safe but wasteful):
server.shell(
    name="qmk_udev_rules_reload",
    commands=["udevadm control --reload-rules"],
    _if=lambda: os.path.exists("/usr/bin/udevadm"),
)


# ===========================================================================
# MIGRATION ANALYSIS SUMMARY
# ===========================================================================
#
# Lines of code:
#   Salt (installers.sls + macros used): ~112 + ~200 (shared macros) = ~312
#   pyinfra (this file):                 ~220 (self-contained)
#
# Key differences:
#   1. NO parallel execution — all downloads are sequential
#   2. NO declarative onchanges — udev reload is unconditional
#   3. Data loading is explicit Python (cleaner but more verbose)
#   4. Idempotency guards are lambdas (more verbose than `creates:`)
#   5. Macros are Python functions (cleaner, testable, type-checked)
#
# Porting time for this file: ~2 hours
# Estimated for full codebase (36 files): 3-5 weeks
#
# Verdict: The Python is cleaner for macro definitions but WORSE for:
#   - Parallelism (critical regression)
#   - Declarative change tracking (watch/onchanges)
#   - Idempotency guards (verbose lambdas vs simple `creates:`)
