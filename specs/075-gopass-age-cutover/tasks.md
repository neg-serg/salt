# Tasks: Gopass Age Cutover

**Input**: Design documents from `/specs/075-gopass-age-cutover/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Validation tasks are required because this feature performs a live operational cutover. They are expressed as baseline capture, post-cutover verification, rollback acceptance, and stabilization evidence rather than new unit tests.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each migration increment.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Freeze the working surface for the live cutover and create the evidence files that every later phase will update.

- [X] T001 Create the baseline evidence scaffold in `/home/neg/src/salt/specs/075-gopass-age-cutover/baseline.md`
- [X] T002 Create the rollback package manifest in `/home/neg/src/salt/specs/075-gopass-age-cutover/rollback-package.md`
- [X] T003 Create the cutover execution log in `/home/neg/src/salt/specs/075-gopass-age-cutover/cutover-log.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Capture the pre-cutover state and prepare rollback inputs that block all user-story work.

**⚠️ CRITICAL**: No user story work should begin until this phase is complete.

- [X] T004 Record the current host backend markers, `gopass` session status, and validation boundary in `/home/neg/src/salt/specs/075-gopass-age-cutover/baseline.md`
- [X] T005 [P] Capture the representative secret consumer inventory and special-entry subset in `/home/neg/src/salt/specs/075-gopass-age-cutover/baseline.md`
- [X] T006 [P] Create the live-store backup and history snapshot from `/home/neg/.local/share/pass` under `/tmp/gopass-age-cutover-backup/` and record the artifact locations in `/home/neg/src/salt/specs/075-gopass-age-cutover/rollback-package.md`
- [X] T007 Record the written rollback steps, legacy unlock materials, and activation order in `/home/neg/src/salt/specs/075-gopass-age-cutover/rollback-package.md`

**Checkpoint**: Baseline evidence and rollback package are complete enough to fail closed before any live conversion.

---

## Phase 3: User Story 1 - Complete Live Cutover (Priority: P1) 🎯 MVP

**Goal**: Switch the active store to `age` now, keep the `gopass` interface stable, and restore `chezmoi apply` in the current user session.

**Independent Test**: The active store at `/home/neg/.local/share/pass` uses the new backend, representative `gopass` reads still match baseline, and `chezmoi apply --force --source /home/neg/src/salt/dotfiles` succeeds in the same user session.

### Implementation for User Story 1

- [X] T008 [P] [US1] Update age cutover and current-session unlock guidance in `/home/neg/src/salt/docs/gopass-setup.md` and `/home/neg/src/salt/docs/gopass-setup.ru.md`
- [X] T009 [P] [US1] Update apply-time age recovery messaging in `/home/neg/src/salt/scripts/salt-apply.sh`
- [ ] T010 [US1] Generate or register the password-protected age unlock artifacts for the active store and record their recovery handling in `/home/neg/src/salt/specs/075-gopass-age-cutover/rollback-package.md`
- [ ] T011 [US1] Convert the active store in `/home/neg/.local/share/pass` from `.gpg-id` to `.age-recipients` and record the exact cutover steps in `/home/neg/src/salt/specs/075-gopass-age-cutover/cutover-log.md`
- [ ] T012 [US1] Run representative post-cutover `gopass` reads for the frozen validation set and capture baseline equivalence results in `/home/neg/src/salt/specs/075-gopass-age-cutover/cutover-log.md`
- [ ] T013 [US1] Re-run `chezmoi apply --force --source /home/neg/src/salt/dotfiles` and capture same-session success or failure details in `/home/neg/src/salt/specs/075-gopass-age-cutover/cutover-log.md`

**Checkpoint**: User Story 1 is complete when the active store is age-backed and the first post-cutover `chezmoi apply` succeeds in the same session.

---

## Phase 4: User Story 2 - Fail-Closed Recovery (Priority: P2)

**Goal**: Ensure the live cutover can be reversed cleanly if any cutover validation fails.

**Independent Test**: The rollback package can restore the previous active store, representative secret reads match baseline again, and the post-rollback `chezmoi` path is usable in the current session.

### Implementation for User Story 2

- [X] T014 [P] [US2] Update rollback-package, failure-trigger, and live-cutover recovery guidance in `/home/neg/src/salt/docs/deploy-cachyos.md` and `/home/neg/src/salt/docs/deploy-cachyos.ru.md`
- [X] T015 [P] [US2] Update operator rollback hints and backup-package cues in `/home/neg/src/salt/scripts/deploy-cachyos.sh`
- [X] T016 [US2] Create the rollback acceptance evidence file in `/home/neg/src/salt/specs/075-gopass-age-cutover/rollback-evidence.md`
- [ ] T017 [US2] Exercise one rollback trigger against the live-cutover workflow and record the recovery outcome in `/home/neg/src/salt/specs/075-gopass-age-cutover/rollback-evidence.md`
- [ ] T018 [US2] Re-run representative secret reads and the `chezmoi` workflow after rollback or rollback rehearsal and record acceptance results in `/home/neg/src/salt/specs/075-gopass-age-cutover/rollback-evidence.md`

**Checkpoint**: User Story 2 is complete when rollback evidence proves the previous working store can become the active source of truth again without mixed-state ambiguity.

---

## Phase 5: User Story 3 - Stabilize and Retire Legacy Access (Priority: P3)

**Goal**: Track the 7-day observation window and make legacy-path retirement depend on recorded evidence instead of ad hoc judgment.

**Independent Test**: The operator can review one stabilization log and determine whether legacy access may be retired without guessing about fallback use or unresolved failures.

### Implementation for User Story 3

- [X] T019 [P] [US3] Update stabilization-window and legacy-retirement criteria in `/home/neg/src/salt/docs/secrets-scheme.md` and `/home/neg/src/salt/docs/secrets-scheme.ru.md`
- [X] T020 [P] [US3] Align deployment-facing stabilization guidance in `/home/neg/src/salt/docs/deploy-cachyos.md`, `/home/neg/src/salt/docs/deploy-cachyos.ru.md`, and `/home/neg/src/salt/scripts/deploy-cachyos.sh`
- [X] T021 [US3] Create the stabilization tracking log in `/home/neg/src/salt/specs/075-gopass-age-cutover/stabilization-log.md`
- [ ] T022 [US3] Record required day-to-day secret-dependent workflows, fallback observations, and unresolved-failure tracking in `/home/neg/src/salt/specs/075-gopass-age-cutover/stabilization-log.md`
- [ ] T023 [US3] Record the final legacy-retirement decision and supporting evidence in `/home/neg/src/salt/specs/075-gopass-age-cutover/stabilization-log.md`

**Checkpoint**: User Story 3 is complete when legacy retirement is governed by the recorded 7-day stabilization evidence.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final consistency checks across docs, evidence, and repo validation.

- [ ] T024 [P] Sync cross-links and cutover terminology across `/home/neg/src/salt/docs/gopass-setup.md`, `/home/neg/src/salt/docs/gopass-setup.ru.md`, `/home/neg/src/salt/docs/secrets-scheme.md`, `/home/neg/src/salt/docs/secrets-scheme.ru.md`, `/home/neg/src/salt/docs/deploy-cachyos.md`, and `/home/neg/src/salt/docs/deploy-cachyos.ru.md`
- [X] T025 Run `just validate` and record the result in `/home/neg/src/salt/specs/075-gopass-age-cutover/verification.md`
- [ ] T026 Re-run `chezmoi apply --force --source /home/neg/src/salt/dotfiles` and record the final verification result in `/home/neg/src/salt/specs/075-gopass-age-cutover/verification.md`
- [ ] T027 Validate the implemented operator flow against `/home/neg/src/salt/specs/075-gopass-age-cutover/quickstart.md` and record any final wording fixes in `/home/neg/src/salt/specs/075-gopass-age-cutover/verification.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; can start immediately.
- **Foundational (Phase 2)**: Depends on Setup; blocks all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational completion.
- **User Story 2 (Phase 4)**: Depends on User Story 1 because rollback evidence depends on the live cutover workflow and its acceptance boundary.
- **User Story 3 (Phase 5)**: Depends on User Story 1 because stabilization starts only after successful live cutover acceptance.
- **Polish (Phase 6)**: Depends on all selected user stories being complete.

### User Story Dependencies

- **US1 (P1)**: First deliverable; no dependency on other stories after Foundational.
- **US2 (P2)**: Builds on US1 because rollback acceptance must validate the same live cutover and `chezmoi` recovery path.
- **US3 (P3)**: Builds on US1 because stabilization evidence begins only after successful cutover.

### Parallel Opportunities

- T005 and T006 can run in parallel.
- T008 and T009 can run in parallel.
- T014 and T015 can run in parallel.
- T019 and T020 can run in parallel.
- T024 can run in parallel with verification preparation once all story-specific edits land.

---

## Parallel Example: User Story 1

```bash
# Parallelize the repo-side age cutover prep:
Task: "Update age cutover and current-session unlock guidance in /home/neg/src/salt/docs/gopass-setup.md and /home/neg/src/salt/docs/gopass-setup.ru.md"
Task: "Update apply-time age recovery messaging in /home/neg/src/salt/scripts/salt-apply.sh"
```

---

## Parallel Example: User Story 2

```bash
# Parallelize rollback-facing doc and script updates:
Task: "Update rollback-package, failure-trigger, and live-cutover recovery guidance in /home/neg/src/salt/docs/deploy-cachyos.md and /home/neg/src/salt/docs/deploy-cachyos.ru.md"
Task: "Update operator rollback hints and backup-package cues in /home/neg/src/salt/scripts/deploy-cachyos.sh"
```

---

## Parallel Example: User Story 3

```bash
# Parallelize stabilization guidance updates:
Task: "Update stabilization-window and legacy-retirement criteria in /home/neg/src/salt/docs/secrets-scheme.md and /home/neg/src/salt/docs/secrets-scheme.ru.md"
Task: "Align deployment-facing stabilization guidance in /home/neg/src/salt/docs/deploy-cachyos.md, /home/neg/src/salt/docs/deploy-cachyos.ru.md, and /home/neg/src/salt/scripts/deploy-cachyos.sh"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational.
3. Complete Phase 3: User Story 1.
4. Stop and validate that `/home/neg/.local/share/pass` is age-backed and that `chezmoi apply --force --source /home/neg/src/salt/dotfiles` succeeds in the same session.

### Incremental Delivery

1. Finish Setup + Foundational to freeze the live validation and rollback boundary.
2. Deliver US1 to complete the live cutover and immediate `chezmoi` recovery.
3. Deliver US2 to prove the workflow fails closed and can recover cleanly.
4. Deliver US3 to turn stabilization and legacy retirement into evidence-based decisions.
5. Finish Polish with repo validation, final `chezmoi` verification, and quickstart walkthrough validation.

### Suggested MVP Scope

- Phase 1
- Phase 2
- Phase 3 (US1 only)

This yields the smallest valuable increment: the workstation actually moves to `age` and the blocked dotfile apply path is restored immediately.

## Notes

- All tasks follow the required checklist format: checkbox, task ID, optional `[P]`, required `[US#]` for story tasks, and exact file paths.
- Operational evidence is stored alongside the feature in `/home/neg/src/salt/specs/075-gopass-age-cutover/` so cutover, rollback, and stabilization results remain auditable.
- Validation is operational rather than unit-test-driven, so `just validate`, representative `gopass` reads, and `chezmoi apply` are the final acceptance gates.
