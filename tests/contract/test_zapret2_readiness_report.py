"""Contract checks for the Zapret2 readiness report."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "zapret2-rollout.sh"
CONTRACT = REPO_ROOT / "specs" / "073-zapret2-dry-run" / "contracts" / "readiness-report.yaml"


def run_rollout(mode: str, scenario: str | None = None) -> dict:
    env = os.environ.copy()
    if scenario:
        env["ZAPRET2_TEST_SCENARIO"] = scenario
    proc = subprocess.run(
        [str(SCRIPT), mode],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )
    return json.loads(proc.stdout)


def run_rollout_isolated(mode: str, scenario: str) -> dict:
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        data_file = tmp / "zapret2.yaml"
        data = yaml.safe_load((REPO_ROOT / "states" / "data" / "zapret2.yaml").read_text())
        data["helper"]["approval_file"] = str(tmp / "approval.json")
        data["helper"]["rollback_file"] = str(tmp / "rollback.json")
        data_file.write_text(yaml.safe_dump(data))
        env = os.environ.copy()
        env["ZAPRET2_TEST_SCENARIO"] = scenario
        env["ZAPRET2_DATA_FILE"] = str(data_file)
        proc = subprocess.run(
            [str(SCRIPT), mode],
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )
        return json.loads(proc.stdout)


def test_readiness_report_matches_required_contract_fields():
    contract = yaml.safe_load(CONTRACT.read_text())
    report = run_rollout_isolated("preflight", "approval_required")

    for field in contract["required_fields"]:
        assert field in report, f"missing required field: {field}"
    assert report["status"] in contract["status_values"]


def test_readiness_report_blocked_when_prerequisite_fails():
    report = run_rollout_isolated("preflight", "blocked_prereq")

    assert report["status"] == "blocked"
    assert any(item["result"] == "fail" for item in report["prerequisite_results"])
    assert report["activation_blockers"]


def test_readiness_report_approval_required_without_explicit_approval():
    report = run_rollout_isolated("preflight", "approval_required")

    assert report["status"] == "approval_required"
    assert all(item["result"] != "fail" for item in report["prerequisite_results"])
    assert "explicit operator approval is absent" in report["activation_blockers"]


def test_readiness_report_includes_operator_workflow_commands():
    report = run_rollout_isolated("preflight", "approval_required")

    assert "operator_workflow" in report
    assert report["operator_workflow"]["capture_rollback"]
    assert report["operator_workflow"]["activate"] == "systemctl start zapret2.service"
