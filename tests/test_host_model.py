"""Unit tests for scripts/host_model.py — shared host model builder."""

import os
import sys

import pytest

# Add scripts/ to path so we can import host_model
SCRIPTS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts")
sys.path.insert(0, SCRIPTS_DIR)

import host_model  # noqa: E402, I001


# --- recursive_merge ---


def test_recursive_merge_basic():
    base = {"a": 1, "b": {"x": 10, "y": 20}, "c": [1, 2]}
    override = {"a": 2, "b": {"y": 99, "z": 30}, "c": [3]}
    result = host_model.recursive_merge(base, override)
    assert result["a"] == 2
    assert result["b"] == {"x": 10, "y": 99, "z": 30}
    assert result["c"] == [3]  # lists override, not merge


def test_recursive_merge_empty():
    base = {"a": 1, "b": {"x": 10}}
    result = host_model.recursive_merge(base, {})
    assert result == base
    assert result is not base  # must be a copy


def test_recursive_merge_does_not_mutate_base():
    base = {"a": 1, "b": {"x": 10}}
    override = {"b": {"x": 99}}
    host_model.recursive_merge(base, override)
    assert base["b"]["x"] == 10  # base unchanged


# --- enable_all_features ---


def test_enable_all_features():
    config = {
        "user": "neg",
        "features": {
            "steam": False,
            "monitoring": {"loki": False, "sysstat": True},
            "mpd": True,
        },
    }
    result = host_model.enable_all_features(config)
    assert result["features"]["steam"] is True
    assert result["features"]["monitoring"]["loki"] is True
    assert result["features"]["monitoring"]["sysstat"] is True
    assert result["features"]["mpd"] is True
    assert result["user"] == "neg"  # non-features unchanged


def test_enable_all_features_preserves_non_bool():
    config = {"features": {"name": "test", "count": 42, "enabled": False}}
    result = host_model.enable_all_features(config)
    assert result["features"]["name"] == "test"
    assert result["features"]["count"] == 42
    assert result["features"]["enabled"] is True


# --- build_lint_host ---


def test_build_lint_host_derived_fields():
    host = host_model.build_lint_host()
    assert "runtime_dir" in host
    assert host["runtime_dir"] == f"/run/user/{host['uid']}"
    assert host["pkg_list"] == "/var/cache/salt/pacman_installed.txt"
    assert host["project_dir"] == host["home"] + "/src/salt"


def test_build_lint_host_all_features_enabled():
    host = host_model.build_lint_host()
    features = host.get("features", {})

    def check_no_false(d, path="features"):
        for k, v in d.items():
            if isinstance(v, dict):
                check_no_false(v, f"{path}.{k}")
            elif v is False:
                pytest.fail(f"{path}.{k} is False — should be True in lint host")

    check_no_false(features)


def test_build_lint_host_has_hostname():
    host = host_model.build_lint_host()
    assert host["hostname"] == "lint-check"


# --- load_hosts_yaml ---


def test_load_hosts_yaml():
    data = host_model.load_hosts_yaml()
    assert isinstance(data, dict)
    assert "defaults" in data
    assert "hosts" in data
    assert "aliases" in data


# --- check_host_config ---


def test_check_host_config_valid():
    errors = host_model.check_host_config()
    assert errors == 0


def test_check_host_config_unknown_key(capsys):
    data = host_model.load_hosts_yaml()
    defaults = data.get("defaults", {})
    fake_config = {"typo_key": "oops"}
    errors = host_model.check_unknown_keys(fake_config, defaults, "test-host")
    assert errors == 1
    captured = capsys.readouterr()
    assert "unknown key" in captured.out
    assert "typo_key" in captured.out


# --- alias resolution ---


def test_alias_resolution():
    data = host_model.load_hosts_yaml()
    host_via_alias = host_model.build_host("cachyos", data)
    host_direct = host_model.build_host("telfir", data)
    # Both should resolve to telfir's config
    assert host_via_alias["hostname"] == host_direct["hostname"]


def test_unknown_host_returns_defaults():
    data = host_model.load_hosts_yaml()
    host = host_model.build_host("nonexistent-host", data)
    # Should return defaults with derived fields
    assert "runtime_dir" in host
    assert "pkg_list" in host
    assert host["user"] == data["defaults"]["user"]


# --- edge cases ---


def test_derived_fields_recomputed_after_override():
    """Edge case: if override contains runtime_dir, it should be recomputed."""
    data = host_model.load_hosts_yaml()
    data = data.copy()
    data["hosts"] = {"test-host": {"runtime_dir": "/bogus"}}
    host = host_model.build_host("test-host", data)
    # Derived field should be recomputed from uid, not taken from override
    assert host["runtime_dir"] == f"/run/user/{host['uid']}"


def test_load_feature_matrix():
    matrix = host_model.load_feature_matrix()
    assert isinstance(matrix, list)
    assert len(matrix) > 0
    for entry in matrix:
        assert "name" in entry


# --- US2: host config assembly pipeline ---


def test_full_assembly_pipeline():
    """Build a real host config and verify defaults + overrides + derived fields."""
    data = host_model.load_hosts_yaml()
    host = host_model.build_host("telfir", data)
    # Defaults should be present
    assert host["user"] == data["defaults"]["user"]
    assert host["home"] == f"/home/{data['defaults']['user']}"
    # Telfir-specific overrides should be applied
    assert "display" in host
    assert "floorp_profile" in host
    assert "zen_profile" in host
    # Derived fields should be computed
    assert host["runtime_dir"] == f"/run/user/{host['uid']}"
    assert host["project_dir"] == host["home"] + "/src/salt"


def test_alias_produces_identical_config():
    """Alias (cachyos→telfir) must produce an identical config dict."""
    data = host_model.load_hosts_yaml()
    via_alias = host_model.build_host("cachyos", data)
    direct = host_model.build_host("telfir", data)
    assert via_alias == direct


def test_derived_fields_from_custom_uid():
    """Override uid → derived runtime_dir should reflect the new uid."""
    data = host_model.load_hosts_yaml()
    data = data.copy()
    data["hosts"] = {"custom-uid-host": {"uid": 9999}}
    host = host_model.build_host("custom-uid-host", data)
    assert host["runtime_dir"] == "/run/user/9999"


def test_feature_flag_override_preserves_siblings():
    """Overriding one feature flag preserves sibling flags from defaults."""
    data = host_model.load_hosts_yaml()
    defaults_features = data["defaults"].get("features", {})
    data = data.copy()
    data["hosts"] = {"flag-test": {"features": {"steam": False}}}
    host = host_model.build_host("flag-test", data)
    assert host["features"]["steam"] is False
    # Other feature flags from defaults should still be present
    for key in defaults_features:
        if key != "steam":
            assert key in host["features"], f"Feature '{key}' missing after override"


def test_host_defaults_include_dual_browser_fields():
    data = host_model.load_hosts_yaml()
    defaults = data["defaults"]
    assert "floorp_profile" in defaults
    assert "zen_profile" in defaults
    assert defaults["floorp_profile"] == ""
    assert defaults["zen_profile"] == ""


def test_telfir_has_primary_and_secondary_browser_bindings():
    data = host_model.load_hosts_yaml()
    host = host_model.build_host("telfir", data)
    assert host["zen_profile"] == "qnkh60k3.Default (release)"
    assert host["floorp_profile"] == "c85pjaxk.default-default"
    assert host["features"]["floorp"] is True


# --- US4: deep merge edge cases ---


def test_merge_three_level_nesting():
    """3-level nested dicts merge recursively."""
    base = {"a": {"b": {"c": 1}}}
    override = {"a": {"b": {"d": 2}}}
    result = host_model.recursive_merge(base, override)
    assert result == {"a": {"b": {"c": 1, "d": 2}}}


def test_merge_list_replaces_entirely():
    """Lists are replaced, not appended."""
    base = {"k": [1, 2, 3]}
    override = {"k": [4, 5]}
    result = host_model.recursive_merge(base, override)
    assert result["k"] == [4, 5]


def test_merge_scalar_replaces_dict():
    """Scalar override replaces a dict base value."""
    base = {"k": {"nested": True}}
    override = {"k": "string"}
    result = host_model.recursive_merge(base, override)
    assert result["k"] == "string"


def test_merge_dict_replaces_scalar():
    """Dict override replaces a scalar base value."""
    base = {"k": "string"}
    override = {"k": {"nested": True}}
    result = host_model.recursive_merge(base, override)
    assert result["k"] == {"nested": True}


def test_merge_empty_dict_preserves_base():
    """Empty dict override does not clobber base nested dict."""
    base = {"a": {"x": 1}}
    override = {"a": {}}
    result = host_model.recursive_merge(base, override)
    assert result == {"a": {"x": 1}}


def test_merge_none_override():
    """None override replaces base value."""
    base = {"k": "val"}
    override = {"k": None}
    result = host_model.recursive_merge(base, override)
    assert result["k"] is None
