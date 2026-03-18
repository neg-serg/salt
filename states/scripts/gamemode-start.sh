#!/bin/bash
set -euo pipefail
# GameMode start hook: set game-scoped environment variables
# These affect all Vulkan applications so they are NOT set globally.
# GameMode exports them only for the game process tree.

export RADV_PERFTEST=gpl,sam

logger -t gamemode-start "Gaming session started: RADV_PERFTEST=${RADV_PERFTEST}"
