# Tasks: Zen Browser Cutover

**Input**: Design documents from `/specs/077-zen-browser-cutover/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: No strict test-first workflow was requested. This task list still includes targeted regression and verification tasks because the specification explicitly requires proving the launcher, profile, helper service, and runtime Surfingkeys workflow all work after the cutover.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the shared regression and verification scaffolding for the browser cutover

- [X] T001 Create launcher regression test scaffold in `tests/test_browser_launch_targets.py`
- [X] T002 [P] Create Zen Surfingkeys contract regression test scaffold in `tests/test_surfingkeys_zen_contract.py`
- [X] T003 [P] Create operator verification script scaffold in `scripts/verify-zen-browser-cutover.sh`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Align shared browser-state assumptions, host coverage, and operator documentation before any user story work

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Extend dual-browser host-model coverage for `floorp_profile`, `zen_profile`, and primary/secondary browser expectations in `tests/test_host_model.py`
- [X] T005 Add safe profile gating for the retained managed Floorp path in `states/floorp.sls`
- [X] T006 Align browser-state inclusion semantics for Zen-primary/Floorp-secondary management in `states/system_description.sls`
- [X] T007 Document `zen_profile` and dual-browser browser-role expectations in `docs/adding-host.md`
- [X] T008 [P] Document `zen_profile` and dual-browser browser-role expectations in `docs/adding-host.ru.md`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Use Zen Browser as the primary daily browser (Priority: P1) 🎯 MVP

**Goal**: Move all common browser entry points to Zen Browser while keeping Floorp separately managed and explicitly launchable

**Independent Test**: Apply the configuration, trigger each common browser launcher surface, and confirm it opens or raises Zen Browser instead of Floorp while Floorp remains available only through an explicit secondary path.

### Implementation for User Story 1

- [X] T009 [US1] Reconcile package-level dual-browser support expectations in `states/data/packages.yaml`
- [X] T010 [P] [US1] Update the primary Hyprland browser binding and add an explicit Floorp launcher path in `dotfiles/dot_config/hypr/bindings/apps.conf`
- [X] T011 [P] [US1] Update the primary Wayfire browser binding and add an explicit Floorp launcher path in `dotfiles/dot_config/wayfire.ini`
- [X] T012 [P] [US1] Update the `wlr-which-key` browser menu to make Zen primary and Floorp explicitly secondary in `dotfiles/dot_config/wlr-which-key/config.yaml`
- [X] T013 [US1] Implement launcher target regression assertions for the Hyprland, Wayfire, and `wlr-which-key` browser surfaces in `tests/test_browser_launch_targets.py`

**Checkpoint**: At this point, common browser launch surfaces should consistently target Zen Browser while Floorp remains separately launchable

---

## Phase 4: User Story 2 - Keep Surfingkeys browser-assisted actions working in Zen (Priority: P1)

**Goal**: Preserve the helper-assisted Surfingkeys workflow inside Zen Browser without expanding the acceptance boundary to Floorp

**Independent Test**: Start the managed helper service, open Zen Browser with the managed profile, and confirm the helper-assisted focus and new-tab Surfingkeys actions succeed while failure messaging remains clear when the helper is unavailable.

### Implementation for User Story 2

- [X] T014 [US2] Keep Zen extension parity explicit for Surfingkeys and shared Firefox-compatible extensions in `states/data/zen_browser.yaml`
- [X] T015 [P] [US2] Update Zen profile deployment and extension reset behavior for the helper-assisted workflow in `states/zen_browser.sls`
- [X] T016 [P] [US2] Normalize the Zen-primary helper workflow wording while preserving the localhost `/focus` and `blank.html` actions in `dotfiles/dot_config/surfingkeys.js`
- [X] T017 [P] [US2] Harden the helper runtime contract for the Zen workflow in `dotfiles/dot_local/bin/executable_surfingkeys-server`
- [X] T018 [US2] Implement regression assertions for Zen Surfingkeys extension presence and localhost helper endpoints in `tests/test_surfingkeys_zen_contract.py`

**Checkpoint**: At this point, Zen Browser should preserve the helper-assisted Surfingkeys workflow independently of the launcher-cutover story

---

## Phase 5: User Story 3 - Verify the Zen workflow without breaking dual-browser management (Priority: P2)

**Goal**: Provide a repeatable operator workflow that validates the Zen cutover end to end and identifies the failing domain when something breaks

**Independent Test**: Run the documented verification workflow on the target host and confirm it reports render, launcher, profile, helper-service, and runtime action results clearly enough to accept or reject the cutover in one session.

### Implementation for User Story 3

- [X] T019 [US3] Implement the operator verification workflow in `scripts/verify-zen-browser-cutover.sh`
- [X] T020 [P] [US3] Align the executable verification steps and acceptance sequence in `specs/077-zen-browser-cutover/quickstart.md`
- [X] T021 [P] [US3] Update the verification coverage contract to match the implemented script and runtime checks in `specs/077-zen-browser-cutover/contracts/verification-matrix.yaml`
- [X] T022 [US3] Update the browser launch-surface contract to match the final Zen-primary and explicit-Floorp launcher mapping in `specs/077-zen-browser-cutover/contracts/browser-cutover-surfaces.yaml`

**Checkpoint**: At this point, the cutover should be verifiable end to end with a repeatable operator workflow

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup, artifact refresh, and repository validation across all user stories

- [X] T023 [P] Refresh the design notes to match delivered implementation details in `specs/077-zen-browser-cutover/research.md`
- [X] T024 [P] Refresh the implementation summary and constitution gate notes in `specs/077-zen-browser-cutover/plan.md`
- [X] T025 Run targeted validation for `tests/test_host_model.py`, `tests/test_browser_launch_targets.py`, `tests/test_surfingkeys_zen_contract.py`, and `scripts/verify-zen-browser-cutover.sh`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion - delivers the MVP browser-entry-point cutover
- **User Story 2 (Phase 4)**: Depends on Foundational completion and can proceed in parallel with US1 once the shared browser assumptions are in place
- **User Story 3 (Phase 5)**: Depends on Foundational completion and should land after the core US1/US2 behavior is implemented so verification reflects the final workflow
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - no dependency on other stories
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) - independent of launcher migration except for final integrated validation
- **User Story 3 (P2)**: Depends on the implemented launcher and helper behavior from US1 and US2

### Within Each User Story

- Package/state expectations before launcher/profile edits
- Launcher/profile/helper edits before regression assertions
- Verification script and contracts after the runtime workflow is implemented
- Artifact refresh and validation after the implementation work is complete

### Parallel Opportunities

- T001, T002, and T003 can run in parallel as setup scaffolding
- T007 and T008 can run in parallel once the foundational browser-role wording is clear
- T010, T011, and T012 can run in parallel once T009 confirms the dual-browser support boundary
- T015, T016, and T017 can run in parallel once T014 fixes the Zen extension contract
- T020 and T021 can run in parallel after T019 establishes the verification workflow
- T023 and T024 can run in parallel after implementation is complete

---

## Parallel Example: User Story 1

```bash
# Launch all common browser-surface updates together after the package/support boundary is confirmed:
Task: "Update the primary Hyprland browser binding and add an explicit Floorp launcher path in dotfiles/dot_config/hypr/bindings/apps.conf"
Task: "Update the primary Wayfire browser binding and add an explicit Floorp launcher path in dotfiles/dot_config/wayfire.ini"
Task: "Update the wlr-which-key browser menu to make Zen primary and Floorp explicitly secondary in dotfiles/dot_config/wlr-which-key/config.yaml"
```

---

## Parallel Example: User Story 2

```bash
# Launch the Zen helper-workflow updates together after the extension contract is confirmed:
Task: "Update Zen profile deployment and extension reset behavior for the helper-assisted workflow in states/zen_browser.sls"
Task: "Normalize the Zen-primary helper workflow wording while preserving the localhost /focus and blank.html actions in dotfiles/dot_config/surfingkeys.js"
Task: "Harden the helper runtime contract for the Zen workflow in dotfiles/dot_local/bin/executable_surfingkeys-server"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Confirm all common browser launch surfaces now open Zen Browser while Floorp remains explicitly available

### Incremental Delivery

1. Complete Setup + Foundational → shared browser-role assumptions and validation scaffolding are ready
2. Add User Story 1 → validate Zen-primary launcher behavior (MVP)
3. Add User Story 2 → validate helper-assisted Surfingkeys behavior in Zen
4. Add User Story 3 → validate the end-to-end operator verification workflow
5. Finish with Polish → refresh planning artifacts and run targeted repository validation

### Parallel Team Strategy

With multiple developers:

1. One developer completes Setup + Foundational
2. Once the foundation is ready:
   - Developer A: US1 launcher and package surface updates
   - Developer B: US2 Zen profile and helper-workflow updates
   - Developer C: US3 verification script and contract alignment after US1/US2 stabilize

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [US1] through [US3] labels map directly to the user stories in `spec.md`
- Every task includes an exact file path or explicit validation target for immediate execution
- Suggested MVP scope: Phase 3 / User Story 1 only
