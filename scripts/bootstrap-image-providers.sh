#!/usr/bin/env bash
# bootstrap-image-providers.sh — seed image provider API keys into gopass
#
# Mirrors bootstrap-free-providers.sh for the image generation roster.
# Reads provider names and gopass_key entries from image_providers.yaml,
# skips dummy_key providers (local ComfyUI).
#
# Usage:
#   scripts/bootstrap-image-providers.sh          # seed missing keys interactively
#   scripts/bootstrap-image-providers.sh --check  # verify which keys exist
#   scripts/bootstrap-image-providers.sh --force  # overwrite existing keys

set -euo pipefail

DATA_FILE="$(dirname "$0")/../states/data/image_providers.yaml"

if [[ ! -f "$DATA_FILE" ]]; then
    echo "ERROR: Image providers data file not found at $DATA_FILE"
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

if [[ ${#PROVIDERS[@]} -eq 0 ]]; then
    echo "No cloud providers found in $DATA_FILE"
    exit 0
fi

FORCE=false
CHECK=false
for arg in "$@"; do
    case "$arg" in
        --check) CHECK=true ;;
        --force) FORCE=true ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

if $CHECK; then
    echo "Checking gopass keys for image providers..."
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
        echo ""
        echo "Missing keys. Run without --check to seed them:"
        echo "  scripts/bootstrap-image-providers.sh"
    fi
    exit 0
fi

echo "Seeding API keys for image providers..."
echo ""

for name in "${!PROVIDERS[@]}"; do
    key_path="${PROVIDERS[$name]}"

    if ! $FORCE && gopass show -o "$key_path" >/dev/null 2>&1; then
        echo "  SKIP: $name ($key_path) — already exists (use --force to overwrite)"
        continue
    fi

    echo "  INSERT: $name"
    echo "  Path: $key_path"
    case "$name" in
        together-ai)
            echo "  Get key at: https://api.together.xyz/settings/api-keys"
            ;;
        huggingface)
            echo "  Get token at: https://huggingface.co/settings/tokens"
            ;;
        cloudflare)
            echo "  Get token at: https://dash.cloudflare.com/profile/api-tokens"
            echo "  (Also set account_id in image_providers.yaml)"
            ;;
    esac
    echo ""

    if ! gopass insert "$key_path"; then
        echo "  ERROR: failed to insert $key_path" >&2
        continue
    fi
    echo "  Done: $name"
    echo ""
done

echo ""
echo "Bootstrap complete. Run 'just apply image_generation' to deploy."
echo "Subsequent 'just' runs will maintain keys via AWK fallback."
