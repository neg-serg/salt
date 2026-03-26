#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: gopass-gpg-cutover-rehearsal.sh --gpg-id <fingerprint> [options]

Build an isolated GPG-backed rehearsal store from the current active gopass store
without touching ~/.config/gopass or the live store path.

Options:
  --gpg-id <fingerprint>   GPG recipient fingerprint for the rehearsal store.
  --workdir <path>         Scratch directory. Default: /tmp/gopass-gpg-rehearsal-$USER
  --secret <path>          Rehearse only this secret. Can be passed multiple times.
  --all-secrets            Rehearse the whole store instead of the representative set.
  --resume                 Reuse an existing workdir and skip already verified secrets.
  --skip-chezmoi-diff      Skip the chezmoi diff validation step.
  --keep-workdir           Do not remove the workdir after success.
  -h, --help               Show this help.

Default representative set:
  - ssh-key
  - email/gmail/app-password
  - api/proxypilot-local
  - recov/MEGA-RECOVERYKEY.txt
  - recov/github-recovery-codes.txt
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '==> %s\n' "$*"
}

cleanup() {
  if [[ -n "${original_config_path:-}" && -n "${original_config_backup:-}" && -f "${original_config_backup}" ]]; then
    cp -f "${original_config_backup}" "${original_config_path}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${store_alias:-}" ]]; then
    gopass mounts remove "${store_alias}" >/dev/null 2>&1 || true
  fi
  if [[ "${keep_workdir}" == "true" ]]; then
    return
  fi
  if [[ -n "${workdir:-}" && -d "${workdir}" ]]; then
    rm -rf "${workdir}"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

derive_secret_name() {
  local path="$1"
  local rel="${path#"${active_store}"/}"
  printf '%s\n' "${rel%"${source_extension}"}"
}

export_path_for_secret() {
  local secret="$1"
  local escaped="${secret//\//__SLASH__}"
  printf '%s/source-export/%s' "${workdir}" "${escaped}"
}

list_store_secret_files() {
  find "${active_store}" \
    -path "${active_store}/.git" -prune -o \
    -type f \
    ! -name '.gpg-id' \
    ! -name '.age-recipients' \
    ! -name '.gitattributes' \
    ! -name '.gitignore' \
    ! -name '.extensions' \
    -print |
    sort
}

default_secrets=(
  "ssh-key"
  "email/gmail/app-password"
  "api/proxypilot-local"
  "recov/MEGA-RECOVERYKEY.txt"
  "recov/github-recovery-codes.txt"
)

gpg_id=""
workdir="/tmp/gopass-gpg-rehearsal-${USER}"
all_secrets="false"
resume_run="false"
skip_chezmoi_diff="false"
keep_workdir="false"
declare -a requested_secrets=()

while (($# > 0)); do
  case "$1" in
    --gpg-id)
      gpg_id="${2:-}"
      shift 2
      ;;
    --workdir)
      workdir="${2:-}"
      shift 2
      ;;
    --secret)
      requested_secrets+=("${2:-}")
      shift 2
      ;;
    --all-secrets)
      all_secrets="true"
      shift
      ;;
    --resume)
      resume_run="true"
      shift
      ;;
    --skip-chezmoi-diff)
      skip_chezmoi_diff="true"
      shift
      ;;
    --keep-workdir)
      keep_workdir="true"
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

[[ -n "${gpg_id}" ]] || {
  usage >&2
  die "--gpg-id is required"
}

trap cleanup EXIT

require_cmd gopass
require_cmd gpg
require_cmd gpg-connect-agent
require_cmd chezmoi
require_cmd find
require_cmd grep
require_cmd mktemp

active_store="$(gopass config | awk -F' = ' '$1 == "mounts.path" { print $2 }')"
[[ -n "${active_store}" ]] || die "failed to discover mounts.path from gopass config"
[[ -d "${active_store}" ]] || die "active store does not exist: ${active_store}"

if [[ -f "${active_store}/.age-recipients" ]]; then
  source_marker=".age-recipients"
  source_extension=".age"
elif [[ -f "${active_store}/.gpg-id" ]]; then
  source_marker=".gpg-id"
  source_extension=".gpg"
else
  die "could not find .age-recipients or .gpg-id in ${active_store}"
fi

if ! gpg --list-keys --with-colons "${gpg_id}" >/dev/null 2>&1; then
  die "GPG recipient not available locally: ${gpg_id}"
fi

if [[ -x "${HOME}/.local/bin/gpg-warmup" ]]; then
  log "warming up the current gpg session"
  if ! "${HOME}/.local/bin/gpg-warmup" >/dev/null; then
    log "gpg-warmup did not succeed; continuing with direct gpg-agent refresh"
  fi
fi

if tty >/dev/null 2>&1; then
  export GPG_TTY
  GPG_TTY="$(tty)"
  export PINENTRY_USER_DATA="force-tty"
fi

log "refreshing gpg-agent tty binding"
gpg-connect-agent updatestartuptty /bye >/dev/null

if [[ "${all_secrets}" == "true" ]]; then
  mapfile -t secrets < <(list_store_secret_files | while read -r secret_file; do derive_secret_name "${secret_file}"; done)
elif ((${#requested_secrets[@]} > 0)); then
  secrets=("${requested_secrets[@]}")
else
  secrets=("${default_secrets[@]}")
fi

((${#secrets[@]} > 0)) || die "no secrets selected for rehearsal"

log "using active store ${active_store} (${source_marker})"
log "selected ${#secrets[@]} secret(s) for rehearsal"

log "checking that the current session can decrypt the source store"
if ! gopass show "${secrets[0]}" >/dev/null 2>&1; then
  die "source store is not unlocked in this session; unlock gopass and retry"
fi

log "checking that the target gpg key can decrypt in this session"
preflight_plain="$(mktemp "${workdir}.gpg-preflight-plain.XXXXXX")"
preflight_cipher="${preflight_plain}.gpg"
trap 'rm -f "${preflight_plain:-}" "${preflight_cipher:-}"; cleanup' EXIT
printf 'gpg rehearsal preflight\n' > "${preflight_plain}"
gpg --batch --yes --quiet --trust-model always --recipient "${gpg_id}" --output "${preflight_cipher}" --encrypt "${preflight_plain}" >/dev/null 2>&1 || {
  die "failed to encrypt the target gpg preflight payload"
}
if ! gpg --batch --quiet --decrypt "${preflight_cipher}" >/dev/null 2>&1; then
  die "target gpg key is not unlocked in this session or pinentry is unavailable"
fi
rm -f "${preflight_plain}" "${preflight_cipher}"
preflight_plain=""
preflight_cipher=""

if [[ "${resume_run}" != "true" ]]; then
  rm -rf "${workdir}"
fi
mkdir -p "${workdir}/source-export" "${workdir}/logs"
rehearsal_store="${workdir}/rehearsal-store"
store_alias="rehearsal-gpg-cutover-$$"
completed_log="${workdir}/logs/completed-secrets.txt"

if [[ "${resume_run}" == "true" && -f "${rehearsal_store}/.gpg-id" ]]; then
  log "reusing existing rehearsal store at ${rehearsal_store}"
  gopass mounts remove "${store_alias}" >/dev/null 2>&1 || true
  gopass mounts add "${store_alias}" "${rehearsal_store}" >/dev/null
else
  log "initializing isolated rehearsal store at ${rehearsal_store}"
  rm -rf "${rehearsal_store}"
  gopass mounts remove "${store_alias}" >/dev/null 2>&1 || true
  gopass --nosync init --crypto gpgcli --store "${store_alias}" --path "${rehearsal_store}" "${gpg_id}" >/dev/null
fi

printf 'source_store=%s\n' "${active_store}" > "${workdir}/logs/summary.env"
printf 'source_marker=%s\n' "${source_marker}" >> "${workdir}/logs/summary.env"
printf 'rehearsal_store=%s\n' "${rehearsal_store}" >> "${workdir}/logs/summary.env"
printf 'gpg_id=%s\n' "${gpg_id}" >> "${workdir}/logs/summary.env"
printf 'store_alias=%s\n' "${store_alias}" >> "${workdir}/logs/summary.env"
printf 'resume_run=%s\n' "${resume_run}" >> "${workdir}/logs/summary.env"

for secret in "${secrets[@]}"; do
  if [[ ! -f "${active_store}/${secret}${source_extension}" ]]; then
    die "secret not found in source store: ${secret}"
  fi
done

for secret in "${secrets[@]}"; do
  if [[ -f "${completed_log}" ]] && grep -Fqx -- "${secret}" "${completed_log}"; then
    log "skipping ${secret}; already verified in previous run"
    continue
  fi

  export_path="$(export_path_for_secret "${secret}")"
  mkdir -p "${workdir}/source-export"

  log "exporting ${secret} from source store"
  gopass fscopy "${secret}" "${export_path}" >/dev/null

  if grep -Iq . "${export_path}"; then
    log "importing ${secret} into rehearsal store as text"
    gopass insert -f "${store_alias}/${secret}" < "${export_path}" >/dev/null
  else
    log "importing ${secret} into rehearsal store as binary"
    gopass fscopy "${export_path}" "${store_alias}/${secret}" >/dev/null
  fi

  source_sum="$(gopass sum "${secret}" | awk '{print $1}')"
  rehearsal_sum="$(gopass sum "${store_alias}/${secret}" | awk '{print $1}')"
  [[ -n "${source_sum}" && -n "${rehearsal_sum}" ]] || die "failed to compute checksum for ${secret}"
  [[ "${source_sum}" == "${rehearsal_sum}" ]] || die "checksum mismatch for ${secret}"

  printf '%s  %s\n' "${source_sum}" "${secret}" >> "${workdir}/logs/checksums.txt"
  printf '%s\n' "${secret}" >> "${completed_log}"
done

if [[ "${skip_chezmoi_diff}" != "true" ]]; then
  repo_root="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  log "running chezmoi diff against the rehearsal backend"
  original_config_path="${HOME}/.config/gopass/config"
  original_config_backup="${workdir}/logs/original-gopass-config.toml"
  cp -f "${original_config_path}" "${original_config_backup}"
  gopass config mounts.path "${rehearsal_store}" >/dev/null
  chezmoi diff --source "${repo_root}/dotfiles" > "${workdir}/logs/chezmoi.diff" 2>&1 || {
    printf 'chezmoi diff output:\n' >&2
    sed -n '1,200p' "${workdir}/logs/chezmoi.diff" >&2
    die "chezmoi diff failed under the rehearsal backend"
  }
  cp -f "${original_config_backup}" "${original_config_path}"
  original_config_backup=""
fi

cat <<EOF

Rehearsal succeeded.

Workdir: ${workdir}
Rehearsal store: ${rehearsal_store}
Secrets rehearsed: ${#secrets[@]}

Next manual gates before any live swap:
  1. Review ${workdir}/logs/checksums.txt
  2. If needed, inspect ${workdir}/logs/chezmoi.diff
  3. Re-run this script with --all-secrets before a production cutover
  4. Only then prepare a rollback package and swap the active store path
EOF
