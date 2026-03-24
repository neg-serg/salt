"""Integration checks for the Zapret2 preflight workflow."""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "zapret2-rollout.sh"


def run_preflight(scenario: str) -> dict:
    env = os.environ.copy()
    env["ZAPRET2_TEST_SCENARIO"] = scenario
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
    assert payload["rollback_inputs"]
    assert "explicit operator approval is absent" in payload["activation_blockers"]
