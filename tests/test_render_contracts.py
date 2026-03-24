"""Render-contract tests for critical Salt states."""

import os

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
