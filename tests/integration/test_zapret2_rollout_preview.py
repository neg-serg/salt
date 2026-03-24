"""Integration checks for Zapret2 prepare/preview workflows."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "zapret2-rollout.sh"


def test_prepare_reports_non_destructive_managed_surface():
    proc = subprocess.run(
        [str(SCRIPT), "prepare"],
        check=True,
        capture_output=True,
        text=True,
    )
    payload = json.loads(proc.stdout)

    assert payload["mode"] == "prepare"
    assert payload["traffic_affecting"] is False
    assert payload["planned_artifacts"]


def test_preview_reports_activation_scope_without_live_execution():
    proc = subprocess.run(
        [str(SCRIPT), "preview"],
        check=True,
        capture_output=True,
        text=True,
    )
    payload = json.loads(proc.stdout)

    assert payload["mode"] == "preview"
    assert payload["traffic_affecting"] is False
    assert payload["activation_summary"]["live_execution"] is False
    assert payload["planned_artifacts"]
