# bench_services.py — pyinfra PoC: systemd service management
#
# Part of 030-pyinfra-migration-research. NOT production code.
# Demonstrates pyinfra equivalent of Salt's service.running + service.enabled.
#
# Run: .venv/bin/pyinfra @local bench_services.py
#
# ---- Equivalent Salt YAML ----
# # Using the simple_service macro (pkg install + enable):
# {% from '_macros_pkg.jinja' import simple_service %}
# {{ simple_service('openssh', ['openssh'], 'sshd') }}
#
# # Which expands roughly to:
# install_openssh:
#   cmd.run:
#     - name: pacman -S --noconfirm --needed openssh
#     - unless: pacman -Qi openssh
#
# openssh_enabled:
#   service.enabled:
#     - name: sshd
#     - require:
#       - cmd: install_openssh
#
# # Or using ensure_running macro for already-installed services:
# {% from '_macros_service.jinja' import ensure_running %}
# {{ ensure_running('sshd', 'sshd') }}
#
# # Which expands to:
# sshd_reset:
#   cmd.run:
#     - name: systemctl reset-failed sshd || true
#
# sshd_running:
#   service.running:
#     - name: sshd
#     - enable: True
#     - require:
#       - cmd: sshd_reset
#
# # NetworkManager — same pattern:
# {{ ensure_running('networkmanager', 'NetworkManager') }}
#
# networkmanager_reset:
#   cmd.run:
#     - name: systemctl reset-failed NetworkManager || true
#
# networkmanager_running:
#   service.running:
#     - name: NetworkManager
#     - enable: True
#     - require:
#       - cmd: networkmanager_reset
# ----------------------------------

from pyinfra.operations import server, systemd

SERVICES = [
    {
        "name": "sshd",
        "description": "OpenSSH daemon",
    },
    {
        "name": "NetworkManager",
        "description": "Network management daemon",
    },
]

for svc in SERVICES:
    svc_name = svc["name"]

    # Reset failed state first (equivalent to Salt's ensure_running reset step).
    # This clears transient failures so systemd will attempt a restart.
    server.shell(
        name=f"Reset failed state for {svc_name}",
        commands=[f"systemctl reset-failed {svc_name} || true"],
    )

    # Ensure the service is running and enabled at boot.
    # Combines Salt's service.running + service.enabled into one call.
    #
    # systemd.service is pyinfra's native operation for systemd units.
    # - running=True  -> equivalent to Salt's service.running
    # - enabled=True  -> equivalent to Salt's service.enabled (enable at boot)
    systemd.service(
        name=f"Ensure {svc_name} is running and enabled",
        service=svc_name,
        running=True,
        enabled=True,
    )
