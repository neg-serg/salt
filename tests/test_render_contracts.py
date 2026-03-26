"""Render-contract tests for critical Salt states."""

import os

import yaml

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def test_openclaw_runtime_dir_uses_host_model():
    path = os.path.join(REPO_ROOT, "states", "openclaw_agent.sls")
    with open(path) as fh:
        source = fh.read()

    assert "Environment=XDG_RUNTIME_DIR=/run/user/1000" not in source
    assert "Environment=XDG_RUNTIME_DIR={{ host.runtime_dir }}" in source


def test_salt_monitor_unit_is_templated_for_runtime_dir():
    state_path = os.path.join(REPO_ROOT, "states", "monitoring_alerts.sls")
    with open(state_path) as fh:
        state_source = fh.read()
    unit_path = os.path.join(REPO_ROOT, "states", "units", "user", "salt-monitor.service")
    with open(unit_path) as fh:
        unit_source = fh.read()

    assert "template='jinja'" in state_source
    assert "runtime_dir': host.runtime_dir" in state_source
    assert "Environment=XDG_RUNTIME_DIR={{ runtime_dir }}" in unit_source


def test_salt_daemon_unit_is_templated_for_user_runtime_dir():
    state_path = os.path.join(REPO_ROOT, "states", "desktop", "user.sls")
    with open(state_path) as fh:
        state_source = fh.read()
    unit_path = os.path.join(REPO_ROOT, "states", "units", "salt-daemon.service.j2")
    with open(unit_path) as fh:
        unit_source = fh.read()

    assert "runtime_dir': host.runtime_dir" in state_source
    assert "Environment=XDG_RUNTIME_DIR={{ runtime_dir }}" in unit_source
    assert "Environment=DBUS_SESSION_BUS_ADDRESS=unix:path={{ runtime_dir }}/bus" in unit_source


def test_user_services_source_has_no_parallel_feature_lists():
    path = os.path.join(REPO_ROOT, "states", "user_services.sls")
    with open(path) as fh:
        source = fh.read()

    assert "mail_unit_ids" not in source
    assert "vdirsyncer_unit_ids" not in source
    assert "mail_enable" not in source
    assert "vdirsyncer_timers" not in source


def test_video_ai_uses_shared_huggingface_macro():
    root_path = os.path.join(REPO_ROOT, "states", "video_ai.sls")
    with open(root_path) as fh:
        root_source = fh.read()
    models_path = os.path.join(REPO_ROOT, "states", "video_ai", "models.sls")
    with open(models_path) as fh:
        models_source = fh.read()

    assert "- video_ai.models" in root_source
    assert "huggingface_file(" in models_source
    assert "curl -fsSL -C -" not in models_source


def test_system_description_includes_shared_systemd_resources_state():
    path = os.path.join(REPO_ROOT, "states", "system_description.sls")
    with open(path) as fh:
        source = fh.read()

    assert "- systemd_resources" in source


def test_system_description_includes_os_release_state():
    path = os.path.join(REPO_ROOT, "states", "system_description.sls")
    with open(path) as fh:
        source = fh.read()

    assert "- os_release" in source


def test_hyprlock_uses_fancy_name_fallback_for_os_release():
    paths = [
        os.path.join(REPO_ROOT, "dotfiles", "dot_config", "hypr", "hyprlock", "greetd.conf"),
        os.path.join(
            REPO_ROOT,
            "dotfiles",
            "dot_config",
            "hypr",
            "hyprlock",
            "greetd-wallbash.conf",
        ),
    ]

    for path in paths:
        with open(path) as fh:
            source = fh.read()

        assert ". /etc/os-release" in source
        assert "FANCY_NAME:-${PRETTY_NAME:-$NAME}" in source


def test_managed_resources_inventory_covers_phase1_services():
    path = os.path.join(REPO_ROOT, "states", "data", "managed_resources.yaml")
    with open(path) as fh:
        data = yaml.safe_load(fh)

    identities = data["managed_service_identities"]
    paths = data["managed_service_paths"]

    assert {"loki", "adguardhome", "bitcoind", "greetd"} <= set(identities)
    assert {
        "loki_root",
        "adguardhome_root",
        "bitcoind_root",
        "greetd_root",
        "mpd_fifo",
    } <= set(paths)
    assert paths["mpd_fifo"]["user"] == "__CURRENT_USER__"


def test_service_states_use_shared_managed_resource_ensures():
    state_paths = [
        os.path.join(REPO_ROOT, "states", "monitoring_loki.sls"),
        os.path.join(REPO_ROOT, "states", "dns.sls"),
        os.path.join(REPO_ROOT, "states", "services.sls"),
        os.path.join(REPO_ROOT, "states", "mpd.sls"),
    ]

    combined = []
    for path in state_paths:
        with open(path) as fh:
            combined.append(fh.read())
    source = "\n".join(combined)

    assert "cmd: managed_service_accounts_ensure" in source
    assert "cmd: managed_service_paths_ensure" in source
    assert "system_daemon_user(" not in source
    assert "/etc/tmpfiles.d/mpd-fifo.conf" not in source


def test_greetd_state_depends_on_shared_managed_resources():
    path = os.path.join(REPO_ROOT, "states", "greetd.sls")
    with open(path) as fh:
        source = fh.read()

    assert "- systemd_resources" in source
    assert "cmd: managed_service_accounts_ensure" in source
    assert "cmd: managed_service_paths_ensure" in source


def test_quickshell_services_qmldir_registers_widget_registry():
    path = os.path.join(REPO_ROOT, "dotfiles", "dot_config", "quickshell", "Services", "qmldir")
    with open(path) as fh:
        source = fh.read()

    assert "singleton WidgetRegistry 1.0 WidgetRegistry.qml" in source


def test_systemd_resource_templates_reference_shared_macros():
    accounts_path = os.path.join(REPO_ROOT, "states", "configs", "managed-service-accounts.conf.j2")
    with open(accounts_path) as fh:
        accounts_source = fh.read()

    paths_path = os.path.join(REPO_ROOT, "states", "configs", "managed-service-paths.conf.j2")
    with open(paths_path) as fh:
        paths_source = fh.read()

    assert "managed_sysusers_line" in accounts_source
    assert "managed_tmpfiles_line" in paths_source
