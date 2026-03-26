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


def test_hiddify_state_keeps_compatibility_wrappers_and_profile_data():
    source = (REPO_ROOT / "states" / "hiddify.sls").read_text()

    assert "{{ home }}/.local/bin/hiddify-launch" not in source
    assert "{{ home }}/.local/bin/hiddify-fix-loopback" not in source
    assert "{{ home }}/.local/share/app.hiddify.com" not in source


def test_hiddify_wrapper_launches_system_binary_after_loopback_fix():
    source = (
        REPO_ROOT / "dotfiles" / "dot_local" / "bin" / "executable_hiddify-launch"
    ).read_text()

    assert '"$HOME/.local/bin/hiddify-fix-loopback" || true' in source
    assert 'exec hiddify "$@"' in source


def test_hiddify_local_desktop_uses_wrapper_exec():
    source = (
        REPO_ROOT / "dotfiles" / "dot_local" / "share" / "applications" / "hiddify.desktop"
    ).read_text()

    assert "Exec=/home/neg/.local/bin/hiddify-launch %U" in source
    assert "MimeType=x-scheme-handler/hiddify" in source
