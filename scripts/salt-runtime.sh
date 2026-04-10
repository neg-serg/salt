#!/usr/bin/env bash

salt_runtime_prepare_dirs() {
    local project_dir="$1"
    local runtime_dir="$2"

    mkdir -p "${runtime_dir}/pki/minion" \
        "${runtime_dir}/var/cache/salt/pillar_cache" \
        "${runtime_dir}/var/cache/salt/files" \
        "${runtime_dir}/var/cache/salt/roots" \
        "${runtime_dir}/var/cache/salt/proc" \
        "${runtime_dir}/var/cache/salt/file_lists" \
        "${runtime_dir}/var/cache/salt/accumulator" \
        "${runtime_dir}/var/cache/salt/extrn_files" \
        "${runtime_dir}/var/log/salt"
}


salt_runtime_write_minion_config() {
    local project_dir="$1"
    local runtime_dir="$2"
    local mode="$3"
    local minion_path="${runtime_dir}/minion"

    case "$mode" in
        apply)
            cat > "${minion_path}" <<EOF
pki_dir: ${runtime_dir}/pki/minion
log_file: ${runtime_dir}/var/log/salt/minion
cachedir: ${runtime_dir}/var/cache/salt
minion_pillar_cache: True
pillar_cache: True
pillar_cache_backend: disk
pillar_cache_ttl: 3600
file_client: local
file_roots:
  base:
    - ${project_dir}/states/
    - ${project_dir}/

# --- Performance optimizations ---
enable_fqdns_grains: False
enable_gpu_grains: False
grains_cache: True
grains_cache_expiration: 3600
lazy_loader_strict_matching: True
autoload_dynamic_modules: False
fileserver_limit_traversal: True
process_count_max: 16
EOF
            ;;
        validate)
            cat > "${minion_path}" <<EOF
pki_dir: ${runtime_dir}/pki/minion
log_file: /dev/null
cachedir: ${runtime_dir}/var/cache/salt
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
EOF
            ;;
        *)
            echo "error: unknown salt runtime mode: ${mode}" >&2
            return 1
            ;;
    esac
}


salt_runtime_clear_stale_proc_locks() {
    local runtime_dir="$1"

    rm -rf "${runtime_dir}/var/cache/salt/proc/"*
}


salt_runtime_reset_validate_cache() {
    local runtime_dir="$1"
    local cache_root="${runtime_dir}/var/cache/salt"

    # Validation cache is ephemeral. Clear file/roots caches so foreign-owned
    # artifacts from previous sudo/runas executions cannot poison later renders.
    rm -rf \
        "${cache_root}/files" \
        "${cache_root}/roots" \
        "${cache_root}/proc" \
        "${cache_root}/file_lists" \
        "${cache_root}/accumulator" \
        "${cache_root}/extrn_files"

    mkdir -p \
        "${cache_root}/files" \
        "${cache_root}/roots" \
        "${cache_root}/proc" \
        "${cache_root}/file_lists" \
        "${cache_root}/accumulator" \
        "${cache_root}/extrn_files"
}
