#!/usr/bin/env zsh
# Fix DXVK resolution detection for all Proton prefixes.
# Ensures games properly enumerate all available display modes.
# Issue: DXVK sometimes reports only a subset of resolutions to games.
# Expects DXVK_RESOLUTION env var (e.g. "3840x2160"), defaults to native.
set -eo pipefail

RESOLUTION="${DXVK_RESOLUTION:-3840x2160}"

changed=0
for prefix in ~/.steam/root/steamapps/compatdata/*/pfx; do
  [ -d "$prefix" ] || continue
  if [ ! -f "$prefix/dxvk.conf" ]; then
    WINEPREFIX="$prefix" wine reg add \
      "HKEY_CURRENT_USER\Software\Wine\Explorer\Desktops" \
      /v Default /d "$RESOLUTION" /f 2>/dev/null || true
    printf '%s\n' \
      'd3d11.allowDiscard = True' \
      'd3d11.enumerateDisplayModes = 1' \
      'dxgi.deferSurfaceCreation = 0' \
      > "$prefix/dxvk.conf"
    changed=$((changed + 1))
  fi
done
[ "$changed" -gt 0 ] && echo "Configured $changed prefix(es)" || echo "All prefixes already configured"
