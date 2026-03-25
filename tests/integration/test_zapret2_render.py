"""Integration checks for the Zapret2 Salt-managed surface."""

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


def test_system_description_feature_gates_zapret2():
    source = (REPO_ROOT / "states" / "system_description.sls").read_text()

    assert "host.features.network.get('zapret2', false)" in source
    assert "- zapret2" in source


def test_zapret2_state_manages_package_config_unit_and_helper():
    source = (REPO_ROOT / "states" / "zapret2.sls").read_text()

    assert "paru_install('zapret2'" in source
    assert "salt://configs/zapret2.conf.j2" in source
    assert "salt://units/zapret2.service.j2" in source
    assert "salt://scripts/zapret2-rollout.sh" in source


def test_zapret2_unit_is_disabled_by_default():
    source = (REPO_ROOT / "states" / "zapret2.sls").read_text()

    assert "enabled=False" in source


def test_zapret2_unit_marks_activation_context_and_state_dir_write_access():
    source = (REPO_ROOT / "states" / "units" / "zapret2.service.j2").read_text()

    assert "Environment=ZAPRET2_ACTIVATION_VIA_UNIT=1" in source
    assert "ReadWritePaths=/var/lib/zapret2" in source
