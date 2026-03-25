"""Integration checks for the locally built swayimg workflow."""

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


def test_desktop_packages_build_swayimg_from_local_checkout():
    source = (REPO_ROOT / "states" / "desktop" / "packages.sls").read_text()

    assert "swayimg_local_checkout_build" in source
    assert 'src="{{ home }}/src/1st-level/swayimg"' in source
    assert "meson install -C" in source
    assert "/usr/local/bin/swayimg" in source


def test_swayimg_is_not_managed_via_custom_pkgbuild_anymore():
    source = (REPO_ROOT / "states" / "data" / "custom_pkgs.yaml").read_text()

    assert "\n  swayimg:\n" not in source
