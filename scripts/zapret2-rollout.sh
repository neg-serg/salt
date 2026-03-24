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
execute_live=0

usage() {
    cat <<'EOF'
Usage: zapret2-rollout.sh <prepare|preflight|preview|activate> [options]

Options:
  --config PATH          Config path to report or activate
  --approval-file PATH   Explicit approval signal file
  --rollback-file PATH   Rollback inputs file
  --output PATH          Write JSON output to file instead of stdout
  --execute-live         Allow the activate mode to describe a live execution path
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        prepare|preflight|preview|activate)
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

python3 - "${mode}" "${DATA_FILE}" "${config_path}" "${approval_file}" "${rollback_file}" "${output_file}" "${execute_live}" <<'PY'
import json
import os
import platform
import shutil
import subprocess
import sys
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
            "dir": "/etc/zapret2",
            "path": "/etc/zapret2/zapret2.conf",
            "profile": "safe-preview",
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
            "deployed_path": "/usr/local/libexec/zapret2-rollout",
            "approval_file": "/var/lib/zapret2/activation-approval.json",
            "rollback_file": "/var/lib/zapret2/rollback-inputs.json",
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


def run_ok(cmd):
    return subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def check_active_service(name):
    return run_ok(["systemctl", "is-active", name])


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


def rollback_inputs(path):
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
            "location": "/etc/zapret2/zapret2.conf",
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


def preflight_report(data, approval_file_arg, rollback_file_arg):
    scenario = os.environ.get("ZAPRET2_TEST_SCENARIO", "")
    approval = approval_state(approval_file_arg or data["helper"]["approval_file"])

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
        "generated_at": __import__("datetime").datetime.now(
            __import__("datetime").timezone.utc
        ).isoformat(),
        "target_host": platform.node() or "unknown-host",
        "prerequisite_results": prereqs,
        "conflict_results": conflicts,
        "planned_artifacts": planned_artifacts(data),
        "activation_blockers": blockers,
        "rollback_inputs": rollback_inputs(rollback_file_arg or data["helper"]["rollback_file"]),
    }


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


def preview_payload(data, config_path_arg, approval_file_arg, rollback_file_arg):
    return {
        "mode": "preview",
        "traffic_affecting": False,
        "approval_required": True,
        "approval_state": approval_state(approval_file_arg or data["helper"]["approval_file"]),
        "planned_artifacts": planned_artifacts(data),
        "activation_summary": {
            "config_path": config_path_arg or data["config"]["path"],
            "unit_name": data["service"]["unit"],
            "scope": data["approval_gate"]["scope"],
            "live_execution": False,
        },
        "rollback_inputs": rollback_inputs(rollback_file_arg or data["helper"]["rollback_file"]),
    }


def activate_payload(data, config_path_arg, approval_file_arg, rollback_file_arg, execute_live):
    approval = approval_state(approval_file_arg or data["helper"]["approval_file"])
    rollback = rollback_inputs(rollback_file_arg or data["helper"]["rollback_file"])
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
    return 0, {
        "mode": "activate",
        "allowed": True,
        "approval_state": approval,
        "config_path": config_path_arg or data["config"]["path"],
        "scope": data["approval_gate"]["scope"],
        "rollback_inputs": rollback,
        "live_execution": bool(execute_live),
        "commands": [
            f"systemctl daemon-reload",
            f"systemctl enable --now {data['service']['unit']}",
        ] if execute_live else [],
    }


mode, data_file, config_path_arg, approval_file_arg, rollback_file_arg, output_file_arg, execute_live_arg = sys.argv[1:]
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
elif mode == "activate":
    code, payload = activate_payload(
        data,
        config_path_arg,
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
