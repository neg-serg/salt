from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def test_host_defaults_expose_floorp_to_zen_migration_flag():
    text = read("states/data/hosts.yaml")
    assert "migrate_floorp_profile_to_zen: false" in text
    assert "migrate_floorp_profile_to_zen: true" in text


def test_zen_browser_state_wires_one_shot_floorp_profile_import():
    text = read("states/zen_browser.sls")
    assert "zen_floorp_profile_import" in text
    assert "migrate-floorp-to-zen-profile.sh" in text
    assert "floorp-profile-import-v1" in text
    assert "- creates: {{ zen_floorp_import_stamp }}" in text
    assert "- file: floorp_user_js" in text


def test_floorp_to_zen_migration_script_copies_user_data_only():
    text = read("scripts/migrate-floorp-to-zen-profile.sh")
    assert "places.sqlite" in text
    assert "bookmarkbackups" in text
    assert "storage" in text
    assert "extensions.json" not in text
    assert "chrome/userChrome.css" not in text


def test_zen_user_js_has_betterfox_prefs_from_floorp():
    """Zen user.js must carry the same Betterfox performance/network prefs as Floorp."""
    text = read("dotfiles/dot_config/zen-browser/user.js")
    # Fastfox: initial paint delay
    assert 'user_pref("nglayout.initialpaint.delay", 0);' in text
    # Network: bigger buffers
    assert 'user_pref("network.buffer.cache.size", 262144);' in text
    # Network: more connections
    assert 'user_pref("network.http.max-connections", 1800);' in text
    # Privacy: disable speculative connections
    assert 'user_pref("network.predictor.enabled", false);' in text
    # Cache: disk cache disabled
    assert 'user_pref("browser.cache.disk.enable", false);' in text
    # Download dir uses Jinja template
    assert "{{ home }}/dw" in text


def test_zen_state_templates_user_js_with_jinja():
    """zen_browser.sls must template user.js with Jinja for {{ home }} variable."""
    text = read("states/zen_browser.sls")
    assert "- template: jinja" in text
    assert "home: {{ home }}" in text
