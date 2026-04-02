#!/usr/bin/env zsh
# Test script for lib-utils.zsh
# Run: zsh dotfiles/dot_local/lib/test-lib-utils.zsh

set -uo pipefail

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib-utils.zsh"

_pass=0
_fail=0

_ok() {
    printf "  PASS: %s\n" "$1"
    _pass=$(( _pass + 1 ))
}

_nok() {
    printf "  FAIL: %s\n" "$1" >&2
    _fail=$(( _fail + 1 ))
}

echo "=== lib-utils.zsh tests ==="

# Test logging (capture stderr)
echo "--- Logging ---"
_out=$(log_info "test message" 2>&1)
[[ "$_out" == *"[INFO]"*"test message"* ]] && _ok "log_info outputs INFO tag" || _nok "log_info outputs INFO tag"

_out=$(log_warn "warn message" 2>&1)
[[ "$_out" == *"[WARN]"*"warn message"* ]] && _ok "log_warn outputs WARN tag" || _nok "log_warn outputs WARN tag"

_out=$(log_error "error message" 2>&1)
[[ "$_out" == *"[ERROR]"*"error message"* ]] && _ok "log_error outputs ERROR tag" || _nok "log_error outputs ERROR tag"

# Test require_cmd
echo "--- require_cmd ---"
require_cmd zsh && _ok "require_cmd finds zsh" || _nok "require_cmd finds zsh"
require_cmd ls && _ok "require_cmd finds ls" || _nok "require_cmd finds ls"
require_cmd nonexistent_tool_xyz 2>/dev/null && _nok "require_cmd rejects missing tool" || _ok "require_cmd rejects missing tool"

# Test retry (with a command that succeeds)
echo "--- retry ---"
retry 3 true && _ok "retry succeeds on first try" || _nok "retry succeeds on first try"

# Test retry (with a command that fails)
retry 1 false 2>/dev/null && _nok "retry fails after max attempts" || _ok "retry fails after max attempts"

echo ""
echo "=== Results: $_pass passed, $_fail failed ==="
exit $(( _fail > 0 ? 1 : 0 ))
