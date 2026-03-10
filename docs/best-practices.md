# Salt Best Practices — Implemented

This document summarizes the best practices audit and improvements implemented for the Salt configuration repo.

## Context

After researching modern Salt best practices (2024–2025), we identified gaps between our setup and industry standards, ranked them by impact and effort, then implemented the top 6.

**Already strong before this audit**: data-driven YAML architecture, DRY macros (6 Jinja2 files), idempotency guards, network resilience patterns, gopass secrets, 7 custom linters, feature-matrix rendering, bilingual documentation.

**Declined**: salt-lint (our `lint-jinja.py` at 1178 lines already far exceeds salt-lint's scope).

## Implemented Improvements

### 1. Pre/Post-Apply Btrfs Snapshots

Every `just apply` automatically creates snapper pre/post snapshot pairs, providing instant rollback capability.

- **How**: `salt-apply.sh` calls `snapper create --type pre/post` around state execution
- **Rollback**: `just rollback` reverts to the last pre-apply snapshot
- **Graceful**: Skipped silently if snapper is unavailable

### 2. Automated Drift Detection

A daily systemd timer compares declared packages against installed packages and sends a desktop notification on drift.

- **Timer**: `salt-drift.timer` (daily, persistent)
- **Service**: `salt-drift.service` runs `drift-notify.sh`
- **Notification**: `notify-send` on drift detected
- **Logs**: `logs/drift-YYYY-MM-DD.log`
- **On-demand**: `just pkg-drift`

### 3. Dependency Graph Visualization

Generate a visual graph of all state dependencies (include/require/watch/onchanges).

- **Command**: `just dep-graph` (opens SVG), `just dep-graph --format text` (tree)
- **Output**: DOT format, SVG via graphviz, or text tree
- **Cycle detection**: Warns on circular dependencies
- **Script**: `scripts/dep-graph.py`

### 4. Container Smoke Tests

Podman-based test that applies states in isolation and validates outcomes.

- **Command**: `just smoke-test`
- **Image**: `archlinux:latest`
- **Tests**: State rendering validation for all 36+ states, safe state execution, assertions
- **Script**: `tests/smoke-test.sh`

### 5. State Profiling Trends

Extended state profiler with trend analysis across multiple apply logs.

- **Trend**: `just profile-trend` — min/max/avg/latest duration per state across all logs
- **Compare**: `just profile-compare LOG1 LOG2` — highlights regressions (>20% slower)
- **Script**: `scripts/state-profiler.py` (extended)

### 6. Unified Health Check

Single command to check all managed services.

- **Command**: `just health`
- **Checks**: System services, user services, HTTP healthcheck endpoints
- **Output**: Colored table, `--json`, or `--quiet` (exit code only)
- **Script**: `scripts/health-check.sh`

## New Justfile Recipes

| Recipe | Description |
|--------|-------------|
| `rollback` | Revert to last pre-apply snapshot |
| `dep-graph` | Generate state dependency graph |
| `smoke-test` | Container-based smoke tests |
| `profile-trend` | State duration trends across logs |
| `profile-compare LOG1 LOG2` | Compare two apply logs |
| `health` | Check all managed service health |
