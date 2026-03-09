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

apply-opencode:
    scripts/salt-apply.sh opencode

apply-user-services:
    scripts/salt-apply.sh user_services

apply-installers:
    scripts/salt-apply.sh installers

# List available recipes
help:
    @just --list

# Dry-run a state — no changes applied
test STATE="system_description":
    scripts/salt-apply.sh {{STATE}} --test

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
    .venv/bin/ruff check .
    .venv/bin/ruff format --check .
    .venv/bin/python3 scripts/lint-jinja.py
    .venv/bin/python3 scripts/lint-dotfiles.py
    .venv/bin/python3 scripts/lint-ownership.py
    .venv/bin/python3 scripts/lint-units.py
    .venv/bin/python3 scripts/lint-qml.py
    .venv/bin/python3 scripts/render-matrix.py
    # ShellCheck only understands sh/bash; skip zsh scripts.
    bash -c 'set -euo pipefail; files=(); while IFS= read -r -d "" path; do first=$(head -n1 "$path"); case "$first" in ("#!/usr/bin/env bash"*|"#!/bin/bash"*|"#!/usr/bin/env sh"*|"#!/bin/sh"*|"#!/usr/bin/env dash"*|"#!/bin/dash"*) files+=("$path");; esac; done < <(find scripts states/scripts -maxdepth 1 -name "*.sh" -print0); if [ ${#files[@]} -gt 0 ]; then shellcheck -e SC2129 "${files[@]}"; else echo "No bash scripts for shellcheck"; fi'
    yamllint states/data/*.yaml states/configs/*.yaml .github/workflows/*.yaml
    taplo check $(find . -name '*.toml' -not -path './.venv/*' -not -path './.salt_runtime/*' 2>/dev/null)

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

# Check all state files render without errors (no execution)
validate:
    #!/usr/bin/env bash
    set -euo pipefail
    # Regenerate .salt_runtime/minion with correct absolute paths
    # Note: just runs recipes from the Justfile directory, so PWD is correct
    project_dir="$(pwd)"
    runtime="${project_dir}/.salt_runtime"
    mkdir -p "${runtime}/pki/minion" \
             "${runtime}/var/cache/salt/pillar_cache" \
             "${runtime}/var/log/salt"
    cat > "${runtime}/minion" <<MEOF
    pki_dir: ${runtime}/pki/minion
    log_file: ${runtime}/var/log/salt/minion
    cachedir: ${runtime}/var/cache/salt
    file_client: local
    file_roots:
      base:
        - ${project_dir}/states/
        - ${project_dir}/
    enable_fqdns_grains: False
    enable_gpu_grains: False
    grains_cache: False
    MEOF
    failed=0
    for sls in states/*.sls; do
        name="${sls#states/}"
        name="${name%.sls}"
        if ! .venv/bin/salt-call --local --config-dir=.salt_runtime \
                state.show_sls "$name" --out=quiet 2>/dev/null; then
            echo "FAILED: $name"
            failed=$((failed + 1))
        fi
    done
    echo "Validated $(ls states/*.sls | wc -l) states, $failed failed"
    [ "$failed" -eq 0 ]

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
