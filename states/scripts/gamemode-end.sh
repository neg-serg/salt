#!/bin/bash
set -euo pipefail
# GameMode end hook: log session end.
# Environment variables are process-scoped and die with the game process.
# GPU power profile is reverted by GameMode automatically (amd_performance_level).

logger -t gamemode-end "Gaming session ended"
