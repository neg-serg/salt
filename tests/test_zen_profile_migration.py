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
