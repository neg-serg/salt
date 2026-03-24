"""Contract checks for the Zapret2 activation gate."""

from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "zapret2-rollout.sh"
CONTRACT = REPO_ROOT / "specs" / "073-zapret2-dry-run" / "contracts" / "operator-workflow.yaml"


def test_activation_requires_explicit_approval():
    proc = subprocess.run(
        [str(SCRIPT), "activate"],
        capture_output=True,
        text=True,
    )
    payload = json.loads(proc.stdout)

    assert proc.returncode != 0
    assert payload["allowed"] is False
    assert payload["reason"] == "explicit approval is required"


def test_activation_scope_matches_workflow_contract():
    contract = yaml.safe_load(CONTRACT.read_text())
    activation_stage = next(
        stage for stage in contract["workflow"]["stages"] if stage["name"] == "activate"
    )

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        approval_file = tmp / "approval.json"
        rollback_file = tmp / "rollback.json"
        approval_file.write_text(json.dumps({"approval_state": "granted"}))
        rollback_file.write_text(
            json.dumps({"rollback_inputs": [{"id": "baseline", "required_for_rollback": True}]})
        )
        proc = subprocess.run(
            [
                str(SCRIPT),
                "activate",
                "--approval-file",
                str(approval_file),
                "--rollback-file",
                str(rollback_file),
            ],
            check=True,
            capture_output=True,
            text=True,
        )

    payload = json.loads(proc.stdout)

    assert payload["allowed"] is True
    assert payload["live_execution"] is False
    assert activation_stage["requires_approval"] is True
    assert set(payload["scope"]) == {
        "package_install",
        "config_activation",
        "service_enable",
        "traffic_handling",
    }
