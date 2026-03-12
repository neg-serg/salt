#!/usr/bin/env python3
"""Sanitize OpenClaw config before gateway startup.

OpenClaw auto-populates models from audio/STT provider references
(e.g. Groq Whisper) with contextWindow=0 and maxTokens=0, which
fails validation on next startup. This script strips invalid model
entries (contextWindow <= 0 or maxTokens <= 0) from all providers.
"""

import json
import sys
from pathlib import Path

CONFIG = Path.home() / ".openclaw" / "openclaw.json"

if not CONFIG.exists():
    sys.exit(0)

data = json.loads(CONFIG.read_text())
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
