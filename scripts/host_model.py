"""Shared host model builder — single source of truth for Python tooling.

Loads states/data/hosts.yaml and states/data/feature_matrix.yaml, builds
fully-resolved host configurations (defaults + overrides + derived fields),
and validates host config structure.

Consumers: lint-jinja.py, render-matrix.py, index-salt.py.
Salt runtime uses host_config.jinja directly (cannot import Python modules).
"""

import getpass
import os
import re

import yaml

HOSTS_YAML_PATH = os.path.join("states", "data", "hosts.yaml")
FEATURE_MATRIX_PATH = os.path.join("states", "data", "feature_matrix.yaml")

GRAINS_HOSTNAME_SENTINEL = "{{ grains['host'] }}"

VALID_CPU_VENDORS = {"amd", "intel"}
KVM_MODULES = {"amd": "kvm_amd", "intel": "kvm_intel"}
DISPLAY_RE = re.compile(r"^\d+x\d+@\d+$")


# --- Loading ---


def load_hosts_yaml():
    """Load states/data/hosts.yaml (defaults, host overrides, aliases)."""
    try:
        with open(HOSTS_YAML_PATH) as fh:
            data = yaml.safe_load(fh.read()) or {}
    except FileNotFoundError:
        return {}
    except yaml.YAMLError:
        return {}
    if not isinstance(data, dict):
        return {}
    return data


def load_feature_matrix():
    """Load states/data/feature_matrix.yaml (synthetic test scenarios)."""
    try:
        with open(FEATURE_MATRIX_PATH) as fh:
            data = yaml.safe_load(fh.read()) or []
    except FileNotFoundError:
        return []
    except yaml.YAMLError:
        return []
    if not isinstance(data, list):
        return []
    return data


# --- Merge ---


def recursive_merge(base, override):
    """Recursive dict merge mimicking slsutil.merge(strategy='recurse')."""
    result = base.copy()
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = recursive_merge(result[k], v)
        else:
            result[k] = v
    return result


# --- Feature enablement ---


def deep_enable(d):
    """Recursively set all False booleans to True."""
    return {
        k: deep_enable(v) if isinstance(v, dict) else (True if v is False else v)
        for k, v in d.items()
    }


def enable_all_features(d):
    """Enable all feature flags in host config for maximum lint coverage."""
    if not isinstance(d, dict):
        return d
    result = d.copy()
    if "features" in result and isinstance(result["features"], dict):
        result["features"] = deep_enable(result["features"])
    return result


# --- Host building ---


def fallback_host():
    """Build a minimal fallback host config from the current environment."""
    user = os.environ.get("USER", getpass.getuser())
    home = os.path.expanduser("~")
    return {"user": user, "home": home, "pkg_list": "/var/cache/salt/pacman_installed.txt"}


def _add_derived_fields(host):
    """Compute derived fields from merged host config (in-place)."""
    if not host.get("home"):
        host["home"] = f"/home/{host['user']}"
    host["runtime_dir"] = f"/run/user/{host['uid']}"
    host["pkg_list"] = "/var/cache/salt/pacman_installed.txt"
    host["project_dir"] = host["home"] + "/src/salt"


def build_lint_host():
    """Build a synthetic host config with all features enabled for linting.

    Loads defaults from states/data/hosts.yaml, enables all feature flags, and
    adds derived fields.  This is needed because macros in _macros_pkg.jinja
    and _macros_service.jinja reference ``host`` directly (not via import).
    """
    data = load_hosts_yaml()
    defaults = data.get("defaults")
    if not isinstance(defaults, dict):
        return fallback_host()
    host = enable_all_features(defaults)
    host = recursive_merge(host, {})
    _add_derived_fields(host)
    host["hostname"] = "lint-check"
    return host


def build_host(hostname, hosts_data=None):
    """Build a fully-resolved host config for a specific hostname.

    Resolves aliases, merges defaults with host-specific overrides, and
    computes derived fields.  If hostname is not found (and not an alias),
    returns defaults with derived fields (same as host_config.jinja behavior).
    """
    if hosts_data is None:
        hosts_data = load_hosts_yaml()
    defaults = hosts_data.get("defaults", {})
    hosts = hosts_data.get("hosts", {})
    aliases = hosts_data.get("aliases", {})
    resolved = aliases.get(hostname, hostname)
    overrides = hosts.get(resolved, {})
    host = recursive_merge(defaults, overrides)
    _add_derived_fields(host)
    return host


# --- Validation ---


def check_unknown_keys(config, defaults, hostname, prefix=""):
    """Check for keys in host config that don't exist in defaults."""
    errors = 0
    for k, v in config.items():
        path = f"{prefix}.{k}" if prefix else k
        if k not in defaults:
            print(f"\033[31mHost config: '{hostname}': unknown key '{path}'\033[0m")
            errors += 1
        elif isinstance(v, dict) and isinstance(defaults.get(k), dict):
            errors += check_unknown_keys(v, defaults[k], hostname, path)
    return errors


def check_host_config():
    """Validate host configuration YAML: field types, allowed values, unknown keys."""
    data = load_hosts_yaml()
    defaults = data.get("defaults")
    hosts = data.get("hosts", {})
    if not isinstance(defaults, dict):
        return 0

    errors = 0
    for hostname, config in hosts.items():
        if not isinstance(config, dict):
            msg = type(config).__name__
            print(f"\033[31mHost config: '{hostname}': expected mapping, got {msg}\033[0m")
            errors += 1
            continue
        merged = recursive_merge(defaults, config)

        # Unknown keys (typo protection)
        errors += check_unknown_keys(config, defaults, hostname)

        # cpu_vendor must be amd or intel
        cpu = merged.get("cpu_vendor")
        if cpu not in VALID_CPU_VENDORS:
            print(
                f"\033[31mHost config: '{hostname}':"
                f" cpu_vendor '{cpu}' not in {VALID_CPU_VENDORS}\033[0m"
            )
            errors += 1

        # kvm_module must match cpu_vendor
        expected_kvm = KVM_MODULES.get(cpu)
        if expected_kvm and merged.get("kvm_module") != expected_kvm:
            print(
                f"\033[31mHost config: '{hostname}':"
                f" kvm_module '{merged.get('kvm_module')}' doesn't match"
                f" cpu_vendor '{cpu}' (expected '{expected_kvm}')\033[0m"
            )
            errors += 1

        # display format: WxH@Hz (if set)
        display = merged.get("display", "")
        if display and not DISPLAY_RE.match(display):
            print(
                f"\033[31mHost config: '{hostname}':"
                f" display '{display}' doesn't match WxH@Hz format\033[0m"
            )
            errors += 1

        # hostname field should match dict key
        h = merged.get("hostname")
        if h not in (hostname, "__grains__", GRAINS_HOSTNAME_SENTINEL):
            print(
                f"\033[31mHost config: '{hostname}':"
                f" hostname field '{h}' doesn't match dict key\033[0m"
            )
            errors += 1

        # Numeric fields
        for field in ("uid", "greetd_scale", "cursor_size"):
            if not isinstance(merged.get(field), int):
                print(
                    f"\033[31mHost config: '{hostname}':"
                    f" {field} must be int, got {type(merged.get(field)).__name__}\033[0m"
                )
                errors += 1

    return errors
