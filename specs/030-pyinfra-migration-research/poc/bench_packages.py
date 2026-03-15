# bench_packages.py — pyinfra PoC: package installation with idempotency guards
#
# Part of 030-pyinfra-migration-research. NOT production code.
# Demonstrates pyinfra equivalent of Salt's pacman_install macro with
# unless guards and retry logic.
#
# Run: .venv/bin/pyinfra @local bench_packages.py
#
# ---- Equivalent Salt YAML ----
# {% from '_macros_pkg.jinja' import pacman_install %}
# {{ pacman_install('bench_tools', ['ripgrep', 'fd', 'bat'],
#                   check='rg') }}
#
# Which expands roughly to:
#
# install_bench_tools:
#   cmd.run:
#     - name: pacman -S --noconfirm --needed ripgrep fd bat
#     - unless: pacman -Qi ripgrep && pacman -Qi fd && pacman -Qi bat
#     - retry:
#         attempts: 3
#         interval: 10
# ----------------------------------

from pyinfra.operations import pacman

# Packages to install (all should already be present on this workstation).
PACKAGES = ["ripgrep", "fd", "bat"]

for pkg in PACKAGES:
    # pacman.packages is the native pyinfra operation for Arch Linux.
    #
    # _if:  equivalent to Salt's `unless` — skip if already installed.
    #       The shell command returns 0 when the package is present,
    #       so the operation is skipped (pyinfra _if runs the check and
    #       proceeds only when it returns 0; we want to SKIP when installed,
    #       so we invert: _if returns 0 only when NOT installed).
    #
    # _retries / _retry_delay: equivalent to Salt's retry.attempts / retry.interval.
    pacman.packages(
        name=f"Install {pkg}",
        packages=[pkg],
        present=True,
        # Guard: only run if pacman -Qi fails (package not installed).
        # pacman -Qi returns 1 when package is absent.
        _if="! pacman -Qi {pkg}".format(pkg=pkg),
        _retries=3,
        _retry_delay=10,
    )

# Alternative: install all at once (closer to how Salt's pacman_install macro works).
# This is more efficient but less granular for benchmarking individual operations.
pacman.packages(
    name="Install all bench packages at once",
    packages=PACKAGES,
    present=True,
    _if="! (pacman -Qi ripgrep && pacman -Qi fd && pacman -Qi bat)",
    _retries=3,
    _retry_delay=10,
)
