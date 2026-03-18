#!/usr/bin/env bash
set -euo pipefail

# Validate all Salt state files render without errors.
# Uses GNU parallel for concurrent validation.
#
# Usage: salt-validate.sh [JOBS]
#   JOBS: max parallel jobs (default: nproc, or VALIDATE_JOBS env var)
#   VALIDATE_TIMEOUT: per-state timeout in seconds (default: 300)

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

jobs="${1:-${VALIDATE_JOBS:-$(nproc)}}"
validate_timeout="${VALIDATE_TIMEOUT:-300}"

# --- Runtime directory setup ---
runtime="${project_dir}/.salt_runtime"
mkdir -p "${runtime}/pki/minion" \
         "${runtime}/var/cache/salt/pillar_cache" \
         "${runtime}/var/log/salt"
cat > "${runtime}/minion" <<MEOF
pki_dir: ${runtime}/pki/minion
log_file: /dev/null
cachedir: ${runtime}/var/cache/salt
file_client: local
file_roots:
  base:
    - ${project_dir}/states/
    - ${project_dir}/
enable_fqdns_grains: False
enable_gpu_grains: False
grains_cache: False
file_ignore_glob:
  - '*.pyc'
  - '.venv/*'
  - '.git/*'
  - '.salt_runtime/*'
  - 'specs/*'
  - '.specify/*'
  - 'node_modules/*'
MEOF

# Clear stale proc locks from previous runs
rm -rf "${runtime}/var/cache/salt/proc/"*

# Use sudo when available (CI has NOPASSWD sudo, needed for runas=)
sudo_cmd=""
if sudo -n true 2>/dev/null; then
    sudo_cmd="sudo"
fi

# --- Collect state names ---
shopt -s nullglob
sls_files=(states/*.sls)
shopt -u nullglob

total=${#sls_files[@]}
if [[ $total -eq 0 ]]; then
    echo "Warning: no .sls files found in states/"
    exit 0
fi

# --- Pre-warm cache template ---
# Salt scans file_roots to build mtime_map (expensive for large trees).
# Build it once, then copy to per-worker caches so each starts warm.
cache_base=$(mktemp -d)
joblog=$(mktemp)
trap 'rm -rf "$cache_base" "$joblog"' EXIT

template_cache="${cache_base}/template"
mkdir -p "$template_cache"
$sudo_cmd .venv/bin/salt-call --local --config-dir=.salt_runtime \
    --cachedir="$template_cache" \
    state.show_sls audio --out=quiet 2>/dev/null || true

# --- Per-state validation function (exported for GNU parallel) ---
# Each worker copies the pre-warmed template cache for isolation.
validate_one() {
    local sls="$1"
    local slot="$2"
    local name="${sls#states/}"
    name="${name%.sls}"
    local worker_cache="${cache_base}/worker-${slot}"
    if [[ ! -d "$worker_cache" ]]; then
        cp -a "${cache_base}/template" "$worker_cache"
    fi
    if $sudo_cmd .venv/bin/salt-call --local --config-dir=.salt_runtime \
            --cachedir="$worker_cache" \
            state.show_sls "$name" --out=quiet 2>/dev/null; then
        return 0
    else
        echo "FAILED: $name"
        # Re-run to capture error details
        $sudo_cmd .venv/bin/salt-call --local --config-dir=.salt_runtime \
                --cachedir="$worker_cache" \
                state.show_sls "$name" --out=quiet 2>&1 || true
        return 1
    fi
}
export -f validate_one
export sudo_cmd cache_base

# --- Parallel validation with joblog for accurate failure counting ---
# {1} and {#} are GNU parallel placeholders, not bash syntax
# shellcheck disable=SC1083
parallel --will-cite -j "$jobs" --group --timeout "$validate_timeout" --halt never \
    --joblog "$joblog" \
    validate_one {1} {#} ::: "${sls_files[@]}" || true

# Count failures from joblog (column 7 is Exitval, skip header line)
failed=$(awk 'NR>1 && $7!=0 {count++} END {print count+0}' "$joblog")

echo "Validated ${total} states, ${failed} failed"
[[ "$failed" -eq 0 ]]
