#!/bin/bash
set -uo pipefail

# Apply Salt states on CachyOS.
# Defaults to the cachyos.sls verification state; accepts any state name.
#
# Usage:
#   ./apply_cachyos.sh                        # apply all states (system_description)
#   ./apply_cachyos.sh cachyos                # smoke-test only (verify bootstrap)
#   ./apply_cachyos.sh kernel_modules         # apply kernel_modules.sls
#   ./apply_cachyos.sh kernel_params_limine   # apply Limine kernel params
#   ./apply_cachyos.sh hardware               # apply hardware/fancontrol
#   ./apply_cachyos.sh sysctl --dry-run       # test mode

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"
ACTION="state.sls"

# Parse arguments: first non-flag arg is STATE, --dry-run is a flag
STATE="system_description"
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        -*) echo "Unknown flag: $arg" >&2; exit 1 ;;
        *) STATE="$arg" ;;
    esac
done

LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${LOG_DIR}/${STATE}-${TIMESTAMP}.log"

# Runtime salt config (paths derived from SCRIPT_DIR)
RUNTIME_CONFIG_DIR="${SCRIPT_DIR}/.salt_runtime"

mkdir -p "${LOG_DIR}"

setup_config() {
  mkdir -p "${RUNTIME_CONFIG_DIR}/pki/minion" "${RUNTIME_CONFIG_DIR}/var/cache/salt/pillar_cache" "${RUNTIME_CONFIG_DIR}/var/log/salt"
  cat > "${RUNTIME_CONFIG_DIR}/minion" <<EOF
pki_dir: ${RUNTIME_CONFIG_DIR}/pki/minion
log_file: ${RUNTIME_CONFIG_DIR}/var/log/salt/minion
cachedir: ${RUNTIME_CONFIG_DIR}/var/cache/salt
minion_pillar_cache: True
pillar_cache: True
pillar_cache_backend: disk
pillar_cache_ttl: 3600
state_output: changes
file_client: local
file_roots:
  base:
    - ${SCRIPT_DIR}/states/
    - ${SCRIPT_DIR}/
EOF
}

bootstrap_salt() {
  if [[ ! -d "$VENV_DIR" ]]; then
    echo "--- Bootstrapping Salt (creating venv) ---"
    python3 -m venv "$VENV_DIR"
  fi

  if [[ ! -f "$VENV_DIR/bin/salt-call" ]]; then
    echo "--- Installing Salt and dependencies ---"
    "$VENV_DIR/bin/pip" install salt passlib tornado jinja2 msgpack pyyaml psutil requests distro looseversion packaging pycryptodomex

    # Patch Salt for Python 3.14+ urlunparse behavior (character swallowing)
    PYVER=$("$VENV_DIR/bin/python3" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    URL_PY="$VENV_DIR/lib/python${PYVER}/site-packages/salt/utils/url.py"
    if [[ -f "$URL_PY" ]]; then
      echo "--- Patching Salt for Python 3.14 compatibility ---"
      sed -i 's/return "salt:\/\/{}".format(url\[len("file:\/\/\/") :\])/return "salt:\/\/{}".format(url.split("file:", 1)[1].lstrip("\/"))/' "$URL_PY"
    fi
  fi
}

get_sudo() {
  # Use NOPASSWD if available, otherwise read from .password file
  if sudo -n true 2>/dev/null; then
    SUDO_CMD="sudo -E"
  elif [[ -f "${SCRIPT_DIR}/.password" ]]; then
    SUDO_CMD="sudo -S -E"
    SUDO_PASS=$(cat "${SCRIPT_DIR}/.password")
  else
    echo "error: no NOPASSWD sudo and no .password file found" >&2
    echo "  either configure NOPASSWD or create .password" >&2
    exit 1
  fi
}

# Inline Salt runner: patches removed stdlib modules for Python 3.13+
# (crypt, spwd) and suppresses Salt's internal DeprecationWarnings.
SALT_RUNNER='
import sys
import warnings

_orig_showwarning = warnings.showwarning

def _showwarning(msg, cat, filename, lineno, file=None, line=None):
    if cat is DeprecationWarning and "/salt/" in filename:
        return
    _orig_showwarning(msg, cat, filename, lineno, file, line)

warnings.showwarning = _showwarning

class MockCrypt:
    def __init__(self):
        try:
            import passlib.hash as hash
            self.hash = hash
        except ImportError:
            self.hash = None
            print("Warning: passlib not found. Salt user password management might fail.")

        class Method:
            def __init__(self, name, ident):
                self.name = name
                self.ident = ident

        self.methods = [
            Method("sha512", "6"),
            Method("sha256", "5"),
            Method("md5", "1"),
            Method("crypt", ""),
        ]

    def crypt(self, word, salt):
        if not self.hash:
            raise ImportError("passlib is required for crypt emulation")
        from passlib.hash import des_crypt, md5_crypt, sha256_crypt, sha512_crypt

        if salt.startswith("$6$"):
            return sha512_crypt.hash(word, salt=salt.split("$")[2])
        if salt.startswith("$5$"):
            return sha256_crypt.hash(word, salt=salt.split("$")[2])
        if salt.startswith("$1$"):
            return md5_crypt.hash(word, salt=salt.split("$")[2])
        return des_crypt.hash(word, salt=salt)

sys.modules["crypt"] = MockCrypt()

class MockSpwd:
    def getspnam(self, name):
        raise KeyError(f"spwd.getspnam emulation: user {name} lookup failed or not implemented")

sys.modules["spwd"] = MockSpwd()

import salt.scripts
salt.scripts.salt_call()
'

run_salt() {
  local extra_args="${1:-}"
  echo "=== Applying ${STATE} ($(date)) ==="
  echo "Log: ${LOG_FILE}"

  # Show state progress from the debug log in real-time.
  # Debug log has "Executing state X for [name]" (real-time) but only shows the
  # 'name' param (e.g. "true") not the state ID.  The stdout summary has
  # "Name: state_id - Function: ... - Result: ... - Duration: ..." with proper IDs.
  # Strategy: real-time spinner from debug, completion lines from stdout summary.
  touch "${LOG_FILE}"
  tail -f "${LOG_FILE}" | awk -v maxlen=100 '
    # Real-time progress from debug log
    match($0, /Executing state ([^ ]+) for \[([^]]+)\]/, m) {
      state_n++
      line = "▶ [" state_n "] " m[1] " " m[2]
      if (length(line) > maxlen) line = substr(line, 1, maxlen) "…"
      printf "\r\033[K%s", line
      fflush()
    }
    # Clear spinner when summary section begins
    /^local:/ {
      printf "\r\033[K"
      fflush()
    }
    # Completion from stdout summary (shows state ID, not command name)
    match($0, /^  Name: ([^ ]+) - Function: ([^ ]+) - Result: ([^ ]+) - Started: [^ ]+ - Duration: ([0-9.]+ ms)/, m) {
      dur = " (" m[4] ")"
      if (m[3] == "Changed") mark = "\033[33m✦\033[0m"
      else if (m[3] ~ /^Fail/) mark = "\033[31m✗\033[0m"
      else mark = "✓"
      name = mark " " m[1]
      cut = maxlen - length(dur) + 9  # +9 for ANSI escape chars in mark
      printf "%s%s\n", name, dur
      fflush()
    }
    # Pass through summary stats
    /^Summary for / { in_summary=1 }
    in_summary && /^[-]+$/ { print; fflush() }
    in_summary && /^(Succeeded|Failed|Total)/ { print; fflush() }
  ' &
  local tail_pid=$!

  # Run salt-call; stdout goes to log only (awk handles terminal display).
  # Use python -u for unbuffered output so summary lines reach the log immediately.
  if [[ -n "${SUDO_PASS:-}" ]]; then
    echo "$SUDO_PASS" | $SUDO_CMD "$VENV_DIR/bin/python3" -u -c "$SALT_RUNNER" \
      --config-dir="${RUNTIME_CONFIG_DIR}" \
      --local \
      --log-level=warning \
      --log-file="${LOG_FILE}" \
      --log-file-level=debug \
      --state-output=mixed_id \
      ${ACTION} ${STATE} ${extra_args} 2>&1 | tee -a "${LOG_FILE}" > /dev/null
  else
    $SUDO_CMD "$VENV_DIR/bin/python3" -u -c "$SALT_RUNNER" \
      --config-dir="${RUNTIME_CONFIG_DIR}" \
      --local \
      --log-level=warning \
      --log-file="${LOG_FILE}" \
      --log-file-level=debug \
      --state-output=mixed_id \
      ${ACTION} ${STATE} ${extra_args} 2>&1 | tee -a "${LOG_FILE}" > /dev/null
  fi
  local rc="${PIPESTATUS[0]}"

  # Give awk time to process final lines from the log
  sleep 0.3
  kill "$tail_pid" 2>/dev/null
  wait "$tail_pid" 2>/dev/null
  return "$rc"
}

# Ensure Salt is ready
bootstrap_salt
setup_config
get_sudo

if $DRY_RUN; then
  echo "--- Running ${STATE} in test mode (no changes will be applied) ---"
  run_salt "test=True"
else
  echo "--- Applying state: ${STATE} ---"
  run_salt ""
  RC=$?
  echo ""
  echo "=== Finished ${STATE} (exit code: ${RC}) at $(date) ==="
  echo "Full log: ${LOG_FILE}"
  if [[ $RC -eq 0 ]]; then
    echo "--- ${STATE}: all states passed ---"
    echo "--- Applying dotfiles (chezmoi) ---"
    chezmoi apply --force --source "${SCRIPT_DIR}/dotfiles"
  else
    echo "--- ${STATE}: some states failed (see log above) ---"
    exit $RC
  fi
fi
