#!/bin/bash
# One-time migration: move Transmission downloads to ~/torrent/data
# Run as: sudo bash scripts/migrate-transmission-downloads.sh
set -euo pipefail

src=/var/lib/transmission/Downloads
dst=/home/neg/torrent/data
cfg=/var/lib/transmission/.config/transmission-daemon/settings.json
user=neg

echo "=== Stopping Transmission ==="
systemctl stop transmission

echo "=== Creating target directory ==="
mkdir -p "$dst"
chown "$user:$user" "$dst"

echo "=== Contents to move ==="
ls -lh "$src/" 2>/dev/null || echo "(source dir empty or missing)"

echo "=== Moving data ==="
if [ -d "$src" ] && [ "$(ls -A "$src" 2>/dev/null)" ]; then
    mv "$src"/* "$dst/"
    chown -R "$user:$user" "$dst"
    echo "Moved $(ls "$dst" | wc -l) items"
else
    echo "(nothing to move)"
fi

echo "=== Setting ACLs ==="
setfacl -m u:transmission:rx /home/"$user"
setfacl -m u:transmission:rx /home/"$user"/torrent
setfacl -m u:transmission:rwX "$dst"
setfacl -d -m u:transmission:rwX "$dst"

echo "=== Updating settings.json ==="
python3 - "$cfg" "$dst" <<'PY'
import json, sys, pathlib
cfg = pathlib.Path(sys.argv[1])
dst = sys.argv[2]
data = json.loads(cfg.read_text())
data["download-dir"] = dst
cfg.write_text(json.dumps(data, indent=4, sort_keys=True))
print(f"  download-dir: {data['download-dir']}")
print(f"  watch-dir:    {data.get('watch-dir')}")
PY

echo "=== Starting Transmission ==="
systemctl start transmission

echo "=== Verifying ==="
sleep 1
transmission-remote -si 2>/dev/null | grep -i "download dir"
echo "=== Done ==="
