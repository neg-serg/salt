#!/bin/bash
set -euo pipefail
# Headless SuperDirt quark install via sclang
# Downloads SuperDirt quark + Dirt-Samples (~2GB) from Codeberg
# QT_QPA_PLATFORM=offscreen prevents sclang from requiring a display server

export QT_QPA_PLATFORM=offscreen

tmpfile=$(mktemp /tmp/superdirt-install-XXXXXX.scd)
trap 'rm -f "$tmpfile"' EXIT

cat > "$tmpfile" << 'SCD'
Quarks.checkForUpdates({
    Quarks.install("SuperDirt", "v1.7.4");
    "=== SuperDirt installed ===".postln;
    0.exit;
});
SCD

sclang "$tmpfile"
