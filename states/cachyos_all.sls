# CachyOS: apply all system configuration states in one run.
# Single entry point for full system setup after bootstrap.
#
# Run:   ./apply_cachyos.sh cachyos_all
# Test:  ./apply_cachyos.sh cachyos_all --dry-run

include:
  - cachyos
  - system_description
