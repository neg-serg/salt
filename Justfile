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
    #!/usr/bin/env bash
    set -uo pipefail
    errors=0

    # — Mandatory tools (fail immediately if missing) —
    for tool in .venv/bin/ruff shellcheck yamllint .venv/bin/python3; do
        if ! command -v "$tool" &>/dev/null && [ ! -x "$tool" ]; then
            echo "ERROR: mandatory tool not found: $tool" >&2
            exit 1
        fi
    done

    # — Optional tools (warn and skip if missing) —
    HAS_SALT_LINT=false
    if [ -x .venv/bin/salt-lint ]; then HAS_SALT_LINT=true
    else echo "WARN: salt-lint not found in .venv — skipping salt-lint checks"; fi

    HAS_TAPLO=false
    if command -v taplo &>/dev/null; then HAS_TAPLO=true
    else echo "WARN: taplo not found — skipping TOML checks"; fi

    run_check() {
        local name="$1"; shift
        echo "--- $name ---"
        if "$@"; then
            echo "  OK"
        else
            echo "  FAIL: $name" >&2
            ((errors++))
        fi
    }

    # 1. Python lint
    run_check "ruff check" .venv/bin/ruff check .
    # 2. Python format
    run_check "ruff format" .venv/bin/ruff format --check .
    # 3. Jinja lint
    run_check "lint-jinja" .venv/bin/python3 scripts/lint-jinja.py
    # 4. Dotfiles lint
    run_check "lint-dotfiles" .venv/bin/python3 scripts/lint-dotfiles.py
    # 5. Ownership lint
    run_check "lint-ownership" .venv/bin/python3 scripts/lint-ownership.py
    # 6. Units lint
    run_check "lint-units" .venv/bin/python3 scripts/lint-units.py
    # 7. QML lint
    run_check "lint-qml" .venv/bin/python3 scripts/lint-qml.py
    # 8. Docs lint
    run_check "lint-docs" .venv/bin/python3 scripts/lint-docs.py
    # 9. ShellCheck (sh/bash only, skip zsh)
    sc_files=()
    while IFS= read -r -d "" path; do
        first=$(head -n1 "$path")
        case "$first" in
            "#!/usr/bin/env bash"*|"#!/bin/bash"*|"#!/usr/bin/env sh"*|"#!/bin/sh"*|"#!/usr/bin/env dash"*|"#!/bin/dash"*)
                sc_files+=("$path");;
        esac
    done < <(find scripts states/scripts tests -maxdepth 1 -name "*.sh" -print0 2>/dev/null)
    if [ ${#sc_files[@]} -gt 0 ]; then
        run_check "shellcheck" shellcheck -e SC2129 "${sc_files[@]}"
    else
        echo "--- shellcheck ---"
        echo "  No bash/sh scripts to check"
    fi
    # 10. YAML lint
    run_check "yamllint" yamllint states/data/*.yaml states/configs/*.yaml .github/workflows/*.yaml
    # 11. Salt lint (optional)
    if $HAS_SALT_LINT; then
        run_check "salt-lint" .venv/bin/salt-lint states/*.sls < /dev/null
    fi
    # 12. TOML lint (optional)
    if $HAS_TAPLO; then
        toml_files=$(find . -name '*.toml' -not -path './.venv/*' -not -path './.salt_runtime/*' 2>/dev/null)
        if [ -n "$toml_files" ]; then
            run_check "taplo" taplo check $toml_files
        fi
    fi

    if [ "$errors" -gt 0 ]; then
        echo ""
        echo "FAIL: $errors lint check(s) failed" >&2
        exit 1
    fi
    echo ""
    echo "All lint checks passed"

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

# Revert to last pre-apply btrfs snapshot
rollback:
    #!/usr/bin/env bash
    set -euo pipefail
    pre=$(sudo snapper list --columns number,type,description | grep 'salt-pre:' | tail -1 | awk '{print $1}')
    if [ -z "$pre" ]; then
        echo "No salt pre-apply snapshot found" >&2
        exit 1
    fi
    post=$(sudo snapper list --columns number,type,description | grep 'salt-post:' | tail -1 | awk '{print $1}')
    if [ -z "$post" ]; then
        echo "No matching post-apply snapshot found" >&2
        exit 1
    fi
    echo "Rolling back: snapshot #${pre}..#${post}"
    sudo snapper undochange "${pre}..${post}"

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
