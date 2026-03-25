# Migration Scope Contract

## In Scope for This Feature

- Long-lived system services currently using bespoke repository-managed service-account provisioning
- Persistent service state, cache, and data paths required for those services to start correctly
- Ephemeral service-related paths that must be recreated automatically after boot or equivalent lifecycle resets
- Maintainer-facing repository patterns for future services that need dedicated identities and managed paths

## Explicitly Out of Scope for This Feature

- One-shot helper-script scratch directories
- Build container working directories
- Test-only temporary paths created during smoke or VM workflows
- Unrelated service refactors that do not contribute to identity or managed-path standardization
- Relocating existing service-visible data roots or renaming deployed service accounts

## Representative First-Slice Candidates

- `loki`: dedicated service identity with persistent state directories
- `adguardhome`: dedicated service identity plus service-owned configuration/state root
- `bitcoind`: dedicated service identity with stable service data root
- `mpd` FIFO handling: existing tmpfiles pattern used as a baseline for shared managed-path declarations

## Acceptance Boundary

The feature is considered ready for implementation when the first migration slice covers at least:

- one service currently using the repository's dedicated account helper
- one service with multiple persistent managed paths
- one tmpfiles-backed ephemeral resource

The feature is not required to migrate every `mkdir -p` invocation in the repository.

## Implemented First Slice

- `states/systemd_resources.sls` renders the shared `sysusers.d` and `tmpfiles.d` fragments
- `states/data/managed_resources.yaml` inventories the phase-1 service identities and paths
- `states/monitoring_loki.sls`, `states/dns.sls`, and `states/services.sls` consume the shared service-account/path ensures
- `states/mpd.sls` now relies on the shared tmpfiles inventory for `/tmp/mpd.fifo`
