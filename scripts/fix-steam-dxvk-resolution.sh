#!/usr/bin/env bash
# Fix DXVK resolution detection for all Steam Proton game prefixes
# This ensures games properly enumerate all available display modes instead of only seeing 1920x1080
#
# Issue: DXVK (D3D11 implementation in Proton) sometimes fails to query complete resolution list from Xrandr
# This particularly affects UE4 games which cache the initial resolution list at startup
#
# Solution:
# 1. Register the correct desktop resolution in wine registry
# 2. Create DXVK config with flags to force proper mode enumeration
# 3. This applies globally to all game prefixes

set -eo pipefail

STEAM_DIR="$HOME/.steam/root/steamapps/compatdata"

if [ ! -d "$STEAM_DIR" ]; then
    echo "Error: Steam directory not found at $STEAM_DIR"
    exit 1
fi

echo "========================================="
echo "Fixing DXVK resolution detection"
echo "========================================="

FIXED_COUNT=0
TOTAL_COUNT=0

for prefix_dir in "$STEAM_DIR"/*/pfx; do
    [ -d "$prefix_dir" ] || continue
    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    game_id=$(basename "$(dirname "$prefix_dir")")
    echo ""
    echo "[$game_id] Processing prefix..."

    # 1. Update wine registry with correct desktop resolution
    echo "  → Setting desktop resolution in registry..."
    WINEPREFIX="$prefix_dir" wine reg add "HKEY_CURRENT_USER\Software\Wine\Explorer\Desktops" \
        /v Default /d "3840x2160" /f 2>/dev/null && echo "    ✓ Registry updated" || echo "    ⚠ Registry update skipped"

    # 2. Create DXVK config
    DXVK_CONFIG="$prefix_dir/dxvk.conf"
    if [ -f "$DXVK_CONFIG" ]; then
        echo "  → dxvk.conf already exists (skipping)"
    else
        echo "  → Creating dxvk.conf..."
        cat > "$DXVK_CONFIG" << 'EOF'
# DXVK Configuration for proper display mode enumeration
# Fixes issue where games only see subset of available resolutions
# This is especially important for high-resolution displays (4K, ultrawide)
#
# These settings:
# - d3d11.enumerateDisplayModes = 1: Force enumeration of all display modes
# - d3d11.allowDiscard = True: Ensure proper resource cleanup
# - dxgi.deferSurfaceCreation = 0: Don't defer surface creation to improve resolution detection

d3d11.allowDiscard = True
d3d11.enumerateDisplayModes = 1
dxgi.deferSurfaceCreation = 0
EOF
        echo "    ✓ dxvk.conf created"
        FIXED_COUNT=$((FIXED_COUNT + 1))
    fi
done

echo ""
echo "========================================="
echo "Summary:"
echo "  Total prefixes: $TOTAL_COUNT"
echo "  New DXVK configs: $FIXED_COUNT"
echo "========================================="
echo ""
echo "✓ Done! Changes will take effect next time you start a game."
echo ""
echo "Note: If you still only see 1920x1080 in game settings:"
echo "  1. Verify your monitor is connected and xrandr shows 4K:"
echo "     $ xrandr | head -20"
echo "  2. Delete game cache to force redetection:"
echo "     $ rm -rf ~/.steam/root/steamapps/compatdata/GAMEID/pfx/drive_c/users/steamuser/AppData/Local/*"
echo "  3. Restart the game"
