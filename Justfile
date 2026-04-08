# Salt configuration management
#
# Usage:
#   just          # apply system_description
#   just apply    # same
#   just apply hardware
#   just test     # dry-run system_description
#   just test kernel_modules

# Apply a state (default: system_description)
apply STATE="system_description":
    scripts/salt-apply.sh {{STATE}}

# Apply dotfiles only (chezmoi, no Salt)
dotfiles:
    #!/usr/bin/env bash
    set -euo pipefail
    gpg-connect-agent updatestartuptty /bye &>/dev/null || true
    install -Dm644 dotfiles/dot_config/chezmoi/chezmoi.toml \
        "${HOME}/.config/chezmoi/chezmoi.toml" 2>/dev/null || true
    chezmoi apply --force --source dotfiles

apply-user-services:
    scripts/salt-apply.sh user_services

apply-installers:
    scripts/salt-apply.sh installers

# Apply a state group (core, network, desktop, packages, services, ai)
group GROUP:
    scripts/salt-apply.sh group/{{GROUP}}

# Show which states would be applied (without executing)
show STATE="system_description":
    python3 scripts/salt-show.py {{STATE}}

# Capture current system packages into states/data/packages.yaml
pkg-snapshot *ARGS:
    ./scripts/pkg-snapshot.zsh {{ARGS}}

# Compare declared packages against actual system state
pkg-drift *ARGS:
    ./scripts/pkg-drift.zsh {{ARGS}}

# List available recipes
help:
    @just --list

# Dry-run a state — no changes applied
test STATE="system_description":
    scripts/salt-apply.sh {{STATE}} --test

# Run unit tests (data validation, host config, merge)
test-unit *ARGS:
    .venv/bin/pytest tests/ -v {{ARGS}}

# Run CachyOS VM smoke test inside Podman
vm-smoke ROOTFS="/mnt/one/cachyos-root":
    sudo scripts/vm-smoke.sh {{ROOTFS}}

# Start the salt daemon (keeps running, speeds up subsequent applies)
daemon:
    sudo scripts/salt-daemon.py \
        --config-dir .salt_runtime \
        --log-level warning

# Regenerate Claude Code knowledge base indexes
index:
    python scripts/index-qml.py
    python scripts/index-salt.py

# Lint Salt states and Python scripts
lint:
    bash scripts/lint-all.sh

# Format Python scripts
fmt:
    .venv/bin/ruff format .

# List all tools with install status
tools:
    .venv/bin/python3 scripts/update-tools.py

# Check for available GitHub release updates
check-updates:
    .venv/bin/python3 scripts/update-tools.py --check

# Update tools (specify tool names or --all)
update-tools *ARGS:
    .venv/bin/python3 scripts/update-tools.py --update {{ARGS}}

# Verify a state would make no changes (idempotency check)
idempotency STATE="system_description":
    #!/usr/bin/env bash
    set -uo pipefail
    echo "--- Idempotency check: {{STATE}} ---"
    scripts/salt-apply.sh {{STATE}} --test
    log=$(ls -t logs/{{STATE}}-*.log 2>/dev/null | head -1)
    if [ -z "$log" ]; then
        echo "ERROR: no log file found"
        exit 1
    fi
    if grep -q 'changed=' "$log"; then
        echo ""
        echo "FAIL: non-idempotent states detected in $log"
        grep 'changed=' "$log"
        exit 1
    fi
    echo "PASS: all states idempotent"

# Verify sysctl-custom.conf values are applied on live system
lint-sysctl:
    .venv/bin/python3 scripts/lint-sysctl.py

# Check all state files render without errors (no execution, parallel)
validate JOBS="":
    scripts/salt-validate.sh {{JOBS}}

# Check if salt-daemon is running and responsive
daemon-health:
    #!/usr/bin/env bash
    sock="${SALT_DAEMON_SOCK:-/run/salt-daemon.sock}"
    if [ ! -S "$sock" ]; then
        echo "OFFLINE (no socket at $sock)"
        exit 1
    fi
    if python3 -c "
    import socket, sys
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(2)
    s.connect('$sock')
    s.close()
    " 2>/dev/null; then
        echo "HEALTHY (listening on $sock)"
    else
        echo "UNHEALTHY (socket exists but not responding)"
        exit 1
    fi

# Remove generated runtime files (venv and salt runtime config)
clean:
    rm -rf __pycache__ .salt_runtime .venv

# Render all states for every feature-matrix scenario (template smoke test)
render-matrix:
    python3 scripts/render-matrix.py

# Profile Salt state durations from the latest log (or provided LOG)
profile LOG="":
    #!/usr/bin/env bash
    set -euo pipefail
    log="{{LOG}}"
    if [ -z "$log" ]; then
        log=$(ls -t logs/*.log 2>/dev/null | head -1)
    fi
    if [ -z "$log" ]; then
        echo "No logs found" >&2
        exit 1
    fi
    python3 scripts/state-profiler.py "$log"

# Prune log files older than N days (default 14)
logs-prune DAYS="14" DRY_RUN="":
    if [ "{{DRY_RUN}}" = "1" ]; then \
        python3 scripts/cleanup-logs.py --days {{DAYS}} --dry-run; \
    else \
        python3 scripts/cleanup-logs.py --days {{DAYS}}; \
    fi

# Generate Salt state dependency graph
dep-graph *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    args=({{ARGS}})
    if [ ${#args[@]} -eq 0 ]; then
        python3 scripts/dep-graph.py --format svg --output logs/dep-graph.svg
        echo "Written to logs/dep-graph.svg"
        handlr open logs/dep-graph.svg 2>/dev/null || echo "Open logs/dep-graph.svg to view"
    else
        python3 scripts/dep-graph.py "${args[@]}"
    fi

# Run container-based smoke test (Podman)
smoke-test *ARGS:
    tests/smoke-test.sh {{ARGS}}

# Profile state durations with optional trend analysis
profile-trend:
    python3 scripts/state-profiler.py --trend

# Compare two state apply logs for regressions
profile-compare LOG1 LOG2:
    python3 scripts/state-profiler.py --compare {{LOG1}} {{LOG2}}

# Check health of all Salt-managed services
health *ARGS:
    ~/.local/bin/salt-alert --health {{ARGS}}
