# Tasks: pyinfra Migration Research

**Input**: Design documents from `/specs/030-pyinfra-migration-research/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md

**Tests**: Not applicable — research deliverable, no automated tests.

**Organization**: Tasks are grouped by user story to enable independent research and validation of each analysis dimension.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

All deliverables go to `docs/pyinfra-migration-research.md` (final report) and `specs/030-pyinfra-migration-research/` (working artifacts). PoC port goes to `specs/030-pyinfra-migration-research/poc/`.

---

## Phase 1: Setup

**Purpose**: Establish benchmarking environment and tools

- [x] T001 Install pyinfra v3.7 in isolated venv at `specs/030-pyinfra-migration-research/poc/.venv/`
- [x] T002 Capture Salt baseline: run `just profile-trend` and save output to `specs/030-pyinfra-migration-research/salt-baseline.txt`
- [x] T003 [P] Capture current `parallel: True` state list by auditing all `.sls` files in `states/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Gather raw data needed by all three user stories

**⚠️ CRITICAL**: No user story analysis can begin until baseline measurements exist

- [x] T004 Run 3x idempotent (no-change) `salt-call --local state.apply system_description` and record wall-clock times to `specs/030-pyinfra-migration-research/benchmarks/salt-noop.txt`
- [x] T005 Measure Salt state compilation time separately: run `salt-call --local state.show_lowstate` 3x and record times to `specs/030-pyinfra-migration-research/benchmarks/salt-compile.txt`
- [x] T006 [P] Extract complete list of Salt features used in codebase (require, watch, onchanges, parallel, creates, unless, onlyif, import_yaml, runas, file.managed, service.running) with occurrence counts to `specs/030-pyinfra-migration-research/salt-features-audit.md`

**Checkpoint**: Baseline data collected — user story analysis can begin

---

## Phase 3: User Story 1 - Evaluate Deployment Speed Impact (Priority: P1) 🎯 MVP

**Goal**: Produce wall-clock time comparison of Salt vs pyinfra for the three dominant workload types

**Independent Test**: Compare benchmark numbers side-by-side — speed difference should be quantified with <10% error

### Implementation for User Story 1

- [x] T007 [US1] Write minimal pyinfra deploy script for package install test (3 packages via pacman) at `specs/030-pyinfra-migration-research/poc/bench_packages.py`
- [x] T008 [US1] Write minimal pyinfra deploy script for file deploy test (3 config files via files.template) at `specs/030-pyinfra-migration-research/poc/bench_files.py`
- [x] T009 [US1] Write minimal pyinfra deploy script for service management test (enable/start 2 services) at `specs/030-pyinfra-migration-research/poc/bench_services.py`
- [x] T010 [US1] Run each pyinfra benchmark 3x with `@local` connector and record times to `specs/030-pyinfra-migration-research/benchmarks/pyinfra-results.txt`
- [x] T011 [US1] Run equivalent Salt operations 3x (matching the exact same packages/files/services) and record times to `specs/030-pyinfra-migration-research/benchmarks/salt-results.txt`
- [x] T012 [US1] Compare no-change (idempotent) apply overhead: pyinfra `@local --dry` vs `salt-call --local test=True` 3x each, record to `specs/030-pyinfra-migration-research/benchmarks/noop-comparison.txt`
- [x] T013 [US1] Write speed comparison section in `docs/pyinfra-migration-research.md` with benchmark table, methodology, and analysis (FR-001, FR-004, SC-001)

**Checkpoint**: Speed impact quantified — the core question "would pyinfra be faster?" has a data-backed answer

---

## Phase 4: User Story 2 - Assess Feature Parity Gaps (Priority: P1)

**Goal**: Map every Salt feature used in this codebase to pyinfra equivalents or document gaps

**Independent Test**: Feature gap matrix covers 100% of Salt features used; each gap has severity rating and workaround description

### Implementation for User Story 2

- [x] T014 [P] [US2] Map all 35 Salt macros to pyinfra equivalents: for each macro in `states/_macros_*.jinja`, document pyinfra equivalent or gap in `specs/030-pyinfra-migration-research/macro-mapping.md` (SC-002)
- [x] T015 [P] [US2] Document watch/onchanges migration pattern: for each of 15 watch/onchanges directives, write equivalent pyinfra code using `OperationMeta.did_change` in `specs/030-pyinfra-migration-research/watch-migration.md`
- [x] T016 [P] [US2] Quantify `parallel: True` impact: for each of 4 parallel states, estimate serial vs parallel time and total regression in `specs/030-pyinfra-migration-research/parallel-impact.md` (FR-006)
- [x] T017 [US2] Document pyinfra two-phase model limitations: write examples of install→configure patterns that break, with workarounds, in `specs/030-pyinfra-migration-research/two-phase-issues.md`
- [x] T018 [US2] Write feature gap matrix section in `docs/pyinfra-migration-research.md` consolidating T014-T017 findings (FR-002)

**Checkpoint**: Complete feature parity picture — all gaps identified with severity and workaround effort

---

## Phase 5: User Story 3 - Estimate Migration Effort and Risk (Priority: P2)

**Goal**: Produce realistic migration effort estimate backed by a proof-of-concept port

**Independent Test**: PoC port of `installers.sls` runs successfully with `pyinfra @local`; time to port is recorded; complexity categorization covers all 36 state files

### Implementation for User Story 3

- [x] T019 [US3] Port `states/installers.sls` to pyinfra at `specs/030-pyinfra-migration-research/poc/installers.py` — preserve all macro behaviors (curl_bin, pip_pkg, cargo_pkg, curl_extract_tar), retry logic, and idempotency guards (FR-003, SC-003)
- [x] T020 [US3] Run PoC port with `pyinfra @local specs/030-pyinfra-migration-research/poc/installers.py` and validate identical behavior; record porting time and issues encountered
- [x] T021 [US3] Categorize all 36 state files by migration complexity (trivial/medium/hard) with per-file time estimates in `specs/030-pyinfra-migration-research/complexity-matrix.md`
- [x] T022 [P] [US3] Assess pyinfra project health: document bus factor, contributor count, release cadence, community size in `specs/030-pyinfra-migration-research/project-health.md` (FR-005)
- [x] T023 [US3] Write migration effort and risk section in `docs/pyinfra-migration-research.md` consolidating T019-T022 findings

**Checkpoint**: Migration cost fully estimated — effort, risk, and project health assessed

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final report assembly and go/no-go recommendation

- [x] T024 Write go/no-go recommendation section in `docs/pyinfra-migration-research.md` with decision matrix backed by ≥3 quantitative data points from US1-US3 (FR-007, SC-004, SC-005)
- [x] T025 Write executive summary at top of `docs/pyinfra-migration-research.md` with key numbers and clear recommendation
- [x] T026 [P] Write Russian translation at `docs/pyinfra-migration-research.ru.md` per convention
- [x] T027 Review `docs/pyinfra-migration-research.md` for completeness against all 7 functional requirements (FR-001 through FR-007) and 5 success criteria (SC-001 through SC-005)
- [x] T028 Clean up PoC artifacts: remove `.venv/` from `specs/030-pyinfra-migration-research/poc/`, keep Python source files as reference

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup (T001 for pyinfra venv, T002 for Salt baseline)
- **US1 Speed (Phase 3)**: Depends on T001 (pyinfra installed) and T004-T005 (Salt baselines)
- **US2 Feature Gaps (Phase 4)**: Depends on T006 (feature audit) — can run in parallel with US1
- **US3 Migration Effort (Phase 5)**: Depends on T001 (pyinfra installed) — can run in parallel with US1/US2
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Depends on Foundational baselines only — no cross-story dependencies
- **User Story 2 (P1)**: Depends on T006 (feature audit) only — no cross-story dependencies
- **User Story 3 (P2)**: Depends on T001 (pyinfra installed) only — can start early

### Parallel Opportunities

- **Phase 2**: T004-T005 are sequential (same machine resource), T006 can run in parallel with T004
- **Phase 3**: T007-T009 (write PoC scripts) can run in parallel; T010-T011 must be sequential (benchmarking)
- **Phase 4**: T014, T015, T016 can all run in parallel (different analysis files)
- **Phase 5**: T022 (project health) can run in parallel with T019-T021 (PoC port)
- **Cross-phase**: US1, US2, US3 can run largely in parallel after Foundational phase

---

## Parallel Example: User Story 2

```bash
# Launch all feature analysis tasks together:
Task: "Map all 35 Salt macros to pyinfra equivalents in specs/030-pyinfra-migration-research/macro-mapping.md"
Task: "Document watch/onchanges migration patterns in specs/030-pyinfra-migration-research/watch-migration.md"
Task: "Quantify parallel: True impact in specs/030-pyinfra-migration-research/parallel-impact.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (install pyinfra, capture baselines)
2. Complete Phase 2: Foundational (Salt noop benchmarks, feature audit)
3. Complete Phase 3: User Story 1 (speed benchmarks)
4. **STOP and VALIDATE**: If speed difference is negligible (expected), the core question is already answered
5. The go/no-go may be obvious at this point — proceed to US2/US3 only for completeness

### Incremental Delivery

1. Setup + Foundational → Baselines ready
2. Add US1 (Speed) → Core question answered (MVP!)
3. Add US2 (Feature Gaps) → Full picture of migration feasibility
4. Add US3 (Effort Estimate) → Complete cost-benefit analysis
5. Polish → Final report with recommendation

### Early Exit

Given research.md already indicates NO-GO, the MVP (US1 benchmarks) may confirm this quickly. If the speed difference is within noise (<5%), consider completing only US1 + a summary recommendation and skipping US2/US3 detailed analysis.

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- All benchmarks must use 3 runs minimum for statistical validity
- PoC port (T019) should be time-boxed to 4 hours — if it takes longer, that itself is a data point
- Russian translation (T026) required per project convention
- Clean up pyinfra venv after research to avoid repo bloat
