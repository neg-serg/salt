# Tasks: Sysusers and Tmpfiles Adoption

**Input**: Design documents from `/specs/074-sysusers-tmpfiles-adoption/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: No dedicated test-first tasks were generated because the specification did not request a TDD workflow. Validation tasks still include repository checks and representative lifecycle verification.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the shared data and state scaffolding for declarative systemd-managed resources

- [x] T001 Create managed resource inventory file in `states/data/managed_resources.yaml`
- [x] T002 [P] Create sysusers fragment template in `states/configs/managed-service-accounts.conf.j2`
- [x] T003 [P] Create tmpfiles fragment template in `states/configs/managed-service-paths.conf.j2`
- [x] T004 Create shared orchestration state for managed resources in `states/systemd_resources.sls`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build the shared macros, includes, and rendering path that all user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Extend shared rendering macros for managed identities and paths in `states/_macros_service.jinja`
- [x] T006 Wire the shared managed resource state into the top-level orchestrator in `states/system_description.sls`
- [x] T007 Update the managed resource contract to match the implemented data shape in `specs/074-sysusers-tmpfiles-adoption/contracts/managed-resource-contract.yaml`
- [x] T008 Add render-level validation coverage for generated managed resource fragments in `tests/test_render_contracts.py`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Provision service identities declaratively (Priority: P1) 🎯 MVP

**Goal**: Replace bespoke dedicated service account provisioning with declarative sysusers-backed definitions for the first migration slice

**Independent Test**: Apply the repository on a machine missing representative migrated service accounts and confirm the accounts are materialized once and re-apply cleanly without duplicate-account failures.

### Implementation for User Story 1

- [x] T009 [US1] Record phase-1 service identity inventory entries in `states/data/managed_resources.yaml`
- [x] T010 [P] [US1] Replace the Loki dedicated account helper with the shared managed identity pattern in `states/monitoring_loki.sls`
- [x] T011 [P] [US1] Replace the AdGuardHome dedicated account helper with the shared managed identity pattern in `states/dns.sls`
- [x] T012 [P] [US1] Replace the Bitcoind dedicated account helper with the shared managed identity pattern in `states/services.sls`
- [x] T013 [US1] Remove or refactor legacy `system_daemon_user` account provisioning paths in `states/_macros_service.jinja`
- [x] T014 [US1] Add representative identity lifecycle verification for migrated services in `tests/test_render_contracts.py`

**Checkpoint**: At this point, representative dedicated service accounts should be fully declarative and independently verifiable

---

## Phase 4: User Story 2 - Materialize service filesystem paths predictably (Priority: P2)

**Goal**: Move representative persistent and ephemeral service resources to the shared tmpfiles-backed managed path pattern

**Independent Test**: Remove representative managed paths, trigger apply or lifecycle recreation, and confirm the paths return with the expected owner, group, mode, and type before dependent services use them.

### Implementation for User Story 2

- [x] T015 [US2] Add persistent and ephemeral managed path inventory entries for phase-1 services in `states/data/managed_resources.yaml`
- [x] T016 [P] [US2] Replace Loki directory provisioning with the shared managed path pattern in `states/monitoring_loki.sls`
- [x] T017 [P] [US2] Replace AdGuardHome service-owned path provisioning with the shared managed path pattern in `states/dns.sls`
- [x] T018 [P] [US2] Replace MPD FIFO tmpfiles handling with the shared managed path pattern in `states/mpd.sls`
- [x] T019 [US2] Reconcile Bitcoind service data-root ownership through the shared managed path pattern in `states/services.sls`
- [x] T020 [US2] Add representative persistent and ephemeral path recreation coverage in `tests/test_render_contracts.py`

**Checkpoint**: At this point, representative persistent directories and ephemeral resources should be recreated predictably through the shared policy

---

## Phase 5: User Story 3 - Keep service onboarding and maintenance consistent (Priority: P3)

**Goal**: Make the new identity/path pattern the default maintainer-facing workflow for future services and clarify migration boundaries

**Independent Test**: Review the shared data contract and maintainer guidance, then confirm a maintainer can identify how to add a new dedicated service identity and managed path without tracing legacy helper logic.

### Implementation for User Story 3

- [x] T021 [US3] Document the implemented migration boundary and representative first-slice coverage in `specs/074-sysusers-tmpfiles-adoption/contracts/migration-scope.md`
- [x] T022 [US3] Add maintainer guidance for declarative managed resources in `docs/salt-best-practices.md`
- [x] T023 [US3] Update inline macro documentation to point maintainers at the new managed resource workflow in `states/_macros_service.jinja`
- [x] T024 [US3] Align the implementation quickstart with the final maintainer workflow in `specs/074-sysusers-tmpfiles-adoption/quickstart.md`

**Checkpoint**: Maintainers can onboard or update representative services using one documented identity/path pattern

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup across all user stories

- [x] T025 [P] Refresh feature plan artifacts to match delivered implementation details in `specs/074-sysusers-tmpfiles-adoption/plan.md`
- [x] T026 Run repository validation commands from `specs/074-sysusers-tmpfiles-adoption/quickstart.md`
- [x] T027 [P] Update feature notes with final migration decisions in `specs/074-sysusers-tmpfiles-adoption/research.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion - delivers the MVP
- **User Story 2 (Phase 4)**: Depends on Foundational completion and benefits from User Story 1 identity inventory being in place
- **User Story 3 (Phase 5)**: Depends on the shared framework and should follow the implemented workflow from User Stories 1 and 2
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - no dependency on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) but should land after US1 to reuse the same service inventory and representative slice
- **User Story 3 (P3)**: Depends on the implemented shared workflow from US1 and US2

### Within Each User Story

- Inventory updates before service migrations
- Shared macro/state changes before per-service replacements
- Representative service migrations before documentation updates
- Validation tasks after the corresponding implementation tasks in each story

### Parallel Opportunities

- T002 and T003 can run in parallel after T001 is understood
- T010, T011, and T012 can run in parallel once T009 establishes the phase-1 identity inventory
- T016, T017, and T018 can run in parallel once T015 establishes the phase-1 path inventory
- T025 and T027 can run in parallel after implementation is complete

---

## Parallel Example: User Story 1

```bash
# Launch representative service identity migrations together after the shared inventory exists:
Task: "Replace the Loki dedicated account helper with the shared managed identity pattern in states/monitoring_loki.sls"
Task: "Replace the AdGuardHome dedicated account helper with the shared managed identity pattern in states/dns.sls"
Task: "Replace the Bitcoind dedicated account helper with the shared managed identity pattern in states/services.sls"
```

---

## Parallel Example: User Story 2

```bash
# Launch representative managed path migrations together after the shared path inventory exists:
Task: "Replace Loki directory provisioning with the shared managed path pattern in states/monitoring_loki.sls"
Task: "Replace AdGuardHome service-owned path provisioning with the shared managed path pattern in states/dns.sls"
Task: "Replace MPD FIFO tmpfiles handling with the shared managed path pattern in states/mpd.sls"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Confirm representative service identities are declarative and re-apply cleanly

### Incremental Delivery

1. Complete Setup + Foundational → shared managed resource framework is ready
2. Add User Story 1 → validate representative service identity provisioning
3. Add User Story 2 → validate persistent and ephemeral managed path recreation
4. Add User Story 3 → validate maintainer onboarding and repository guidance
5. Finish with Polish → run repository validation and refresh feature notes

### Parallel Team Strategy

With multiple developers:

1. One developer completes Setup + Foundational
2. Once the shared framework is ready:
   - Developer A: US1 service identity migrations
   - Developer B: US2 managed path migrations
   - Developer C: US3 maintainer guidance updates after workflow stabilizes

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [US1] through [US3] labels map directly to the user stories in `spec.md`
- Every task includes an exact file path for immediate execution
- Suggested MVP scope: Phase 3 / User Story 1 only
