# CachyOS: apply all system configuration states in one run.
# Single entry point for full system setup after bootstrap.
#
# Run:   scripts/salt-apply.sh cachyos_all
# Test:  scripts/salt-apply.sh cachyos_all --test

include:
  - cachyos
  - system_description
