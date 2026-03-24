"""Contract tests for service helper guardrails and performance gate wiring."""

import importlib.util
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def _load_state_profiler():
    module_path = REPO_ROOT / "scripts" / "state-profiler.py"
    spec = importlib.util.spec_from_file_location("state_profiler_module", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_services_macro_exposes_config_replace_helper():
    source = (REPO_ROOT / "states" / "_macros_service.jinja").read_text()

    assert "macro config_replace_with_service_control" in source
    assert "service.dead:" in source
    assert "service.running:" in source
    assert "- reload: True" in source


def test_transmission_uses_shared_config_replace_helper():
    source = (REPO_ROOT / "states" / "services.sls").read_text()

    assert "config_replace_with_service_control" in source
    assert "transmission_stop_before_settings_change:" not in source
    assert "transmission_restart_after_settings_change:" not in source


def test_state_profiler_gate_statuses():
    state_profiler = _load_state_profiler()

    assert state_profiler.evaluate_compare_gate([], min_sample_count=1)[0] == "INCONCLUSIVE"
    assert (
        state_profiler.evaluate_compare_gate(
            [{"state_id": "fast", "regression": False}], min_sample_count=1
        )[0]
        == "PASS"
    )
    assert (
        state_profiler.evaluate_compare_gate(
            [{"state_id": "slow", "regression": True}], min_sample_count=1
        )[0]
        == "FAIL"
    )


def test_state_profiler_compare_rows_honor_threshold(tmp_path):
    state_profiler = _load_state_profiler()
    baseline = tmp_path / "baseline.log"
    candidate = tmp_path / "candidate.log"
    baseline.write_text(
        "Name: fast_state - Function: test.nop - Duration: 100 ms\n"
        "Name: slow_state - Function: test.nop - Duration: 100 ms\n"
    )
    candidate.write_text(
        "Name: fast_state - Function: test.nop - Duration: 110 ms\n"
        "Name: slow_state - Function: test.nop - Duration: 140 ms\n"
    )

    rows = state_profiler.build_compare_rows(baseline, candidate, max_regression_pct=20.0)
    by_state = {row["state_id"]: row for row in rows}

    assert by_state["fast_state"]["regression"] is False
    assert by_state["slow_state"]["regression"] is True


def test_ci_workflow_wires_performance_gate_status_handling():
    source = (REPO_ROOT / ".github" / "workflows" / "salt-ci.yaml").read_text()

    assert "Detect performance-gate scope" in source
    assert "python3 scripts/state-profiler.py \\" in source
    assert "--gate \\" in source
    assert 'echo "status=inconclusive"' in source
    assert "Fail on performance regressions" in source
