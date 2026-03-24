# Tasks: Salt Refactor Program

**Input**: Design documents from `/specs/071-salt-refactor-program/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Include validation and contract-test tasks because the specification explicitly requires stronger regression detection.

**Organization**: Tasks are grouped by user story so each story can be implemented and validated independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (`US1`, `US2`, `US3`)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Capture baseline and establish task scaffolding before refactor changes.

- [ ] T001 [US1] Capture baseline validation output with `just lint`, `just validate`, `just render-matrix`, and `pytest tests/` before code changes.
- [ ] T002 [US1] Review current contracts and refactor scope in [spec.md](/home/neg/src/salt/specs/071-salt-refactor-program/spec.md), [plan.md](/home/neg/src/salt/specs/071-salt-refactor-program/plan.md), and [contracts/user-services-schema.yaml](/home/neg/src/salt/specs/071-salt-refactor-program/contracts/user-services-schema.yaml).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared plumbing required before user-story implementation can proceed safely.

**CRITICAL**: User story work should build on these common baselines.

- [ ] T003 [US1] Audit existing helper coverage in [states/_macros_install.jinja](/home/neg/src/salt/states/_macros_install.jinja) and [states/_macros_service.jinja](/home/neg/src/salt/states/_macros_service.jinja) against FR-002 and FR-006.
- [ ] T004 [US2] Define shared shell bootstrap interface in [contracts/runtime-bootstrap-shell.md](/home/neg/src/salt/specs/071-salt-refactor-program/contracts/runtime-bootstrap-shell.md) and verify it matches current callers in [scripts/salt-apply.sh](/home/neg/src/salt/scripts/salt-apply.sh) and [scripts/salt-validate.sh](/home/neg/src/salt/scripts/salt-validate.sh).
- [ ] T005 [US3] Define CI performance-gate acceptance mapping from [contracts/performance-gate.md](/home/neg/src/salt/specs/071-salt-refactor-program/contracts/performance-gate.md) to [scripts/state-profiler.py](/home/neg/src/salt/scripts/state-profiler.py) and [.github/workflows/salt-ci.yaml](/home/neg/src/salt/.github/workflows/salt-ci.yaml).

**Checkpoint**: Shared contracts and helper boundaries are clear; user stories can proceed.

---

## Phase 3: User Story 1 - Stabilize shared state patterns (Priority: P1) 🎯 MVP

**Goal**: Remove fragile state-level duplication and centralize repeated render logic.

**Independent Test**: Render and validate `openclaw_agent`, `video_ai`, and `user_services`; verify runtime-dir resolution, shared download macro usage, and YAML-driven service filtering behave correctly.

### Tests for User Story 1

- [x] T006 [P] [US1] Add/extend contract coverage for YAML-tagged user services in [tests/test_data_crossrefs.py](/home/neg/src/salt/tests/test_data_crossrefs.py) against [states/data/user_services.yaml](/home/neg/src/salt/states/data/user_services.yaml).
- [x] T007 [P] [US1] Add render-contract coverage for critical macro-driven states via [scripts/lint-jinja.py](/home/neg/src/salt/scripts/lint-jinja.py) or a dedicated test file under `tests/` for [states/openclaw_agent.sls](/home/neg/src/salt/states/openclaw_agent.sls), [states/video_ai.sls](/home/neg/src/salt/states/video_ai.sls), and [states/user_services.sls](/home/neg/src/salt/states/user_services.sls).

### Implementation for User Story 1

- [x] T008 [US1] Replace remaining hardcoded runtime-dir references in [states/openclaw_agent.sls](/home/neg/src/salt/states/openclaw_agent.sls) and [states/units/user/salt-monitor.service](/home/neg/src/salt/states/units/user/salt-monitor.service) using `host.runtime_dir` or equivalent template context.
- [x] T009 [US1] Implement a narrow Hugging Face/shared download macro path in [states/_macros_install.jinja](/home/neg/src/salt/states/_macros_install.jinja) that preserves retry/cache/version/idempotency rules from FR-002.
- [x] T010 [US1] Migrate model download blocks in [states/video_ai.sls](/home/neg/src/salt/states/video_ai.sls) to the shared macro path and align related artifact handling in [states/llama_embed.sls](/home/neg/src/salt/states/llama_embed.sls) if needed.
- [x] T011 [US1] Refactor [states/data/user_services.yaml](/home/neg/src/salt/states/data/user_services.yaml) to encode feature tags and enable/start metadata for `UserServiceUnitEntry`.
- [x] T012 [US1] Rewrite filtering logic in [states/user_services.sls](/home/neg/src/salt/states/user_services.sls) to derive deploy/enable/disable sets from YAML tags instead of parallel Jinja lists.
- [x] T013 [US1] Update [docs/salt-refactoring-recommendations.md](/home/neg/src/salt/docs/salt-refactoring-recommendations.md) with the stabilized-pattern items and explicit `safe now` vs `requires validation` classification.
- [x] T014 [US1] Run `just validate` plus targeted renders for `openclaw_agent`, `video_ai`, and `user_services`, and confirm SC-001 through SC-003.

**Checkpoint**: User Story 1 is independently functional and testable as the MVP refactor slice.

---

## Phase 4: User Story 2 - Improve workflow maintainability (Priority: P2)

**Goal**: Remove drift between orchestration scripts and move complex task-runner shell code out of `Justfile`.

**Independent Test**: Run `just validate`, `just lint`, and direct script calls to verify unchanged behavior and output semantics.

### Tests for User Story 2

- [x] T015 [P] [US2] Add script-level regression checks or assertions covering runtime bootstrap behavior for [scripts/salt-apply.sh](/home/neg/src/salt/scripts/salt-apply.sh) and [scripts/salt-validate.sh](/home/neg/src/salt/scripts/salt-validate.sh).
- [x] T016 [P] [US2] Add/adjust lint-pipeline verification so `just lint` delegation to [scripts/lint-all.sh](/home/neg/src/salt/scripts/lint-all.sh) is validated.

### Implementation for User Story 2

- [x] T017 [US2] Extract shared Salt runtime bootstrap helpers into a new shell module under `scripts/` and update [scripts/salt-apply.sh](/home/neg/src/salt/scripts/salt-apply.sh) to consume it.
- [x] T018 [US2] Update [scripts/salt-validate.sh](/home/neg/src/salt/scripts/salt-validate.sh) to consume the same shared bootstrap module while preserving its validation-specific options.
- [x] T019 [US2] Create [scripts/lint-all.sh](/home/neg/src/salt/scripts/lint-all.sh) with behavior equivalent to the current `Justfile` lint recipe.
- [x] T020 [US2] Simplify [Justfile](/home/neg/src/salt/Justfile) so `just lint` delegates to [scripts/lint-all.sh](/home/neg/src/salt/scripts/lint-all.sh) without changing exit semantics.
- [x] T021 [US2] Run `just lint`, `just validate`, and direct script invocations to verify FR-004 and FR-005.

**Checkpoint**: User Story 2 is independently functional and script/workflow maintenance is improved.

---

## Phase 5: User Story 3 - Add regression and performance guardrails (Priority: P3)

**Goal**: Add stronger refactor safety nets through helper extraction, contract tests, perf gating, and explicit modularization.

**Independent Test**: Run unit/contract checks and CI-equivalent performance comparison to confirm semantic and timing regressions are detected.

### Tests for User Story 3

- [x] T022 [P] [US3] Add contract tests for service-config helper behavior in `tests/` covering repeated config-change service patterns from [states/services.sls](/home/neg/src/salt/states/services.sls).
- [x] T023 [P] [US3] Add performance-gate verification coverage for [scripts/state-profiler.py](/home/neg/src/salt/scripts/state-profiler.py) and workflow wiring in [.github/workflows/salt-ci.yaml](/home/neg/src/salt/.github/workflows/salt-ci.yaml).
- [x] T024 [P] [US3] Add render/id-collision checks for planned include decomposition of [states/video_ai.sls](/home/neg/src/salt/states/video_ai.sls) and [states/desktop.sls](/home/neg/src/salt/states/desktop.sls).

### Implementation for User Story 3

- [x] T025 [US3] Implement a narrow config-mutation plus controlled restart/reload helper in [states/_macros_service.jinja](/home/neg/src/salt/states/_macros_service.jinja) and migrate only truly repeated patterns in [states/services.sls](/home/neg/src/salt/states/services.sls).
- [x] T026 [US3] Extend [scripts/lint-jinja.py](/home/neg/src/salt/scripts/lint-jinja.py) and/or dedicated tests to enforce macro/render contracts for critical states per FR-007.
- [x] T027 [US3] Extend [scripts/state-profiler.py](/home/neg/src/salt/scripts/state-profiler.py) as needed for deterministic CI comparison output matching [contracts/performance-gate.md](/home/neg/src/salt/specs/071-salt-refactor-program/contracts/performance-gate.md).
- [x] T028 [US3] Update [.github/workflows/salt-ci.yaml](/home/neg/src/salt/.github/workflows/salt-ci.yaml) to run the performance gate for refactor-relevant paths and surface pass/fail/inconclusive status.
- [x] T029 [US3] Decompose [states/video_ai.sls](/home/neg/src/salt/states/video_ai.sls) into a small number of explicit thematic include files while preserving readability and state-ID uniqueness.
- [x] T030 [US3] Decompose [states/desktop.sls](/home/neg/src/salt/states/desktop.sls) into a small number of explicit thematic include files while preserving readability and state-ID uniqueness.
- [x] T031 [US3] Run `pytest tests/`, `just validate`, `just render-matrix`, and profiler comparison checks to verify FR-006 through FR-009 and SC-004 through SC-005.

**Checkpoint**: User Story 3 is independently functional with guardrails in place.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final consistency pass across all user stories.

- [x] T032 [P] [US1] Update [docs/salt-refactoring-recommendations.md](/home/neg/src/salt/docs/salt-refactoring-recommendations.md) with final status, validation evidence, and adoption order for all ten refactor items.
- [x] T033 [P] [US2] Re-run [quickstart.md](/home/neg/src/salt/specs/071-salt-refactor-program/quickstart.md) end-to-end and correct any drift between documented and actual commands.
- [x] T034 [US3] Run full verification set (`just lint`, `pytest tests/`, `just validate`, `just render-matrix`) and record outcome against success criteria in the feature docs or PR notes.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1: Setup**: starts immediately.
- **Phase 2: Foundational**: depends on Phase 1 and defines shared boundaries.
- **Phase 3: US1**: starts after Phase 2 and delivers the MVP refactor slice.
- **Phase 4: US2**: starts after Phase 2; can proceed after US1 or in parallel where there is no file overlap.
- **Phase 5: US3**: starts after Phases 2 and 3; some tasks also depend on US2 script extraction.
- **Phase 6: Polish**: depends on all desired user stories being complete.

### User Story Dependencies

- **US1 (P1)**: no dependency on other stories after foundational work.
- **US2 (P2)**: independent from US1 functionally, but shares repo-wide validation baseline.
- **US3 (P3)**: depends on stabilized helper boundaries from US1 and shared workflow structure from US2 for the cleanest rollout.

### Parallel Opportunities

- T006 and T007 can run in parallel.
- T015 and T016 can run in parallel.
- T022, T023, and T024 can run in parallel.
- T032 and T033 can run in parallel.

## Implementation Strategy

### MVP First

1. Complete Setup and Foundational phases.
2. Complete all US1 tasks.
3. Validate runtime-dir normalization, download macro unification, and data-driven user-services behavior.
4. Stop and verify MVP refactor slice before moving on.

### Incremental Delivery

1. Deliver US1 as the lowest-risk refactor wave.
2. Deliver US2 to reduce workflow and maintenance drift.
3. Deliver US3 to strengthen guardrails and modularity once the core refactor is stable.

## Notes

- `[P]` means different files and no blocking dependencies.
- Do not begin SLS decomposition before render-contract checks are in place.
- Preserve explicit include topology; avoid metadata-generated include graphs.
- Verification work is part of completion, not an optional follow-up.
