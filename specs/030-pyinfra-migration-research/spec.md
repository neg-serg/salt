# Feature Specification: pyinfra Migration Research

**Feature Branch**: `030-pyinfra-migration-research`
**Created**: 2026-03-15
**Status**: Draft
**Input**: User description: "github.com/pyinfra-dev/pyinfra - исследуй насколько можно было бы ускорить выкатку, если бы я перешел с salt на него, может быть есть бенчмарки"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Evaluate Deployment Speed Impact (Priority: P1)

As a workstation administrator running Salt masterless on a single CachyOS machine, I want a clear, data-backed comparison of Salt vs pyinfra execution speed for my specific workload profile (36 state files, package installs, binary downloads, service management) so I can make an informed migration decision.

**Why this priority**: The core question — "would pyinfra be faster?" — must be answered first with concrete data, not marketing claims. Without this, all other migration analysis is premature.

**Independent Test**: Can be validated by running a representative subset of operations (package install, file deploy, service restart) under both tools on the same machine and measuring wall-clock time.

**Acceptance Scenarios**:

1. **Given** the existing Salt state tree (36 SLS files), **When** profiling a full `salt-call --local state.apply`, **Then** a breakdown of time spent in state compilation vs actual execution (pacman, curl, makepkg) is produced.
2. **Given** equivalent pyinfra deploy scripts for the same operations, **When** running `pyinfra @local deploy.py`, **Then** wall-clock times are comparable and the difference is attributable to specific architectural factors (not marketing claims).
3. **Given** both tools running the same idempotent no-change apply, **When** measuring overhead of state evaluation alone, **Then** the compilation/evaluation overhead difference is quantified (expected: <5% of total apply time).

---

### User Story 2 - Assess Feature Parity Gaps (Priority: P1)

As a workstation administrator relying on Salt's declarative dependency graph, watch/onchanges triggers, and single-host parallel execution, I want to know which Salt features have no pyinfra equivalent so I can estimate the true cost of migration.

**Why this priority**: Speed is meaningless if the migration breaks critical workflows. Feature gaps determine whether migration is feasible at all.

**Independent Test**: Can be validated by mapping each Salt feature used in the 36 state files to pyinfra equivalents (or documenting the gap) in a comparison matrix.

**Acceptance Scenarios**:

1. **Given** the Salt macro library (5 macro files with 25+ macros), **When** analyzing pyinfra's operation system, **Then** each macro is classified as: direct equivalent, achievable with workaround, or not possible.
2. **Given** states using `watch`/`onchanges` for service restart on config change, **When** evaluating pyinfra's `OperationMeta.did_change`, **Then** the verbosity increase and reliability trade-offs are documented.
3. **Given** states using `parallel: True` for concurrent downloads, **When** evaluating pyinfra's execution model, **Then** the loss of single-host parallelism is quantified (number of affected states, estimated time impact).

---

### User Story 3 - Estimate Migration Effort and Risk (Priority: P2)

As a workstation administrator maintaining a mature Salt codebase, I want a realistic effort estimate for porting to pyinfra so I can weigh the cost against any potential benefits.

**Why this priority**: Even if pyinfra offered marginal speed gains, a 3-5 week migration with regression risk may not be justified.

**Independent Test**: Can be validated by porting a representative state file (e.g., `installers.sls` — data-driven, uses macros, has retry/parallel) to pyinfra and measuring the actual porting time and resulting code quality.

**Acceptance Scenarios**:

1. **Given** the 36 Salt state files grouped by complexity, **When** estimating migration effort, **Then** each file is categorized (trivial/medium/hard) with time estimates and risk factors.
2. **Given** a proof-of-concept port of one representative state, **When** comparing the Salt and pyinfra versions, **Then** code maintainability, readability, and test coverage differences are documented.
3. **Given** the single-maintainer nature of pyinfra (bus factor = 1), **When** assessing long-term viability, **Then** the project health risk is compared to Salt's enterprise-backed (but Broadcom-neglected) ecosystem.

---

### Edge Cases

- What happens when pyinfra's two-phase execution model encounters interdependent states (operation B depends on operation A's result)? pyinfra gathers facts at prepare time, not between operations — this breaks install-then-configure patterns.
- How does pyinfra handle gopass secret retrieval failures? Salt has `ignore_retcode` + fallback patterns; pyinfra would need manual try/except blocks.
- What happens to `creates:`/`unless:` idempotency guards? Each becomes a Python lambda in `_if`, increasing verbosity and error surface.
- How does pyinfra handle systemd user services? Salt's `runas` parameter has a direct pyinfra equivalent (`_su_user`), but user service scope (`--user`) may require manual `XDG_RUNTIME_DIR` handling.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Research MUST produce a wall-clock time comparison of Salt vs pyinfra for the three dominant workload types: package installation, binary download, and service configuration.
- **FR-002**: Research MUST identify all Salt features used in the current 36-file state tree that have no direct pyinfra equivalent, with workaround complexity rated (trivial/medium/hard/impossible).
- **FR-003**: Research MUST include a proof-of-concept port of at least one representative state file to pyinfra, demonstrating real (not theoretical) migration patterns.
- **FR-004**: Research MUST evaluate pyinfra's `@local` connector performance specifically (not SSH benchmarks), since the target is a single masterless workstation.
- **FR-005**: Research MUST assess pyinfra project health (bus factor, release cadence, community size) as a long-term maintenance risk factor.
- **FR-006**: Research MUST quantify the impact of losing `parallel: True` for single-host concurrent downloads, with affected state count and estimated time regression.
- **FR-007**: Research MUST produce a go/no-go recommendation with clear criteria and data backing.

### Key Entities

- **Benchmark Profile**: A standardized test scenario (operation type, count, dependencies) used to compare both tools under identical conditions.
- **Feature Gap Matrix**: A mapping of Salt features to pyinfra equivalents with gap severity and workaround effort.
- **Migration Complexity Score**: Per-state-file assessment of porting difficulty based on Salt features used.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Deployment speed difference between Salt and pyinfra for a full idempotent (no-change) apply is measured with <10% measurement error.
- **SC-002**: All 25+ Salt macros are mapped to pyinfra equivalents or documented as gaps, covering 100% of the macro surface.
- **SC-003**: At least one state file is fully ported to pyinfra with identical observable behavior, validating the migration pattern.
- **SC-004**: A clear go/no-go recommendation is produced, backed by at least 3 quantitative data points (speed, effort, risk).
- **SC-005**: The research document is actionable — a reader can decide whether to proceed with migration without additional investigation.

## Assumptions

- The comparison focuses on single-host masterless execution, not multi-host orchestration.
- pyinfra v3.x (latest stable) is the comparison target.
- Salt performance is baselined using existing `just profile-trend` data from the current state tree.
- Network-bound operations (package downloads, binary fetches) dominate total apply time — state compilation overhead is expected to be <5% of wall-clock time.
- The existing `parallel: True` annotations on download states provide measurable speedup that would be lost in pyinfra.
