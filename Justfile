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

# Dry-run a state — no changes applied
test STATE="system_description":
    scripts/salt-apply.sh {{STATE}} --test

# Start the salt daemon (keeps running, speeds up subsequent applies)
daemon:
    sudo scripts/salt-daemon.py \
        --config-dir .salt_runtime \
        --socket /tmp/salt-daemon.sock \
        --log-level warning

# Lint Salt states and Python scripts
lint:
    .venv/bin/ruff check .
    .venv/bin/ruff format --check .
    .venv/bin/python3 scripts/lint-jinja.py

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

# Check all state files render without errors (no execution)
validate:
    #!/usr/bin/env bash
    set -euo pipefail
    failed=0
    for sls in states/*.sls; do
        name="${sls#states/}"
        name="${name%.sls}"
        if ! sudo .venv/bin/salt-call --local --config-dir=.salt_runtime \
                state.show_sls "$name" --out=quiet 2>/dev/null; then
            echo "FAILED: $name"
            failed=$((failed + 1))
        fi
    done
    echo "Validated $(ls states/*.sls | wc -l) states, $failed failed"
    [ "$failed" -eq 0 ]

# Remove generated runtime files (venv and salt runtime config)
clean:
    rm -rf __pycache__ .salt_runtime .venv
