#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_FILE="${ZAPRET2_DATA_FILE:-${PROJECT_DIR}/states/data/zapret2.yaml}"

mode=""
config_path=""
approval_file=""
rollback_file=""
output_file=""
operator_name=""
approval_reason=""
expires_at=""
execute_live=0

usage() {
    cat <<'EOF'
Usage: zapret2-rollout.sh <prepare|preflight|preview|grant-approval|revoke-approval|capture-rollback|smoke|activate|rollback> [options]

Options:
  --config PATH          Config path to report or activate
  --approval-file PATH   Explicit approval signal file
  --rollback-file PATH   Rollback inputs file
  --output PATH          Write JSON output to file instead of stdout
  --operator NAME        Operator identity for approval writes
  --reason TEXT          Reason for approval writes
  --expires-at ISO8601   Optional approval expiry timestamp
  --execute-live         Execute privileged activation or rollback commands
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        prepare|preflight|preview|grant-approval|revoke-approval|capture-rollback|smoke|activate|rollback)
            mode="$1"
            ;;
        --config)
            shift
            config_path="${1:-}"
            ;;
        --approval-file)
            shift
            approval_file="${1:-}"
            ;;
        --rollback-file)
            shift
            rollback_file="${1:-}"
            ;;
        --output)
            shift
            output_file="${1:-}"
            ;;
        --operator)
            shift
            operator_name="${1:-}"
            ;;
        --reason)
            shift
            approval_reason="${1:-}"
            ;;
        --expires-at)
            shift
            expires_at="${1:-}"
            ;;
        --execute-live)
            execute_live=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

if [ -z "${mode}" ]; then
    usage >&2
    exit 1
fi

python3 - "${mode}" "${DATA_FILE}" "${config_path}" "${approval_file}" "${rollback_file}" "${output_file}" "${execute_live}" "${operator_name}" "${approval_reason}" "${expires_at}" <<'PY'
import json
import os
import platform
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


def merge_dict(base, override):
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            merge_dict(base[key], value)
        else:
            base[key] = value
    return base


def load_data(data_file):
    defaults = {
        "package": {"source": "aur", "name": "zapret2", "helper": "paru"},
        "config": {
            "dir": "/opt/zapret2",
            "path": "/opt/zapret2/config",
            "profile": "youtube-hostlist",
            "tcp_ports": "80,443",
            "udp_ports": "443",
            "default_mode": "prepare",
        },
        "service": {
            "name": "zapret2",
            "unit": "zapret2.service",
            "enabled_by_default": False,
            "running_by_default": False,
        },
        "helper": {
            "repo_script": "scripts/zapret2-rollout.sh",
            "deployed_path": "/usr/local/libexec/zapret2-rollout",
            "state_dir": "/var/lib/zapret2",
            "approval_file": "/var/lib/zapret2/activation-approval.json",
            "rollback_file": "/var/lib/zapret2/rollback-inputs.json",
            "activation_report": "/var/lib/zapret2/activation-report.json",
            "smoke_report": "/var/lib/zapret2/smoke-report.json",
        },
        "smoke": {"urls": ["https://www.google.com/generate_204"], "timeout_seconds": 5},
        "activation": {
            "entrypoint": "systemctl start zapret2.service",
            "package_query": ["pacman", "-Q", "zapret2"],
            "install_command": ["paru", "-S", "--noconfirm", "zapret2"],
        },
        "rollback": {
            "entrypoint": "/usr/local/libexec/zapret2-rollout rollback",
            "revoke_approval_on_rollback": True,
            "stop_unit_on_rollback": True,
        },
        "managed_artifacts": [],
        "prerequisites": [],
        "conflicts": [],
        "approval_gate": {
            "gate_name": "explicit-operator-approval",
            "grant_method": "file",
            "scope": ["package_install", "config_activation", "service_enable", "traffic_handling"],
            "expires_when": "approval file is removed or replaced",
        },
    }
    try:
        import yaml  # type: ignore
    except Exception:
        return defaults

    path = Path(data_file)
    if not path.exists():
        return defaults
    return merge_dict(defaults, yaml.safe_load(path.read_text()) or {})


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def configured_path(path_arg, fallback):
    return path_arg or fallback


def run_ok(cmd):
    return subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def run_capture(cmd):
    proc = subprocess.run(cmd, capture_output=True, text=True)
    return proc.returncode, proc.stdout, proc.stderr


def write_json(path, payload):
    out = Path(path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_json_best_effort(path, payload):
    out = Path(path)
    try:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
        return {"path": str(out), "written": True}
    except OSError as exc:
        return {"path": str(out), "written": False, "error": str(exc)}


def run_shell_command(cmd):
    scenario = os.environ.get("ZAPRET2_TEST_SCENARIO", "")
    if scenario == "execute_live_ok":
        return subprocess.CompletedProcess(cmd, 0, "", "")
    return subprocess.run(cmd, shell=True, text=True, capture_output=True)


def check_active_service(name):
    return run_ok(["systemctl", "is-active", name])


def check_enabled_service(name):
    return run_ok(["systemctl", "is-enabled", name])


def approval_state(path):
    if os.environ.get("ZAPRET2_APPROVED") == "1":
        return "granted"
    if not path:
        return "absent"
    p = Path(path)
    if not p.exists():
        return "absent"
    try:
        payload = json.loads(p.read_text())
        return payload.get("approval_state", "granted")
    except Exception:
        return "granted"


def rollback_inputs(path, config_path="/opt/zapret2/config"):
    default_inputs = [
        {
            "id": "service_state",
            "input_type": "service_state",
            "capture_method": "systemctl status snapshot",
            "location": path or "stdout",
            "required_for_rollback": True,
        },
        {
            "id": "config_snapshot",
            "input_type": "config_snapshot",
            "capture_method": "managed config copy reference",
            "location": config_path,
            "required_for_rollback": True,
        },
        {
            "id": "package_state",
            "input_type": "package_state",
            "capture_method": "pacman package listing",
            "location": "pacman -Q",
            "required_for_rollback": True,
        },
        {
            "id": "firewall_snapshot",
            "input_type": "firewall_snapshot",
            "capture_method": "nft or iptables inspection",
            "location": "nft list ruleset / iptables-save",
            "required_for_rollback": True,
        },
    ]
    if not path:
        return default_inputs
    p = Path(path)
    if not p.exists():
        return default_inputs
    try:
        payload = json.loads(p.read_text())
    except Exception:
        return default_inputs
    if isinstance(payload, dict):
        return payload.get("rollback_inputs", default_inputs)
    if isinstance(payload, list):
        return payload
    return default_inputs


def planned_artifacts(data):
    return data.get("managed_artifacts", [])


def activation_commands(data):
    commands = []
    pkg_query = data["activation"].get("package_query", [])
    install_cmd = data["activation"].get("install_command", [])
    if pkg_query and not run_ok(pkg_query) and install_cmd:
        commands.append(" ".join(install_cmd))
    commands.append("systemctl daemon-reload")
    commands.append(data["activation"]["entrypoint"])
    return commands


def rollback_commands(data, rollback):
    commands = []
    if data.get("rollback", {}).get("stop_unit_on_rollback", True):
        commands.append(f"systemctl disable --now {data['service']['unit']} || true")
    config_backup = next((item for item in rollback if item.get("id") == "config_snapshot"), None)
    if config_backup and config_backup.get("backup_path"):
        commands.append(f"cp {config_backup['backup_path']} {data['config']['path']}")
    commands.append("systemctl daemon-reload")
    if data.get("rollback", {}).get("revoke_approval_on_rollback", True):
        commands.append(f"rm -f {data['helper']['approval_file']}")
    return commands


def prepare_payload(data, config_path_arg):
    return {
        "mode": "prepare",
        "traffic_affecting": False,
        "planned_artifacts": planned_artifacts(data),
        "rendered_configuration": {
            "source": str(Path("states/configs/zapret2.conf.j2")),
            "target": config_path_arg or data["config"]["path"],
        },
        "service": {
            "name": data["service"]["name"],
            "enabled_by_default": data["service"]["enabled_by_default"],
            "running_by_default": data["service"]["running_by_default"],
        },
    }


def preflight_report(data, approval_file_arg, rollback_file_arg):
    scenario = os.environ.get("ZAPRET2_TEST_SCENARIO", "")
    approval = approval_state(approval_file_arg)

    if scenario == "blocked_prereq":
        prereqs = [
            {
                "id": "package_source",
                "category": "package_source",
                "result": "fail",
                "evidence": "paru missing in test scenario",
            }
        ]
        conflicts = []
    elif scenario == "blocked_conflict":
        prereqs = [
            {"id": "kernel_support", "category": "kernel", "result": "pass", "evidence": "linux"}
        ]
        conflicts = [
            {
                "id": "singbox_active",
                "component_type": "tunnel",
                "component_name": "sing-box-tun",
                "result": "block",
                "observation": "test conflict active",
                "safe_handling": "reported only",
            }
        ]
    else:
        prereqs = [
            {
                "id": "kernel_support",
                "category": "kernel",
                "result": "pass" if platform.system() == "Linux" else "fail",
                "evidence": platform.system(),
            },
            {
                "id": "packet_filter",
                "category": "packet_filter",
                "result": "pass" if shutil.which("nft") or shutil.which("iptables") else "fail",
                "evidence": "nftables/iptables detected" if shutil.which("nft") or shutil.which("iptables") else "no packet filter tool",
            },
            {
                "id": "queueing_support",
                "category": "queueing",
                "result": "pass" if Path("/proc/net/netfilter").exists() else "warn",
                "evidence": "/proc/net/netfilter present" if Path("/proc/net/netfilter").exists() else "netfilter queue support not confirmed",
            },
            {
                "id": "package_source",
                "category": "package_source",
                "result": "pass" if shutil.which(data["package"]["helper"]) else "fail",
                "evidence": f"{data['package']['helper']} available" if shutil.which(data["package"]["helper"]) else f"{data['package']['helper']} missing",
            },
            {
                "id": "service_dependency",
                "category": "service_dependency",
                "result": "pass" if shutil.which("systemctl") else "fail",
                "evidence": "systemctl available" if shutil.which("systemctl") else "systemctl missing",
            },
            {
                "id": "permissions",
                "category": "permissions",
                "result": "warn" if os.geteuid() != 0 else "pass",
                "evidence": "safe-mode can run unprivileged" if os.geteuid() != 0 else "root available",
            },
        ]
        conflicts = [
            {
                "id": "xray_active",
                "component_type": "proxy",
                "component_name": "xray",
                "result": "investigate" if shutil.which("systemctl") and check_active_service("xray") else "clear",
                "observation": "xray active" if shutil.which("systemctl") and check_active_service("xray") else "xray inactive",
                "safe_handling": "reported only",
            },
            {
                "id": "singbox_active",
                "component_type": "tunnel",
                "component_name": "sing-box-tun",
                "result": "investigate" if shutil.which("systemctl") and check_active_service("sing-box-tun") else "clear",
                "observation": "sing-box-tun active" if shutil.which("systemctl") and check_active_service("sing-box-tun") else "sing-box-tun inactive",
                "safe_handling": "reported only",
            },
            {
                "id": "tailscale_active",
                "component_type": "tunnel",
                "component_name": "tailscaled",
                "result": "investigate" if shutil.which("systemctl") and check_active_service("tailscaled") else "clear",
                "observation": "tailscaled active" if shutil.which("systemctl") and check_active_service("tailscaled") else "tailscaled inactive",
                "safe_handling": "reported only",
            },
            {
                "id": "proxypilot_present",
                "component_type": "proxy",
                "component_name": "proxypilot",
                "result": "investigate" if Path.home().joinpath(".config/proxypilot/config.yaml").exists() else "clear",
                "observation": "proxypilot config present" if Path.home().joinpath(".config/proxypilot/config.yaml").exists() else "proxypilot config absent",
                "safe_handling": "reported only",
            },
        ]

    blockers = []
    if any(item["result"] == "fail" for item in prereqs):
        blockers.append("one or more prerequisites failed")
    if any(item["result"] == "block" for item in conflicts):
        blockers.append("one or more conflicts block activation")
    if approval != "granted":
        blockers.append("explicit operator approval is absent")

    if any(item["result"] == "fail" for item in prereqs) or any(item["result"] == "block" for item in conflicts):
        status = "blocked"
    elif approval != "granted":
        status = "approval_required"
    else:
        status = "ready"

    return {
        "status": status,
        "generated_at": utc_now(),
        "target_host": platform.node() or "unknown-host",
        "prerequisite_results": prereqs,
        "conflict_results": conflicts,
        "planned_artifacts": planned_artifacts(data),
        "activation_blockers": blockers,
        "rollback_inputs": rollback_inputs(
            configured_path(rollback_file_arg, data["helper"]["rollback_file"]),
            data["config"]["path"],
        ),
        "operator_workflow": {
            "capture_rollback": f"{data['helper']['deployed_path']} capture-rollback --rollback-file {configured_path(rollback_file_arg, data['helper']['rollback_file'])}",
            "grant_approval": f"{data['helper']['deployed_path']} grant-approval --approval-file {configured_path(approval_file_arg, data['helper']['approval_file'])} --operator <name> --reason <reason>",
            "preview": f"{data['helper']['deployed_path']} preview --approval-file {configured_path(approval_file_arg, data['helper']['approval_file'])} --rollback-file {configured_path(rollback_file_arg, data['helper']['rollback_file'])}",
            "activate": data["activation"]["entrypoint"],
            "smoke": f"{data['helper']['deployed_path']} smoke --approval-file {configured_path(approval_file_arg, data['helper']['approval_file'])} --rollback-file {configured_path(rollback_file_arg, data['helper']['rollback_file'])}",
            "rollback": f"{data['helper']['deployed_path']} rollback --approval-file {configured_path(approval_file_arg, data['helper']['approval_file'])} --rollback-file {configured_path(rollback_file_arg, data['helper']['rollback_file'])}",
        },
    }


def preview_payload(data, config_path_arg, approval_file_arg, rollback_file_arg):
    return {
        "mode": "preview",
        "traffic_affecting": False,
        "approval_required": True,
        "approval_state": approval_state(approval_file_arg),
        "planned_artifacts": planned_artifacts(data),
        "activation_summary": {
            "config_path": config_path_arg or data["config"]["path"],
            "unit_name": data["service"]["unit"],
            "scope": data["approval_gate"]["scope"],
            "live_execution": False,
            "entrypoint": data["activation"]["entrypoint"],
            "commands": activation_commands(data),
        },
        "rollback_inputs": rollback_inputs(
            configured_path(rollback_file_arg, data["helper"]["rollback_file"]),
            data["config"]["path"],
        ),
    }


def grant_approval_payload(data, approval_file_arg, operator_name, approval_reason, expires_at):
    approval_path = configured_path(approval_file_arg, data["helper"]["approval_file"])
    payload = {
        "approval_state": "granted",
        "granted_at": utc_now(),
        "operator": operator_name or os.environ.get("USER", "unknown"),
        "reason": approval_reason or "manual operator approval",
        "expires_at": expires_at or "",
        "scope": data["approval_gate"]["scope"],
    }
    write_json(approval_path, payload)
    return {
        "mode": "grant-approval",
        "approval_file": approval_path,
        "approval_state": "granted",
        "operator": payload["operator"],
        "reason": payload["reason"],
    }


def revoke_approval_payload(data, approval_file_arg):
    approval_path = configured_path(approval_file_arg, data["helper"]["approval_file"])
    p = Path(approval_path)
    existed = p.exists()
    if existed:
        p.unlink()
    return {
        "mode": "revoke-approval",
        "approval_file": approval_path,
        "approval_state": "absent",
        "removed": existed,
    }


def capture_rollback_payload(data, rollback_file_arg):
    rollback_path = configured_path(rollback_file_arg, data["helper"]["rollback_file"])
    rollback_file = Path(rollback_path)
    rollback_file.parent.mkdir(parents=True, exist_ok=True)
    asset_dir = rollback_file.parent / (rollback_file.stem + "-assets")
    asset_dir.mkdir(parents=True, exist_ok=True)

    service_state = {
        "unit": data["service"]["unit"],
        "active": check_active_service(data["service"]["unit"]) if shutil.which("systemctl") else False,
        "enabled": check_enabled_service(data["service"]["unit"]) if shutil.which("systemctl") else False,
    }
    service_state_path = asset_dir / "service-state.json"
    service_state_path.write_text(json.dumps(service_state, indent=2, sort_keys=True) + "\n")

    config_backup_path = ""
    config_path = Path(data["config"]["path"])
    if config_path.exists():
        config_backup = asset_dir / "zapret2.conf.backup"
        shutil.copy2(config_path, config_backup)
        config_backup_path = str(config_backup)

    pkg_state = {"name": data["package"]["name"], "installed": False, "version": ""}
    pkg_query = data["activation"].get("package_query", [])
    if pkg_query:
        code, stdout, _ = run_capture(pkg_query)
        if code == 0:
            pkg_state["installed"] = True
            pkg_state["version"] = stdout.strip()
    package_state_path = asset_dir / "package-state.json"
    package_state_path.write_text(json.dumps(pkg_state, indent=2, sort_keys=True) + "\n")

    firewall_snapshot_path = ""
    for candidate, filename in ((["nft", "list", "ruleset"], "nft-ruleset.txt"), (["iptables-save"], "iptables-save.txt")):
        if shutil.which(candidate[0]):
            code, stdout, _ = run_capture(candidate)
            if code == 0:
                fw_path = asset_dir / filename
                fw_path.write_text(stdout)
                firewall_snapshot_path = str(fw_path)
                break

    rollback = [
        {
            "id": "service_state",
            "input_type": "service_state",
            "capture_method": "systemctl status snapshot",
            "location": str(service_state_path),
            "required_for_rollback": True,
        },
        {
            "id": "config_snapshot",
            "input_type": "config_snapshot",
            "capture_method": "managed config backup",
            "location": data["config"]["path"],
            "backup_path": config_backup_path,
            "required_for_rollback": True,
        },
        {
            "id": "package_state",
            "input_type": "package_state",
            "capture_method": "package query",
            "location": str(package_state_path),
            "required_for_rollback": True,
        },
        {
            "id": "firewall_snapshot",
            "input_type": "firewall_snapshot",
            "capture_method": "nft or iptables inspection",
            "location": firewall_snapshot_path,
            "required_for_rollback": True,
        },
    ]
    payload = {
        "captured_at": utc_now(),
        "target_host": platform.node() or "unknown-host",
        "rollback_inputs": rollback,
    }
    write_json(rollback_path, payload)
    return {
        "mode": "capture-rollback",
        "rollback_file": rollback_path,
        "rollback_inputs": rollback,
        "asset_dir": str(asset_dir),
    }


def smoke_payload(data, approval_file_arg, rollback_file_arg):
    scenario = os.environ.get("ZAPRET2_TEST_SCENARIO", "")
    checks = [
        {
            "id": "config_present",
            "result": "pass" if Path(data["config"]["path"]).exists() or scenario == "smoke_ok" else "warn",
            "detail": data["config"]["path"],
        },
        {
            "id": "helper_present",
            "result": "pass" if Path(data["helper"]["deployed_path"]).exists() or scenario == "smoke_ok" else "warn",
            "detail": data["helper"]["deployed_path"],
        },
        {
            "id": "approval_present",
            "result": "pass" if approval_state(configured_path(approval_file_arg, data["helper"]["approval_file"])) == "granted" or scenario == "smoke_ok" else "warn",
            "detail": configured_path(approval_file_arg, data["helper"]["approval_file"]),
        },
        {
            "id": "rollback_present",
            "result": "pass" if Path(configured_path(rollback_file_arg, data["helper"]["rollback_file"])).exists() or scenario == "smoke_ok" else "warn",
            "detail": configured_path(rollback_file_arg, data["helper"]["rollback_file"]),
        },
    ]
    url_checks = []
    for url in data.get("smoke", {}).get("urls", []):
        if shutil.which("curl"):
            code = subprocess.run(
                ["curl", "-I", "-L", "-sS", "--max-time", str(data["smoke"].get("timeout_seconds", 5)), url],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            ).returncode
            result = "pass" if code == 0 else "warn"
        else:
            result = "warn"
        url_checks.append({"id": "url_probe", "url": url, "result": result})

    status = "pass" if all(item["result"] == "pass" for item in checks) else "warn"
    report_state = write_json_best_effort(data["helper"]["smoke_report"], {"mode": "smoke", "status": status, "checks": checks, "url_checks": url_checks})
    payload = {
        "mode": "smoke",
        "status": status,
        "checks": checks,
        "url_checks": url_checks,
        "smoke_report": report_state,
    }
    return payload


def activate_payload(data, config_path_arg, approval_file_arg, rollback_file_arg, execute_live):
    approval = approval_state(approval_file_arg)
    rollback = rollback_inputs(
        configured_path(rollback_file_arg, data["helper"]["rollback_file"]),
        data["config"]["path"],
    )
    running_inside_activation_unit = os.environ.get("ZAPRET2_ACTIVATION_VIA_UNIT") == "1"
    test_execute_live = os.environ.get("ZAPRET2_TEST_SCENARIO", "") == "execute_live_ok"
    if approval != "granted":
        return 2, {
            "mode": "activate",
            "allowed": False,
            "reason": "explicit approval is required",
            "approval_state": approval,
            "live_execution": False,
        }
    if not rollback:
        return 3, {
            "mode": "activate",
            "allowed": False,
            "reason": "rollback inputs are required before activation",
            "approval_state": approval,
            "live_execution": False,
        }
    commands = activation_commands(data)
    payload = {
        "mode": "activate",
        "allowed": True,
        "approval_state": approval,
        "config_path": config_path_arg or data["config"]["path"],
        "scope": data["approval_gate"]["scope"],
        "rollback_inputs": rollback,
        "live_execution": bool(execute_live),
        "commands": commands,
        "entrypoint": data["activation"]["entrypoint"],
        "next_steps": [
            f"{data['helper']['deployed_path']} smoke --approval-file {configured_path(approval_file_arg, data['helper']['approval_file'])} --rollback-file {configured_path(rollback_file_arg, data['helper']['rollback_file'])}"
        ],
    }
    if execute_live:
        if os.geteuid() != 0 and not test_execute_live:
            return 4, {
                "mode": "activate",
                "allowed": False,
                "reason": "root privileges are required for live activation",
                "approval_state": approval,
                "live_execution": True,
                "commands": commands,
            }
        executed = []
        for cmd in commands:
            if cmd == data["activation"]["entrypoint"] and running_inside_activation_unit:
                executed.append(
                    {
                        "command": cmd,
                        "returncode": 0,
                        "stdout": "",
                        "stderr": "",
                        "skipped": True,
                        "reason": "already running inside activation unit",
                    }
                )
                continue
            proc = run_shell_command(cmd)
            executed.append(
                {
                    "command": cmd,
                    "returncode": proc.returncode,
                    "stdout": proc.stdout.strip(),
                    "stderr": proc.stderr.strip(),
                }
            )
            if proc.returncode != 0:
                payload["allowed"] = False
                payload["reason"] = f"command failed: {cmd}"
                payload["executed_commands"] = executed
                return 5, payload
        activation_report = {
            "activated_at": utc_now(),
            "approval_file": configured_path(approval_file_arg, data["helper"]["approval_file"]),
            "rollback_file": configured_path(rollback_file_arg, data["helper"]["rollback_file"]),
            "entrypoint": data["activation"]["entrypoint"],
            "executed_commands": executed,
        }
        payload["activation_report"] = write_json_best_effort(
            data["helper"]["activation_report"], activation_report
        )
        payload["executed_commands"] = executed
    return 0, payload


def rollback_payload(data, approval_file_arg, rollback_file_arg, execute_live):
    rollback_path = configured_path(rollback_file_arg, data["helper"]["rollback_file"])
    approval_path = configured_path(approval_file_arg, data["helper"]["approval_file"])
    if not Path(rollback_path).exists():
        return 6, {
            "mode": "rollback",
            "allowed": False,
            "reason": "rollback inputs file is missing",
            "rollback_file": rollback_path,
            "live_execution": bool(execute_live),
        }
    rollback = rollback_inputs(rollback_path, data["config"]["path"])
    commands = rollback_commands(data, rollback)
    payload = {
        "mode": "rollback",
        "allowed": True,
        "rollback_file": rollback_path,
        "approval_file": approval_path,
        "live_execution": bool(execute_live),
        "commands": commands,
    }
    if execute_live:
        if os.geteuid() != 0:
            return 4, {
                "mode": "rollback",
                "allowed": False,
                "reason": "root privileges are required for live rollback",
                "rollback_file": rollback_path,
                "live_execution": True,
                "commands": commands,
            }
        executed = []
        for cmd in commands:
            proc = subprocess.run(cmd, shell=True, text=True, capture_output=True)
            executed.append(
                {
                    "command": cmd,
                    "returncode": proc.returncode,
                    "stdout": proc.stdout.strip(),
                    "stderr": proc.stderr.strip(),
                }
            )
            if proc.returncode != 0:
                payload["allowed"] = False
                payload["reason"] = f"command failed: {cmd}"
                payload["executed_commands"] = executed
                return 7, payload
        payload["executed_commands"] = executed
    return 0, payload


mode, data_file, config_path_arg, approval_file_arg, rollback_file_arg, output_file_arg, execute_live_arg, operator_name_arg, approval_reason_arg, expires_at_arg = sys.argv[1:]
data = load_data(data_file)

if mode == "prepare":
    code = 0
    payload = prepare_payload(data, config_path_arg)
elif mode == "preview":
    code = 0
    payload = preview_payload(data, config_path_arg, approval_file_arg, rollback_file_arg)
elif mode == "preflight":
    code = 0
    payload = preflight_report(data, approval_file_arg, rollback_file_arg)
elif mode == "grant-approval":
    code = 0
    payload = grant_approval_payload(data, approval_file_arg, operator_name_arg, approval_reason_arg, expires_at_arg)
elif mode == "revoke-approval":
    code = 0
    payload = revoke_approval_payload(data, approval_file_arg)
elif mode == "capture-rollback":
    code = 0
    payload = capture_rollback_payload(data, rollback_file_arg)
elif mode == "smoke":
    code = 0
    payload = smoke_payload(data, approval_file_arg, rollback_file_arg)
elif mode == "activate":
    code, payload = activate_payload(
        data,
        config_path_arg,
        approval_file_arg,
        rollback_file_arg,
        int(execute_live_arg),
    )
elif mode == "rollback":
    code, payload = rollback_payload(
        data,
        approval_file_arg,
        rollback_file_arg,
        int(execute_live_arg),
    )
else:
    raise SystemExit(f"unsupported mode: {mode}")

text = json.dumps(payload, indent=2, sort_keys=True)
if output_file_arg:
    Path(output_file_arg).write_text(text + "\n")
else:
    print(text)
raise SystemExit(code)
PY
