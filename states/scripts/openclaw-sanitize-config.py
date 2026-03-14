#!/usr/bin/env python3
"""Sanitize OpenClaw config before gateway startup.

OpenClaw auto-populates models from audio/STT provider references
(e.g. Groq Whisper) with contextWindow=0 and maxTokens=0, which
fails validation on next startup. This script strips invalid model
entries (contextWindow <= 0 or maxTokens <= 0) from all providers.

Also validates JSON syntax before processing — exits 1 on invalid JSON
to prevent crash loops (systemd won't start the main process).
"""

import json
import subprocess
import sys
from pathlib import Path

CONFIG = Path.home() / ".openclaw" / "openclaw.json"

if not CONFIG.exists():
    sys.exit(0)

try:
    data = json.loads(CONFIG.read_text())
except json.JSONDecodeError as e:
    print(f"openclaw-sanitize: invalid JSON in config: {e}", file=sys.stderr)
    sys.exit(1)

providers = data.get("models", {}).get("providers", {})
changed = False

for name, prov in providers.items():
    models = prov.get("models", [])
    valid = [m for m in models if m.get("contextWindow", 0) > 0 and m.get("maxTokens", 0) > 0]
    if len(valid) != len(models):
        removed = len(models) - len(valid)
        print(f"openclaw-sanitize: removed {removed} invalid model(s) from provider '{name}'")
        prov["models"] = valid
        changed = True

if changed:
    CONFIG.write_text(json.dumps(data, indent=2) + "\n")

# Schema validation (informational — don't block startup on schema issues)
try:
    result = subprocess.run(
        ["openclaw", "config", "validate"], capture_output=True, text=True, timeout=10
    )
    if result.returncode != 0:
        print(f"openclaw-sanitize: config validate warning: {result.stderr.strip()}")
except (FileNotFoundError, subprocess.TimeoutExpired):
    pass  # openclaw binary not found or timeout — skip
