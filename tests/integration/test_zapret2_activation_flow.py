"""Integration checks for the Zapret2 activation gate."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "zapret2-rollout.sh"


def test_activate_fails_closed_without_approval():
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        data_file = tmp / "zapret2.yaml"
        data = yaml.safe_load((REPO_ROOT / "states" / "data" / "zapret2.yaml").read_text())
        data["helper"]["approval_file"] = str(tmp / "approval.json")
        data_file.write_text(yaml.safe_dump(data))
        env = dict(os.environ)
        env["ZAPRET2_DATA_FILE"] = str(data_file)
        proc = subprocess.run(
            [
                str(SCRIPT),
                "activate",
            ],
            capture_output=True,
            text=True,
            env=env,
        )
        payload = json.loads(proc.stdout)

    assert proc.returncode == 2
    assert payload["allowed"] is False
    assert payload["approval_state"] == "absent"


def test_activate_returns_scoped_summary_when_approved_but_not_live():
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        approval_file = tmp / "approval.json"
        approval_file.write_text(json.dumps({"approval_state": "granted"}))
        proc = subprocess.run(
            [
                str(SCRIPT),
                "activate",
                "--approval-file",
                str(approval_file),
            ],
            check=True,
            capture_output=True,
            text=True,
        )

    payload = json.loads(proc.stdout)

    assert payload["allowed"] is True
    assert payload["live_execution"] is False
    assert payload["entrypoint"] == "systemctl start zapret2.service"
    assert "systemctl daemon-reload" in payload["commands"]


def test_activate_execute_live_runs_entrypoint_outside_activation_unit():
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        approval_file = tmp / "approval.json"
        data_file = tmp / "zapret2.yaml"
        activation_report = tmp / "activation-report.json"
        approval_file.write_text(json.dumps({"approval_state": "granted"}))
        data_file.write_text(
            yaml.safe_dump(
                {
                    "helper": {"activation_report": str(activation_report)},
                    "activation": {"entrypoint": "systemctl start zapret2.service"},
                }
            )
        )
        env = dict(os.environ)
        env["ZAPRET2_DATA_FILE"] = str(data_file)
        env["ZAPRET2_TEST_SCENARIO"] = "execute_live_ok"
        proc = subprocess.run(
            [
                str(SCRIPT),
                "activate",
                "--approval-file",
                str(approval_file),
                "--execute-live",
            ],
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )

    payload = json.loads(proc.stdout)

    assert payload["allowed"] is True
    assert payload["live_execution"] is True
    assert payload["activation_report"]["written"] is True
    commands = [item["command"] for item in payload["executed_commands"]]
    assert "systemctl daemon-reload" in commands
    assert "systemctl start zapret2.service" in commands


def test_default_operator_flow_uses_user_state_dir_without_root():
    with tempfile.TemporaryDirectory() as tmpdir:
        env = dict(os.environ)
        env["XDG_STATE_HOME"] = tmpdir

        approval = subprocess.run(
            [
                str(SCRIPT),
                "grant-approval",
                "--operator",
                "test",
                "--reason",
                "test",
            ],
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )
        activate = subprocess.run(
            [str(SCRIPT), "activate"],
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )

        approval_payload = json.loads(approval.stdout)
        activate_payload = json.loads(activate.stdout)

        state_dir = Path(tmpdir) / "zapret2"
        assert (state_dir / "activation-approval.json").exists()
        assert approval_payload["approval_state"] == "granted"
        assert activate_payload["allowed"] is True
        assert activate_payload["approval_state"] == "granted"
        assert activate_payload["live_execution"] is False


def test_smoke_reports_status_and_checks():
    env = dict(os.environ)
    env["ZAPRET2_TEST_SCENARIO"] = "smoke_ok"
    proc = subprocess.run(
        [str(SCRIPT), "smoke"],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )
    payload = json.loads(proc.stdout)

    assert payload["mode"] == "smoke"
    assert payload["status"] in {"pass", "warn"}
    assert payload["checks"]
