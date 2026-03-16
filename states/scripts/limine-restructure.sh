#!/bin/bash
# Restructure limine.conf: move boot entries from multi-profile sub-entries
# to flat top-level entries so that timeout auto-boot works.
#
# Before: /CachyOS → //CachyOS LTS (directory — timeout opens submenu)
# After:  /CachyOS LTS (flat — timeout boots directly) + /CachyOS (snapshots)
set -euo pipefail

LIMINE="/boot/limine.conf"

# Already restructured?
if rg -q '^/CachyOS LTS' "$LIMINE"; then
    echo "Already restructured"
    exit 0
fi

# Validate expected structure
if ! rg -q '^/CachyOS$' "$LIMINE"; then
    echo "ERROR: /CachyOS entry not found in $LIMINE" >&2
    exit 1
fi

cp "$LIMINE" "${LIMINE}.pre-restructure"

# Extract the //CachyOS LTS entry block (4-space indented fields after the heading)
LTS_BLOCK=$(awk '
    /^    \/\/CachyOS LTS$/ { found=1; next }
    found && /^    \/\// { exit }
    found && /^$/ { exit }
    found { print }
' "$LIMINE")

# Extract the //CachyOS LTS (fallback) entry block
FB_BLOCK=$(awk '
    /^    \/\/CachyOS LTS \(fallback\)$/ { found=1; next }
    found && /^    \/\// { exit }
    found && /^$/ { exit }
    found { print }
' "$LIMINE")

if [[ -z "$LTS_BLOCK" || -z "$FB_BLOCK" ]]; then
    echo "ERROR: Could not extract entry blocks from $LIMINE" >&2
    cp "${LIMINE}.pre-restructure" "$LIMINE"
    exit 1
fi

# Get the /CachyOS directory section (from /CachyOS to end of file)
DIRECTORY=$(sed -n '/^\/CachyOS$/,$ p' "$LIMINE")

# Write restructured config
TMPFILE=$(mktemp)
cat > "$TMPFILE" << 'HEADER'
timeout: 1
default_entry: 1
interface_branding: CachyOS

HEADER

# Flat top-level entries (auto-boot targets)
printf '/CachyOS LTS\n%s\n\n' "$LTS_BLOCK" >> "$TMPFILE"
printf '/CachyOS LTS (fallback)\n%s\n\n' "$FB_BLOCK" >> "$TMPFILE"

# Preserve the /CachyOS directory with templates + snapshots
printf '%s\n' "$DIRECTORY" >> "$TMPFILE"

# Atomic replace (preserves inode)
cat "$TMPFILE" > "$LIMINE"
rm -f "$TMPFILE"

echo "Restructured limine.conf: flat boot entries + snapshot directory"
echo "Backup: ${LIMINE}.pre-restructure"
