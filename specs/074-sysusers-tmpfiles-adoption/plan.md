# Implementation Plan: Sysusers and Tmpfiles Adoption

**Branch**: `074-sysusers-tmpfiles-adoption` | **Date**: 2026-03-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/074-sysusers-tmpfiles-adoption/spec.md`

## Summary

Plan a repository-wide migration from bespoke Salt-managed service account and filesystem setup toward declarative `systemd-sysusers` and `systemd-tmpfiles` ownership. The implementation will replace the current `system_daemon_user` pattern and scattered managed-path setup for in-scope long-lived services with standardized declarations, while preserving existing service names, data locations, idempotent applies, and boot-time path recreation behavior.

## Implementation Snapshot

- `states/systemd_resources.sls` now renders and applies the shared `sysusers.d` and `tmpfiles.d` fragments
- `states/data/managed_resources.yaml` inventories the phase-1 identities and managed paths
- `states/monitoring_loki.sls`, `states/dns.sls`, `states/services.sls`, and `states/mpd.sls` now depend on shared managed-resource ensures instead of bespoke account/tmpfiles setup
- `tests/test_render_contracts.py` verifies the shared state inclusion, inventory coverage, and representative service adoption

## Technical Context

**Language/Version**: Jinja2 + YAML Salt states, Python 3, Bash/Zsh helper scripts  
**Primary Dependencies**: Salt 3006.x masterless workflow, existing `_macros_*.jinja`, systemd, Arch/CachyOS package management, repository-managed unit/config trees  
**Storage**: Repository-managed Salt states, config templates, unit files, and generated `sysusers.d` / `tmpfiles.d` policy fragments on the target machine  
**Testing**: `just validate`, `just lint`, rendered-state inspection, targeted `pytest` coverage where repository helpers change, and service-footprint verification on representative migrated services  
**Target Platform**: CachyOS/Arch-based Linux workstation with systemd and long-lived Salt-managed services  
**Project Type**: Configuration-management repository with operator-run applies and service lifecycle management  
**Performance Goals**: Repeated applies stay failure-free on already compliant machines, representative missing identities/paths are restored in one run, and boot-time recreation of ephemeral service paths remains automatic  
**Constraints**: Preserve idempotency, use macro-first repository patterns, avoid speculative migration of one-shot helper-script directories, keep service-visible locations stable, and limit scope to in-repository service identity/path management  
**Scale/Scope**: One workstation profile, one repository-wide identity/path policy, a first migration set of existing long-lived services, and updated maintainer conventions for future services

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Research Gate

| Principle | Status | Notes |
| --------- | ------ | ----- |
| I. Idempotency | PASS | Migration goal is to preserve or improve repeatable applies by replacing duplicate-prone account/path setup with declarative policies |
| II. Network Resilience | PASS | Feature is local-system focused and does not introduce new network acquisition behavior beyond existing package/state flows |
| III. Secrets Isolation | PASS | No new secrets or secret-handling paths are introduced |
| IV. Macro-First | PASS | Design will replace the current account helper with repository-standard macros or data-driven declarations instead of adding more bespoke state logic |
| V. Minimal Change | PASS | Scope is constrained to service identities, managed paths, and the related maintainer workflow |
| VI. Convention Adherence | PASS | Planned artifacts fit existing `states/`, `tests/`, `docs/`, and `specs/` layout with explicit service-domain ownership |
| VII. Verification Gate | PASS | Implementation acceptance will require `just` validation plus representative migrated-service checks |
| VIII. CI Gate | PASS | No CI exception is proposed; normal repository validation remains required |

### Gate Decision

No constitutional blockers remain. Planning can proceed as long as implementation keeps migration scope focused on long-lived managed services and preserves the repository's idempotent apply expectations.

## Project Structure

### Documentation (this feature)

```text
specs/074-sysusers-tmpfiles-adoption/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
    ├── managed-resource-contract.yaml
    └── migration-scope.md
```

### Source Code (repository root)

```text
states/
├── _imports.jinja
├── _macros_service.jinja
├── configs/
│   ├── managed-service-accounts.conf.j2
│   ├── managed-service-paths.conf.j2
│   └── ...
├── data/
│   ├── managed_resources.yaml
│   └── ...
├── units/
│   └── ...
├── dns.sls
├── monitoring_loki.sls
├── mpd.sls
├── systemd_resources.sls
└── services.sls

scripts/
├── salt-apply.sh
├── salt-runtime.sh
├── salt-validate.sh
└── ...

tests/
├── contract/
├── integration/
└── ...

docs/
└── ...
```

**Structure Decision**: Keep the existing repository layout. Implement the migration inside the current service-domain Salt tree and shared macros, with feature-specific design artifacts living only under `specs/074-sysusers-tmpfiles-adoption/`. No new top-level module or subsystem is needed.

## Delivery Strategy

### Phase A: Footprint Inventory and Boundary Definition

1. Inventory existing long-lived services that currently rely on `system_daemon_user`, ad-hoc `file.directory`, or hand-managed tmpfiles behavior.
2. Separate in-scope service resources from out-of-scope helper-script and test-only temporary paths.
3. Document which existing service resources can move directly to declarative policies without changing service-visible locations.

### Phase B: Policy Shape and Macro Design

1. Define the repository-facing data shape for managed service identities and managed path rules.
2. Design the macro or helper pattern that renders those declarations into `sysusers.d` and `tmpfiles.d` artifacts consistently.
3. Define how persistent directories, ephemeral runtime paths, FIFOs, and pre-existing directories with ownership requirements are represented.

### Phase C: Migration Strategy for Existing Services

1. Select representative services for the first migration slice, including at least one current `system_daemon_user` consumer and one current tmpfiles-style path.
2. Define sequencing so identity declarations, path declarations, and dependent service states remain operable throughout the migration.
3. Define how existing mismatched users, groups, or directories are reconciled without introducing duplicate-account failures.

### Phase D: Verification and Maintainer Adoption

1. Define validation coverage for render checks, linting, and representative lifecycle checks on migrated services.
2. Define the maintainer-facing contract for adding future services under the new policy.
3. Capture quickstart guidance for local verification after implementation.

## Validation Plan

- Render validation: confirm the migrated state tree renders cleanly with `just validate`
- Lint validation: confirm any new Salt, YAML, or shell artifacts pass `just lint`
- Identity validation: confirm representative migrated service identities are created once and re-apply cleanly
- Managed-path validation: confirm representative persistent and ephemeral paths are materialized with correct ownership and recreated when removed
- Regression validation: confirm migrated services still start with their expected service-visible locations unchanged

## Post-Design Constitution Re-Check

| Principle | Status | Notes |
| --------- | ------ | ----- |
| I. Idempotency | PASS | Design makes identity/path provisioning declarative and keeps re-apply behavior explicit in validation |
| II. Network Resilience | PASS | No new network-dependent logic is introduced by the design |
| III. Secrets Isolation | PASS | Design does not add secrets or change secret-consumer behavior |
| IV. Macro-First | PASS | Design centers on shared macros/data contracts rather than per-service custom state logic |
| V. Minimal Change | PASS | Design explicitly excludes one-shot helper-script scratch directories from the first migration phase |
| VI. Convention Adherence | PASS | Planned files remain within established service-domain and shared-helper conventions |
| VII. Verification Gate | PASS | Quickstart and validation plan require local repository validation before implementation is accepted |
| VIII. CI Gate | PASS | Planned implementation remains subject to the normal CI and local validation gates |

Implementation completed with repository validation passing.
