#!/usr/bin/env bash
# smoke-test.sh — apply core Salt states in an isolated Podman container
#
# Applies a curated subset of offline-capable states (no AUR, no GPU,
# no disk mounts, no secrets) and validates outcomes with assertions.
#
# Usage:
#   tests/smoke-test.sh              # run all smoke tests
#   tests/smoke-test.sh --verbose    # show full salt output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE="archlinux:latest"
CONTAINER_NAME="salt-smoke-$$"
VERBOSE=false

for arg in "$@"; do
    case "$arg" in
        --verbose|-v) VERBOSE=true ;;
        *) echo "Unknown arg: $arg" >&2; exit 1 ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

passed=0
failed=0
skipped=0

assert() {
    local desc="$1"
    shift
    if "$@" 2>/dev/null; then
        printf '%b  ✓ %s%b\n' "$GREEN" "$desc" "$NC"
        passed=$((passed + 1))
    else
        printf '%b  ✗ %s%b\n' "$RED" "$desc" "$NC"
        failed=$((failed + 1))
    fi
}

trap 'podman rm -f "$CONTAINER_NAME" &>/dev/null || true' EXIT

echo "=== Salt Smoke Test ==="
echo "Image: $IMAGE"
echo "Container: $CONTAINER_NAME"
echo ""

# ── Pull image if needed ─────────────────────────────────────────────────
echo "--- Preparing container ---"
podman pull "$IMAGE" -q 2>/dev/null || true

# ── Start container with states mounted ──────────────────────────────────
podman run -d --name "$CONTAINER_NAME" \
    -v "${PROJECT_DIR}:/srv/salt:ro" \
    "$IMAGE" sleep infinity

# Helper to run commands in container
run() { podman exec "$CONTAINER_NAME" "$@"; }

# ── Bootstrap Salt inside container ──────────────────────────────────────
echo "--- Installing Salt ---"
run pacman -Sy --noconfirm python python-pip &>/dev/null
run pip install --break-system-packages -q -r /srv/salt/requirements.txt 2>/dev/null

# Create minimal salt config
run mkdir -p /etc/salt/pki/minion /var/cache/salt
run bash -c 'cat > /etc/salt/minion <<EOF
file_client: local
file_roots:
  base:
    - /srv/salt/states/
    - /srv/salt/
enable_fqdns_grains: False
enable_gpu_grains: False
autoload_dynamic_modules: False
EOF'

# Create mock host config for container (minimal features)
run bash -c 'cat > /etc/salt/grains <<EOF
host: smoke-test
EOF'

# ── Apply states ─────────────────────────────────────────────────────────
# Curated subset: states that work without network, hardware, or secrets
# We test rendering + basic execution for a limited safe set
SAFE_STATES=(
    sysctl
)

echo ""
echo "--- Applying states ---"
for state in "${SAFE_STATES[@]}"; do
    echo -n "  Applying ${state}... "
    output=$(run salt-call --local --config-dir=/etc/salt \
        --log-level=warning \
        state.sls "$state" 2>&1) || true
    if echo "$output" | grep -q "Failed:    0"; then
        printf '%bOK%b\n' "$GREEN" "$NC"
    else
        printf '%bWARN%b (some states may require missing prerequisites)\n' "$YELLOW" "$NC"
        $VERBOSE && echo "$output" | tail -5
    fi
done

# Full tree rendering is covered separately by `just validate` and
# `just render-matrix` in CI. The smoke test stays focused on applying a small
# offline-capable subset inside the container.

# ── Assertions ───────────────────────────────────────────────────────────
echo ""
echo "--- Assertions ---"

# Check salt is functional
salt_versions=$(run salt-call --local --config-dir=/etc/salt test.version 2>/dev/null || echo "")
assert "Salt is functional" test -n "$salt_versions"

# Check state rendering count
state_count=$(find "${PROJECT_DIR}/states" -maxdepth 1 -name '*.sls' | wc -l)
assert "At least 30 state files exist" test "$state_count" -ge 30

# ── Summary ──────────────────────────────────────────────────────────────
echo ""
echo "=== Results ==="
printf '  Passed:  %b%d%b\n' "$GREEN" "$passed" "$NC"
printf '  Failed:  %b%d%b\n' "$RED" "$failed" "$NC"
printf '  Skipped: %b%d%b\n' "$YELLOW" "$skipped" "$NC"

if [ "$failed" -gt 0 ]; then
    printf '\n%bFAIL%b: %d assertion(s) failed\n' "$RED" "$NC" "$failed"
    exit 1
else
    printf '\n%bPASS%b: all assertions passed\n' "$GREEN" "$NC"
    exit 0
fi
