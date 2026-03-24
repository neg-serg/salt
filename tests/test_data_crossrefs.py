"""Unit tests for data file cross-reference consistency.

Validates that references between states/data/*.yaml files resolve correctly:
- installers.yaml ${VER} URLs → versions.yaml keys
- service_catalog.yaml packages → packages.yaml entries
- monitored_services.yaml names → service_catalog/services.yaml keys
"""

import os
import re

import pytest
import yaml

DATA_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "states", "data"
)


def load_yaml(filename):
    """Load a YAML data file from states/data/, returning parsed content."""
    path = os.path.join(DATA_DIR, filename)
    with open(path) as fh:
        return yaml.safe_load(fh.read())


def flatten_packages(packages_data):
    """Collect all package names from packages.yaml across all categories."""
    names = set()
    for category, pkgs in packages_data.items():
        if not isinstance(pkgs, list):
            continue
        for entry in pkgs:
            # Strip inline comments: "pkg-name  # description" → "pkg-name"
            name = str(entry).split("#")[0].strip()
            if name:
                names.add(name)
    return names


def extract_version_entries(installers_data):
    """Find installer entries whose URLs contain ${VER}, return entry names."""
    ver_re = re.compile(r"\$\{VER\}")
    entries = []
    for macro_type, tools in installers_data.items():
        if not isinstance(tools, dict):
            continue
        for name, config in tools.items():
            if not isinstance(config, dict):
                continue
            for _key, val in config.items():
                if isinstance(val, str) and ver_re.search(val):
                    entries.append(name)
                    break
    return entries


# --- US1: Version key cross-references ---


def test_installer_version_keys_exist():
    """Every installer entry using ${VER} must have a matching versions.yaml key."""
    installers = load_yaml("installers.yaml")
    versions = load_yaml("versions.yaml")
    entries_with_ver = extract_version_entries(installers)

    missing = []
    for name in entries_with_ver:
        # Normalize: tool-name → tool_name (versions.yaml convention)
        ver_key = name.replace("-", "_")
        if ver_key not in versions:
            missing.append(f"{name} (expected key: {ver_key})")

    assert not missing, f"Installer entries reference missing version keys: {missing}"


# --- US1: Catalog package field validation ---


def test_catalog_packages_are_valid():
    """Every packages field in service_catalog.yaml must be a non-empty string."""
    catalog = load_yaml("service_catalog.yaml")

    invalid = []
    for svc_name, svc_config in catalog.items():
        if not isinstance(svc_config, dict):
            continue
        pkgs_field = svc_config.get("packages")
        if pkgs_field is None:
            continue  # packages is optional (e.g., ollama installed externally)
        if not isinstance(pkgs_field, str) or not pkgs_field.strip():
            invalid.append(f"{svc_name}: packages must be non-empty string, got {pkgs_field!r}")

    assert not invalid, f"Invalid catalog package fields: {invalid}"


# --- US1: Monitored services cross-references ---


def _collect_known_services():
    """Collect all service names from catalog, services.yaml, and base OS."""
    known = set()
    catalog = load_yaml("service_catalog.yaml")
    for name, config in catalog.items():
        if isinstance(config, dict):
            known.add(name)
            unit = config.get("unit", "")
            if unit:
                known.add(unit)

    services = load_yaml("services.yaml")
    simple = services.get("simple", {})
    if isinstance(simple, dict):
        for name, config in simple.items():
            known.add(name)
            if isinstance(config, dict):
                svc = config.get("service", "")
                if svc:
                    known.add(svc)

    # Services managed by dedicated .sls files or the OS (not in catalog).
    # These are always present and intentionally outside the catalog.
    states_dir = os.path.join(os.path.dirname(DATA_DIR))
    for sls in os.listdir(states_dir):
        if sls.endswith(".sls"):
            known.add(sls[:-4])  # e.g., "mpd.sls" → "mpd"
            known.add(sls[:-4].replace("_", "-"))  # "openclaw_agent" → "openclaw-agent"

    # Base OS services (always present, never Salt-managed)
    known.update({"sshd", "NetworkManager", "cronie"})

    # User/system unit files deployed by Salt (unit name = service name)
    units_dir = os.path.join(states_dir, "units")
    for scope_dir in ("user", "system"):
        scope_path = os.path.join(units_dir, scope_dir)
        if os.path.isdir(scope_path):
            for unit_file in os.listdir(scope_path):
                # Strip .service/.timer suffix to get service name
                for suffix in (".service", ".timer", ".socket", ".path"):
                    if unit_file.endswith(suffix):
                        known.add(unit_file[: -len(suffix)])

    return known


@pytest.mark.parametrize("scope", ["system_services", "user_services"])
def test_monitored_services_resolvable(scope):
    """Non-optional monitored services must trace to catalog, services, or .sls."""
    monitored = load_yaml("monitored_services.yaml")
    known = _collect_known_services()

    entries = monitored.get(scope, [])
    if not isinstance(entries, list):
        return

    missing = []
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        name = entry.get("name", "")
        is_optional = entry.get("optional", False)
        normalized = name.replace("-", "_")
        if not is_optional and name not in known and normalized not in known:
            missing.append(name)

    assert not missing, f"Monitored {scope} reference unknown services: {missing}"


def test_user_services_schema_is_valid():
    """user_services.yaml entries must follow the feature-tagged contract."""
    user_services = load_yaml("user_services.yaml")
    unit_files = user_services.get("unit_files", [])
    enable_services = user_services.get("enable_services", [])
    enable_now = user_services.get("enable_now_timers", [])

    allowed_features = {"mail", "vdirsyncer", "mpd"}
    seen_ids = set()

    invalid = []
    for entry in unit_files:
        if not isinstance(entry, dict):
            invalid.append(f"unit_files entry must be mapping, got {type(entry).__name__}")
            continue
        entry_id = entry.get("id")
        filename = entry.get("filename")
        if not isinstance(entry_id, str) or not entry_id:
            invalid.append(f"unit_files entry missing valid id: {entry!r}")
        elif entry_id in seen_ids:
            invalid.append(f"duplicate unit_files id: {entry_id}")
        else:
            seen_ids.add(entry_id)
        if not isinstance(filename, str) or not filename:
            invalid.append(f"unit_files entry missing valid filename: {entry!r}")
        features = entry.get("features", [])
        if features and (
            not isinstance(features, list)
            or any(feature not in allowed_features for feature in features)
        ):
            invalid.append(f"unit_files entry has invalid features: {entry!r}")

    for group_name, entries in (
        ("enable_services", enable_services),
        ("enable_now_timers", enable_now),
    ):
        for entry in entries:
            if not isinstance(entry, dict):
                invalid.append(f"{group_name} entry must be mapping, got {type(entry).__name__}")
                continue
            name = entry.get("name")
            if not isinstance(name, str) or not name:
                invalid.append(f"{group_name} entry missing valid name: {entry!r}")
            features = entry.get("features", [])
            if features and (
                not isinstance(features, list)
                or any(feature not in allowed_features for feature in features)
            ):
                invalid.append(f"{group_name} entry has invalid features: {entry!r}")

    assert not invalid, f"Invalid user_services.yaml schema: {invalid}"
