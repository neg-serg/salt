"""Contract tests for managed Hiddify automation."""

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def test_system_description_includes_hiddify_state_by_default():
    source = (REPO_ROOT / "states" / "system_description.sls").read_text()

    assert "host.features.network.get('hiddify', True)" in source
    assert "- hiddify" in source


def test_hiddify_state_removes_legacy_appimage_and_prefers_hiddify_next():
    source = (REPO_ROOT / "states" / "hiddify.sls").read_text()

    assert "Hiddify.AppImage" in source
    assert "hiddify-official.desktop" in source
    assert "hiddify.desktop" in source
    assert "xdg-mime default hiddify.desktop x-scheme-handler/hiddify" in source


def test_hiddify_state_cleans_legacy_wrappers_and_profile_data():
    source = (REPO_ROOT / "states" / "hiddify.sls").read_text()

    assert "hiddify-launch" in source
    assert "hiddify-root" in source
    assert "hiddify-fix-loopback" in source
    assert ".local/share/app.hiddify.com" in source
