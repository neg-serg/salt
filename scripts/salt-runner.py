#!/usr/bin/env python3
"""Salt-call wrapper with compatibility shims for Python 3.13+.

Usage:
  python3 scripts/salt-runner.py --config-dir=.salt_runtime --local state.sls ...
"""
import salt_compat

salt_compat.patch()

import salt.scripts

salt.scripts.salt_call()
