"""Integration checks for the Zapret2 Salt-managed surface."""

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


def test_system_description_feature_gates_zapret2():
    source = (REPO_ROOT / "states" / "system_description.sls").read_text()

    assert "host.features.network.get('zapret2', false)" in source
    assert "- zapret2" in source


def test_zapret2_state_manages_package_config_unit_and_helper():
    source = (REPO_ROOT / "states" / "zapret2.sls").read_text()

    assert "zapret2_install_pkg:" in source
    assert "zapret2_install_ipset:" in source
    assert "pacman -S --noconfirm --needed ipset" in source
    assert "zapret2_refresh_lists:" in source
    assert "zapret2-list-update.timer" in source
    assert "salt://configs/zapret2.conf.j2" in source
    assert "salt://configs/zapret2-hosts-user.txt.j2" in source
    assert "salt://units/zapret2.service.j2" in source
    assert "salt://scripts/zapret2-rollout.sh" in source


def test_zapret2_unit_is_enabled_by_default():
    source = (REPO_ROOT / "states" / "zapret2.sls").read_text()

    assert "enabled=True" in source


def test_zapret2_unit_uses_upstream_service_entrypoints():
    source = (REPO_ROOT / "states" / "units" / "zapret2.service.j2").read_text()

    assert "Type=forking" in source
    assert "ExecStart=/opt/zapret2/init.d/sysv/zapret2 start" in source
    assert "ExecStop=/opt/zapret2/init.d/sysv/zapret2 stop" in source


def test_zapret2_config_template_contains_kyber_quic_profiles():
    source = (REPO_ROOT / "states" / "configs" / "zapret2.conf.j2").read_text()

    # Template uses Jinja2 loop variable {{ blob }} — blob paths live in zapret2.yaml
    assert "for blob in quic_kyber_blobs" in source
    assert "hostlist-domains=googlevideo.com" in source
    assert "{{ blob }}" in source


def test_zapret2_config_template_contains_google_tls_profile():
    source = (REPO_ROOT / "states" / "configs" / "zapret2.conf.j2").read_text()

    # Template uses Jinja2 variable {{ tls_google_blob }} — path lives in zapret2.yaml
    assert "{{ tls_google_blob }}" in source
    assert "hostlist-domains=youtube.com,googlevideo.com" in source


def test_zapret2_data_model_contains_kyber_blobs_and_new_domains():
    import yaml

    data = yaml.safe_load((REPO_ROOT / "states" / "data" / "zapret2.yaml").read_text())

    assert "quic_kyber_blobs" in data["config"]
    assert len(data["config"]["quic_kyber_blobs"]) == 2
    assert "tls_google_blob" in data["config"]
    assert "yt3.ggpht.com" in data["hostlist"]["domains"]
    assert "lh3.googleusercontent.com" in data["hostlist"]["domains"]


def test_zapret2_sls_passes_kyber_context_to_config():
    source = (REPO_ROOT / "states" / "zapret2.sls").read_text()

    assert "quic_kyber_blobs" in source
    assert "tls_google_blob" in source
