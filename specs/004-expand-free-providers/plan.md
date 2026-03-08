# Implementation Plan: Expand Free Fallback Provider Pool

**Branch**: `004-expand-free-providers` | **Date**: 2026-03-08 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-expand-free-providers/spec.md`

## Summary

Expand ProxyPilot's free fallback provider pool by adding SiliconFlow (permanent free, Chinese, sanctions-resistant) and DeepSeek (optional, trial credits, confirmed Russia access). This is a purely data-driven change — the infrastructure (Salt template, bootstrap script, Grafana dashboard, documentation) was built in 003-proxypilot-free-fallback and supports arbitrary provider count. The work involves adding entries to the YAML data file, updating Grafana queries, provisioning gopass keys, and updating documentation.

## Technical Context

**Language/Version**: Jinja2/YAML (Salt states), Bash (bootstrap script)
**Primary Dependencies**: Salt, ProxyPilot v0.3.0-dev-0.40, gopass (GPG + Yubikey)
**Storage**: N/A (config files only)
**Testing**: Manual — `just` for Salt render, `curl` for provider verification, `scripts/bootstrap-free-providers.sh --check` for key validation
**Target Platform**: CachyOS (Arch-based) workstation
**Project Type**: Configuration management (Salt states)
**Performance Goals**: N/A — fallback requests within 30s (existing SC-001 from 003)
**Constraints**: Zero monetary cost for permanent-free providers; DeepSeek is optional (trial credits)
**Scale/Scope**: Adding 2 provider entries to existing data file, ~20 lines of YAML

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Idempotency | N/A | No new `cmd.run` states — data file changes only |
| II. Network Resilience | N/A | No new network-accessing states |
| III. Secrets Isolation | PASS | New API keys stored in gopass, injected via existing bootstrap/AWK mechanism |
| IV. Macro-First | N/A | No new state patterns — reusing existing data-driven template |
| V. Minimal Change | PASS | Only data file entries, Grafana queries, and documentation |
| VI. Convention Adherence | PASS | Follows established `free_providers.yaml` schema, `[proxypilot]` commit scope, EN+RU docs |
| VII. Verification Gate | MUST | Run `just` after data file changes |
| VIII. CI Gate | MUST | Pre-commit hooks must pass |

**Result**: All gates PASS. No violations to justify.

## Project Structure

### Documentation (this feature)

```text
specs/004-expand-free-providers/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Provider research (API endpoints, models, limits)
├── data-model.md        # Provider entry schema
├── quickstart.md        # Step-by-step deployment guide
└── checklists/
    └── requirements.md  # Spec quality checklist
```

### Source Code (repository root)

```text
# Files MODIFIED (no new files created):
states/data/free_providers.yaml                    # Add SiliconFlow + DeepSeek entries
states/configs/grafana-dashboard-proxypilot.json   # Add new provider error rate queries
docs/proxypilot-free-fallback.md                   # Update provider tables + signup info
docs/proxypilot-free-fallback.ru.md                # Russian translation update
docs/secrets-scheme.md                             # Add new gopass paths
docs/secrets-scheme.ru.md                          # Russian translation update
```

**Structure Decision**: No new files — purely additive changes to existing data and documentation files. The data-driven architecture from 003 was explicitly designed for this (SC-003 from original spec: "Adding or removing a free provider requires changes to at most 2 files").
