#!/usr/bin/env bash
# bootstrap-free-providers.sh — seed ProxyPilot config with free provider API keys
#
# gopass requires user-level GPG agent access (Yubikey), which is not available
# in Salt's root/sudo context. This script runs as the user to:
#   1. Read API keys from gopass
#   2. Inject the openai-compatibility section into the existing proxypilot config
#
# After this bootstrap, subsequent `just` runs maintain the keys via AWK fallback.
#
# Usage:
#   scripts/bootstrap-free-providers.sh          # inject keys
#   scripts/bootstrap-free-providers.sh --check  # verify keys exist

set -euo pipefail

CONFIG="${HOME}/.config/proxypilot/config.yaml"
DATA_FILE="$(dirname "$0")/../states/data/free_providers.yaml"

if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: ProxyPilot config not found at $CONFIG"
    echo "Run 'just' first to render the initial config, then re-run this script."
    exit 1
fi

if [[ ! -f "$DATA_FILE" ]]; then
    echo "ERROR: Free providers data file not found at $DATA_FILE"
    exit 1
fi

# Parse provider names and gopass keys from YAML (simple awk, no yq dependency)
declare -A PROVIDERS
current_name=""
while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*\"(.+)\" ]]; then
        current_name="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]*gopass_key:[[:space:]]*\"(.+)\" ]] && [[ -n "$current_name" ]]; then
        PROVIDERS["$current_name"]="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]*dummy_key: ]]; then
        current_name=""  # skip local providers
    fi
done < "$DATA_FILE"

if [[ "${1:-}" == "--check" ]]; then
    echo "Checking gopass keys for free providers..."
    all_ok=true
    for name in "${!PROVIDERS[@]}"; do
        key_path="${PROVIDERS[$name]}"
        if gopass show -o "$key_path" >/dev/null 2>&1; then
            echo "  OK: $name ($key_path)"
        else
            echo "  MISSING: $name ($key_path)"
            all_ok=false
        fi
    done
    if $all_ok; then
        echo "All keys present."
    else
        echo "Some keys missing. Run: gopass insert <path>"
        exit 1
    fi
    exit 0
fi

# Build the openai-compatibility section
echo "Resolving API keys from gopass..."
section="openai-compatibility:"
any_resolved=false

# Read providers in priority order from the data file
# Note: model-level `- name:` must be checked BEFORE provider-level `- name:`
# because both match the same regex; the $in_models guard differentiates them.
current_name=""
current_base_url=""
current_key=""
current_models=()
in_models=false
model_name=""

flush_provider() {
    if [[ -n "$current_name" ]] && [[ -n "$current_key" ]]; then
        section+=$'\n'"  - name: \"$current_name\""
        section+=$'\n'"    base-url: \"$current_base_url\""
        section+=$'\n'"    api-key-entries:"
        section+=$'\n'"      - api-key: \"$current_key\""
        section+=$'\n'"    models:"
        for m in "${current_models[@]}"; do
            IFS='|' read -r mname malias <<< "$m"
            section+=$'\n'"      - name: \"$mname\""
            section+=$'\n'"        alias: \"$malias\""
        done
        echo "  OK: $current_name"
        any_resolved=true
    elif [[ -n "$current_name" ]]; then
        echo "  SKIP: $current_name (no key resolved)"
    fi
}

while IFS= read -r line; do
    # Model entries (6+ leading spaces distinguishes from provider-level `- name:`)
    if $in_models && [[ "$line" == "      "* ]] && [[ "$line" =~ -[[:space:]]*name:[[:space:]]*\"(.+)\" ]]; then
        model_name="${BASH_REMATCH[1]}"
    elif $in_models && [[ "$line" == "      "* ]] && [[ "$line" =~ alias:[[:space:]]*\"(.+)\" ]]; then
        model_alias="${BASH_REMATCH[1]}"
        current_models+=("$model_name|$model_alias")
    # Models section marker
    elif [[ "$line" =~ ^[[:space:]]*models: ]]; then
        in_models=true
    # New provider entry — flush previous, start new
    elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*\"(.+)\" ]]; then
        flush_provider
        current_name="${BASH_REMATCH[1]}"
        current_base_url=""
        current_key=""
        current_models=()
        in_models=false
    elif [[ "$line" =~ ^[[:space:]]*base_url:[[:space:]]*\"(.+)\" ]]; then
        current_base_url="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]*gopass_key:[[:space:]]*\"(.+)\" ]]; then
        key_path="${BASH_REMATCH[1]}"
        current_key=$(gopass show -o "$key_path" 2>/dev/null || true)
        if [[ -z "$current_key" ]]; then
            echo "  SKIP: $current_name (gopass key '$key_path' not found)"
        fi
    elif [[ "$line" =~ ^[[:space:]]*dummy_key:[[:space:]]*\"(.+)\" ]]; then
        current_key="${BASH_REMATCH[1]}"
    fi
done < "$DATA_FILE"

# Flush last provider
flush_provider

if ! $any_resolved; then
    echo "ERROR: No provider keys resolved. Check gopass."
    exit 1
fi

# Replace or insert the openai-compatibility section in the config
if grep -q '^openai-compatibility:' "$CONFIG"; then
    # Remove existing section (from openai-compatibility: to next top-level key)
    tmpfile=$(mktemp)
    awk '
        /^openai-compatibility:/ { skip=1; next }
        skip && /^[a-z]/ { skip=0 }
        !skip { print }
    ' "$CONFIG" > "$tmpfile"
    # Insert new section before payload: (or at end)
    if grep -q '^# ── Payload rules' "$tmpfile"; then
        sed -i "/^# ── Payload rules/i\\
$(echo "$section" | sed 's/$/\\/' | sed '$ s/\\$//')
" "$tmpfile"
    else
        echo "" >> "$tmpfile"
        echo "$section" >> "$tmpfile"
    fi
    mv "$tmpfile" "$CONFIG"
    chmod 600 "$CONFIG"
else
    # No existing section — insert before payload rules
    if grep -q '^# ── Payload rules' "$CONFIG"; then
        tmpfile=$(mktemp)
        awk -v sect="$section" '
            /^# ── Payload rules/ { print sect; print "" }
            { print }
        ' "$CONFIG" > "$tmpfile"
        mv "$tmpfile" "$CONFIG"
        chmod 600 "$CONFIG"
    else
        echo "" >> "$CONFIG"
        echo "$section" >> "$CONFIG"
    fi
fi

echo ""
echo "Done. ProxyPilot config updated at $CONFIG"
echo "Run 'systemctl --user restart proxypilot' to apply."
echo "Subsequent 'just' runs will maintain these keys via AWK fallback."
