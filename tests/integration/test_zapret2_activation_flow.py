"""Integration checks for the Zapret2 activation gate."""

from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "zapret2-rollout.sh"


def test_activate_fails_closed_without_approval():
    proc = subprocess.run(
        [str(SCRIPT), "activate"],
        capture_output=True,
        text=True,
    )
    payload = json.loads(proc.stdout)

    assert proc.returncode == 2
    assert payload["allowed"] is False
    assert payload["approval_state"] == "absent"


def test_activate_returns_scoped_summary_when_approved_but_not_live():
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
    assert payload["commands"] == []
