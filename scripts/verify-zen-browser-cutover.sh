#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

failures=0

check() {
  local name="$1"
  shift
  if "$@"; then
    printf '[PASS] %s\n' "$name"
  else
    printf '[FAIL] %s\n' "$name"
    failures=$((failures + 1))
  fi
}

check_grep() {
  local name="$1"
  local pattern="$2"
  local file="$3"
  check "$name" grep -Fq -- "$pattern" "$file"
}

if command -v just >/dev/null 2>&1; then
  check "render gate available" just --list
else
  printf '[FAIL] render gate available\n'
  failures=$((failures + 1))
fi

check_grep "host has zen profile binding" 'zen_profile: "qnkh60k3.Default (release)"' "states/data/hosts.yaml"
check_grep \
  "hypr primary launcher uses zen" \
  "bind = \$M4, w, exec, raise --match \"class:regex=^zen$\" --launch zen-browser" \
  "dotfiles/dot_config/hypr/bindings/apps.conf"
check_grep "wayfire primary launcher uses zen" 'command_browser = raise --match "class:regex=^zen$" --launch zen-browser' "dotfiles/dot_config/wayfire.ini"
check_grep "which-key primary launcher uses zen" 'cmd: raise --match "class:regex=^zen$" --launch zen-browser' "dotfiles/dot_config/wlr-which-key/config.yaml"
check_grep "zen state deploys Surfingkeys extension" 'slug: surfingkeys_ff' "states/data/zen_browser.yaml"
check_grep "surfingkeys config keeps focus helper" "http://localhost:18888/focus" "dotfiles/dot_config/surfingkeys.js"
check_grep "surfingkeys config keeps new-tab helper" "http://localhost:18888/blank.html" "dotfiles/dot_config/surfingkeys.js"
check_grep "helper service stays enabled in user-services data" 'surfingkeys-server.service' "states/data/user_services.yaml"

if (( failures > 0 )); then
  printf '\nZen browser cutover verification failed with %d issue(s).\n' "$failures"
  exit 1
fi

printf '\nZen browser cutover verification passed.\n'
