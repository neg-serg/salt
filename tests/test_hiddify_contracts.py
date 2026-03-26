"""Contract tests for managed Hiddify automation."""

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def test_system_description_includes_hiddify_state_by_default():
    source = (REPO_ROOT / "states" / "system_description.sls").read_text()

    assert "host.features.network.get('hiddify', True)" in source
    assert "- hiddify" in source


def test_hiddify_state_manages_appimage_and_loopback_fix():
    source = (REPO_ROOT / "states" / "hiddify.sls").read_text()

    assert "Hiddify-Linux-x64.AppImage" in source
    assert "hiddify-fix-loopback" in source
    assert "/opt/hiddify-next" in source
    assert "xdg-mime default hiddify-official.desktop x-scheme-handler/hiddify" in source


def test_hiddify_launchers_call_fixup_script():
    launch = (
        REPO_ROOT / "dotfiles" / "dot_local" / "bin" / "executable_hiddify-launch"
    ).read_text()
    root = (REPO_ROOT / "dotfiles" / "dot_local" / "bin" / "executable_hiddify-root").read_text()
    fix = (
        REPO_ROOT / "dotfiles" / "dot_local" / "bin" / "executable_hiddify-fix-loopback"
    ).read_text()

    assert 'hiddify-fix-loopback" || true' in launch
    assert 'hiddify-fix-loopback" || true' in root
    assert 'select(.listen != "::1")' in fix
    assert "\\[::1\\]:12334" in fix
