"""Unit tests for feature matrix structural integrity.

Validates that states/data/feature_matrix.yaml scenarios are well-formed:
- Required fields present (name, description, overrides)
- Scenario names unique
- Override keys exist in hosts.yaml defaults schema
"""

import os
import sys

import pytest

SCRIPTS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts")
sys.path.insert(0, SCRIPTS_DIR)

import host_model  # noqa: E402, I001


def flatten_keys(d, prefix=""):
    """Extract all dotpath keys from a nested dict."""
    keys = set()
    for k, v in d.items():
        path = f"{prefix}.{k}" if prefix else k
        keys.add(path)
        if isinstance(v, dict):
            keys.update(flatten_keys(v, path))
    return keys


def _check_keys_exist(overrides, defaults, prefix=""):
    """Recursively check that every key in overrides exists in defaults."""
    unknown = []
    for k, v in overrides.items():
        path = f"{prefix}.{k}" if prefix else k
        if k not in defaults:
            unknown.append(path)
        elif isinstance(v, dict) and isinstance(defaults.get(k), dict):
            unknown.extend(_check_keys_exist(v, defaults[k], path))
    return unknown


# --- US3: Feature matrix structural integrity ---


class TestFeatureMatrixStructure:
    """Validate feature_matrix.yaml scenario structure."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.matrix = host_model.load_feature_matrix()
        self.hosts_data = host_model.load_hosts_yaml()
        self.defaults = self.hosts_data.get("defaults", {})

    def test_scenarios_have_required_fields(self):
        """Every scenario must have name (str), description (str), overrides (dict)."""
        for i, scenario in enumerate(self.matrix):
            assert isinstance(scenario.get("name"), str), (
                f"Scenario #{i}: 'name' must be a string, got {type(scenario.get('name'))}"
            )
            assert isinstance(scenario.get("description"), str), (
                f"Scenario #{i} ({scenario.get('name', '?')}): 'description' must be a string"
            )
            assert isinstance(scenario.get("overrides"), dict), (
                f"Scenario #{i} ({scenario.get('name', '?')}): 'overrides' must be a dict"
            )

    def test_scenario_names_unique(self):
        """No duplicate scenario names."""
        names = [s.get("name") for s in self.matrix]
        duplicates = [n for n in names if names.count(n) > 1]
        assert not duplicates, f"Duplicate scenario names: {set(duplicates)}"

    def test_override_keys_exist_in_defaults(self):
        """Every override key path must exist in hosts.yaml defaults."""
        all_unknown = []
        for scenario in self.matrix:
            name = scenario.get("name", "?")
            overrides = scenario.get("overrides", {})
            unknown = _check_keys_exist(overrides, self.defaults)
            for key in unknown:
                all_unknown.append(f"{name}: {key}")
        assert not all_unknown, f"Unknown override keys: {all_unknown}"
