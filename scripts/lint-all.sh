#!/usr/bin/env bash
set -uo pipefail

errors=0

for tool in .venv/bin/ruff shellcheck yamllint .venv/bin/python3; do
    if ! command -v "$tool" &>/dev/null && [ ! -x "$tool" ]; then
        echo "ERROR: mandatory tool not found: $tool" >&2
        exit 1
    fi
done

HAS_SALT_LINT=false
if [ -x .venv/bin/salt-lint ]; then
    HAS_SALT_LINT=true
else
    echo "WARN: salt-lint not found in .venv — skipping salt-lint checks"
fi

HAS_TAPLO=false
if command -v taplo &>/dev/null; then
    HAS_TAPLO=true
else
    echo "WARN: taplo not found — skipping TOML checks"
fi

run_check() {
    local name="$1"
    shift
    echo "--- $name ---"
    if "$@"; then
        echo "  OK"
    else
        echo "  FAIL: $name" >&2
        ((errors++))
    fi
}

run_check "ruff check" .venv/bin/ruff check .
run_check "ruff format" .venv/bin/ruff format --check .
run_check "lint-jinja" .venv/bin/python3 scripts/lint-jinja.py
run_check "lint-dotfiles" .venv/bin/python3 scripts/lint-dotfiles.py
run_check "lint-ownership" .venv/bin/python3 scripts/lint-ownership.py
run_check "lint-units" .venv/bin/python3 scripts/lint-units.py
run_check "lint-qml" .venv/bin/python3 scripts/lint-qml.py
run_check "lint-docs" .venv/bin/python3 scripts/lint-docs.py

sc_files=()
while IFS= read -r -d "" path; do
    first=$(head -n1 "$path")
    case "$first" in
        "#!/usr/bin/env bash"*|"#!/bin/bash"*|"#!/usr/bin/env sh"*|"#!/bin/sh"*|"#!/usr/bin/env dash"*|"#!/bin/dash"*)
            sc_files+=("$path")
            ;;
    esac
done < <(find scripts states/scripts tests -maxdepth 1 -name "*.sh" -print0 2>/dev/null)

if [ ${#sc_files[@]} -gt 0 ]; then
    run_check "shellcheck" shellcheck -e SC2129 "${sc_files[@]}"
else
    echo "--- shellcheck ---"
    echo "  No bash/sh scripts to check"
fi

run_check "yamllint" yamllint states/data/*.yaml states/configs/*.yaml .github/workflows/*.yaml

if $HAS_SALT_LINT; then
    run_check "salt-lint" .venv/bin/salt-lint states/*.sls
fi

if $HAS_TAPLO; then
    mapfile -t toml_files < <(
        find . -name '*.toml' -not -path './.venv/*' -not -path './.salt_runtime/*' 2>/dev/null
    )
    if [ "${#toml_files[@]}" -gt 0 ]; then
        run_check "taplo" taplo check "${toml_files[@]}"
    fi
fi

if [ "$errors" -gt 0 ]; then
    echo ""
    echo "FAIL: $errors lint check(s) failed" >&2
    exit 1
fi

echo ""
echo "All lint checks passed"
