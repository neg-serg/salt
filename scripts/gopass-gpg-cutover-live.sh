#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: gopass-gpg-cutover-live.sh [options]

Promote a previously validated rehearsal GPG store into the active gopass store.
The script is fail-closed: if post-cutover verification fails, it restores the
previous active store automatically.

Options:
  --workdir <path>         Rehearsal workdir. Default: /tmp/gopass-gpg-rehearsal-$USER
  --secret <path>          Verify this secret after cutover. Can be passed multiple times.
  --skip-chezmoi-diff      Skip the chezmoi diff verification step.
  -h, --help               Show this help.

Default verification set:
  - ssh-key
  - email/gmail/app-password
  - api/proxypilot-local
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '==> %s\n' "$*"
}

default_secrets=(
  "ssh-key"
  "email/gmail/app-password"
  "api/proxypilot-local"
)

workdir="/tmp/gopass-gpg-rehearsal-${USER}"
skip_chezmoi_diff="false"
declare -a requested_secrets=()

while (($# > 0)); do
  case "$1" in
    --workdir)
      workdir="${2:-}"
      shift 2
      ;;
    --secret)
      requested_secrets+=("${2:-}")
      shift 2
      ;;
    --skip-chezmoi-diff)
      skip_chezmoi_diff="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
done

command -v gopass >/dev/null 2>&1 || die "gopass not found"
command -v chezmoi >/dev/null 2>&1 || die "chezmoi not found"

active_store="$(gopass config | awk -F' = ' '$1 == "mounts.path" { print $2 }')"
[[ -n "${active_store}" ]] || die "failed to discover mounts.path from gopass config"
[[ -d "${active_store}" ]] || die "active store does not exist: ${active_store}"

rehearsal_store="${workdir}/rehearsal-store"
[[ -d "${rehearsal_store}" ]] || die "rehearsal store does not exist: ${rehearsal_store}"
[[ -f "${rehearsal_store}/.gpg-id" ]] || die "rehearsal store is not gpg-backed: ${rehearsal_store}"

if ((${#requested_secrets[@]} > 0)); then
  secrets=("${requested_secrets[@]}")
else
  secrets=("${default_secrets[@]}")
fi

timestamp="$(date +%F-%H%M%S)"
backup_store="${active_store}.age-backup-${timestamp}"
previous_store="${active_store}.age-old-${timestamp}"
config_backup="${HOME}/.config/gopass.backup-${timestamp}"

rolled_back="false"

rollback() {
  if [[ "${rolled_back}" == "true" ]]; then
    return
  fi
  rolled_back="true"

  if [[ -d "${active_store}" ]]; then
    rm -rf "${active_store}"
  fi
  if [[ -d "${previous_store}" ]]; then
    mv "${previous_store}" "${active_store}"
  fi
}

cleanup() {
  status=$?
  if (( status != 0 )); then
    rollback
  fi
  exit "${status}"
}

trap cleanup EXIT

log "capturing backups"
cp -a "${active_store}" "${backup_store}"
cp -a "${HOME}/.config/gopass" "${config_backup}"

log "promoting rehearsal store to active store"
mv "${active_store}" "${previous_store}"
cp -a "${rehearsal_store}" "${active_store}"

log "verifying active store marker"
[[ -f "${active_store}/.gpg-id" ]] || die "new active store does not contain .gpg-id"

for secret in "${secrets[@]}"; do
  log "verifying ${secret}"
  gopass show "${secret}" >/dev/null
done

if [[ "${skip_chezmoi_diff}" != "true" ]]; then
  log "running chezmoi diff"
  chezmoi diff --source "$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/dotfiles" >/dev/null
fi

trap - EXIT

cat <<EOF

Cutover succeeded.

Active store: ${active_store}
Backup copy: ${backup_store}
Pre-cutover store: ${previous_store}
Config backup: ${config_backup}

Keep these until you are satisfied the new GPG-backed store is stable.
EOF
