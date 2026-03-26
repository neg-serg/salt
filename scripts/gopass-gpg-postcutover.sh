#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: gopass-gpg-postcutover.sh <command> [options]

Post-cutover helper for the local GPG-backed gopass migration.

Commands:
  status    Show active markers and known backup paths.
  cleanup   Remove post-cutover backup artifacts.
  rollback  Restore the pre-cutover age-backed store and config backups.

Options:
  --timestamp <value>   Cutover timestamp suffix.
                        Default: 2026-03-27-012946
  -h, --help            Show this help.
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '==> %s\n' "$*"
}

timestamp="2026-03-27-012946"

while (($# > 0)); do
  case "$1" in
    --timestamp)
      timestamp="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    status|cleanup|rollback)
      command_name="$1"
      shift
      break
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "${command_name:-}" ]] || {
  usage >&2
  die "command is required"
}

if (($# > 0)); then
  usage >&2
  die "unexpected trailing arguments: $*"
fi

active_store="${HOME}/.local/share/pass"
backup_store="${HOME}/.local/share/pass.age-backup-${timestamp}"
old_store="${HOME}/.local/share/pass.age-old-${timestamp}"
config_dir="${HOME}/.config/gopass"
config_backup="${HOME}/.config/gopass.backup-${timestamp}"
rehearsal_dir="/tmp/gopass-gpg-rehearsal-${USER}"

show_status() {
  printf 'Active store: %s\n' "${active_store}"
  find "${active_store}" -maxdepth 2 \( -name '.gpg-id' -o -name '.age-recipients' \) 2>/dev/null || true
  printf '\nKnown artifacts:\n'
  for path in "${backup_store}" "${old_store}" "${config_backup}" "${rehearsal_dir}"; do
    if [[ -e "${path}" ]]; then
      printf 'present  %s\n' "${path}"
    else
      printf 'missing  %s\n' "${path}"
    fi
  done
}

cleanup_artifacts() {
  for path in "${backup_store}" "${old_store}" "${config_backup}" "${rehearsal_dir}"; do
    if [[ -e "${path}" ]]; then
      log "removing ${path}"
      rm -rf "${path}"
    else
      log "skipping missing ${path}"
    fi
  done
}

rollback_cutover() {
  [[ -d "${old_store}" ]] || die "rollback source missing: ${old_store}"
  [[ -d "${config_backup}" ]] || die "config backup missing: ${config_backup}"

  if [[ -e "${active_store}" ]]; then
    log "removing current active store ${active_store}"
    rm -rf "${active_store}"
  fi

  log "restoring ${old_store} -> ${active_store}"
  cp -a "${old_store}" "${active_store}"

  if [[ -e "${config_dir}" ]]; then
    log "removing current config ${config_dir}"
    rm -rf "${config_dir}"
  fi

  log "restoring ${config_backup} -> ${config_dir}"
  cp -a "${config_backup}" "${config_dir}"

  log "rollback restored; verify with gopass show and marker check"
  find "${active_store}" -maxdepth 2 \( -name '.gpg-id' -o -name '.age-recipients' \) 2>/dev/null || true
}

case "${command_name}" in
  status)
    show_status
    ;;
  cleanup)
    cleanup_artifacts
    ;;
  rollback)
    rollback_cutover
    ;;
  *)
    die "unsupported command: ${command_name}"
    ;;
esac
