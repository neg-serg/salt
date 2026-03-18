#!/usr/bin/env bash
# Convert an XCursor theme to native hyprcursor format.
# Usage: ./scripts/convert-hyprcursor.sh [theme-dir]
# Default: ~/.local/share/icons/Alkano-aio
#
# Requires: hyprcursor-util, xcur2png (pacman -S xcur2png)
# After conversion: hyprctl reload
set -euo pipefail

theme_dir="${1:-$HOME/.local/share/icons/Alkano-aio}"
theme_name=$(basename "$theme_dir")
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

if [[ ! -d "$theme_dir/cursors" ]]; then
    echo "Error: $theme_dir/cursors not found" >&2
    exit 1
fi

for cmd in hyprcursor-util xcur2png; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd not found. Install it first." >&2
        exit 1
    fi
done

echo "Extracting XCursor theme from $theme_dir..."
mkdir -p "$tmp_dir/extracted" "$tmp_dir/compiled"
hyprcursor-util -x "$theme_dir" -o "$tmp_dir/extracted"

extracted="$tmp_dir/extracted/extracted_${theme_name}"
if [[ ! -d "$extracted" ]]; then
    echo "Error: extraction failed — $extracted not found" >&2
    exit 1
fi

# Fix theme name in manifest
sed -i "s/^name = .*/name = ${theme_name}/" "$extracted/manifest.hl"
sed -i "s/^description = .*/description = ${theme_name} cursor theme (hyprcursor)/" "$extracted/manifest.hl"

echo "Compiling hyprcursor theme..."
hyprcursor-util -c "$extracted" -o "$tmp_dir/compiled"

compiled="$tmp_dir/compiled/theme_${theme_name}"
if [[ ! -d "$compiled/hyprcursors" ]]; then
    echo "Error: compilation failed" >&2
    exit 1
fi

shapes=$(find "$compiled/hyprcursors/" -maxdepth 1 -name '*.hlc' | wc -l)
echo "Installing $shapes cursor shapes to $theme_dir..."
cp -r "$compiled/hyprcursors" "$theme_dir/"
cp "$compiled/manifest.hl" "$theme_dir/"

echo "Done. Run 'hyprctl reload' to activate."
