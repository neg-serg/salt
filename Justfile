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
    ./apply_config.sh --dry-run

# Show salt state info
info:
    ./apply_config.sh --dry-run | grep -A 20 "Summary for local"

# Clean temporary files
clean:
    rm -rf __pycache__
    rm -rf .venv
    rm -rf /var/home/neg/.gemini/tmp/salt_config

# Lint Salt states and Python scripts
lint:
    ruff check .
    ruff format --check .
    salt-lint *.sls salt/**/*.sls

# Format Python scripts
fmt:
    ruff format .
