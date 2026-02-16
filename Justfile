# Justfile for salt configuration management

# Apply the full configuration
apply:
    ./apply_config.sh

# Run the configuration in dry-run mode (no changes)
dry-run:
    ./apply_config.sh --dry-run

# Re-bootstrap the salt environment
bootstrap:
    python3 -m venv .venv
    .venv/bin/pip install ruff jinja2 pyyaml
    ./apply_config.sh --dry-run

# Show salt state info
info:
    ./apply_config.sh --dry-run | grep -A 20 "Summary for local"

# Clean temporary files
clean:
    rm -rf __pycache__
    rm -rf .venv
    rm -rf /home/neg/.gemini/tmp/salt_config

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

# Update tools (specify names or --all)
update-tools *ARGS:
    .venv/bin/python3 scripts/update-tools.py --update {{ARGS}}

# Test idempotency: verify applying states would make no changes (needs prior apply)
test-idempotency STATE="system_description":
    #!/usr/bin/env bash
    set -uo pipefail
    echo "--- Idempotency check: {{STATE}} (test=True) ---"
    ./apply_cachyos.sh {{STATE}} --dry-run
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

# Validate all states render without errors (no execution)
validate:
    #!/usr/bin/env bash
    set -euo pipefail
    failed=0
    for sls in states/*.sls; do
        name="${sls#states/}"
        name="${name%.sls}"
        if ! sudo salt-call --local --config-dir=.salt_runtime state.show_sls "$name" --out=quiet 2>/dev/null; then
            echo "FAILED: $name"
            failed=$((failed + 1))
        fi
    done
    echo "Validated $(ls states/*.sls | wc -l) states, $failed failed"
    [ "$failed" -eq 0 ]
