"""Integration checks for the Zapret2 preflight workflow."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "zapret2-rollout.sh"


def run_preflight(scenario: str) -> dict:
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        data_file = tmp / "zapret2.yaml"
        data = yaml.safe_load((REPO_ROOT / "states" / "data" / "zapret2.yaml").read_text())
        data["helper"]["approval_file"] = str(tmp / "approval.json")
        data_file.write_text(yaml.safe_dump(data))
        env = os.environ.copy()
        env["ZAPRET2_TEST_SCENARIO"] = scenario
        env["ZAPRET2_DATA_FILE"] = str(data_file)
        proc = subprocess.run(
            [str(SCRIPT), "preflight"],
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )
        return json.loads(proc.stdout)


def test_preflight_reports_blocking_conflict_without_modifying_state():
    payload = run_preflight("blocked_conflict")

    assert payload["status"] == "blocked"
    assert any(item["result"] == "block" for item in payload["conflict_results"])
    assert payload["planned_artifacts"]


def test_preflight_reports_approval_required_when_prereqs_pass():
    payload = run_preflight("approval_required")

    assert payload["status"] == "approval_required"
    assert "explicit operator approval is absent" in payload["activation_blockers"]
