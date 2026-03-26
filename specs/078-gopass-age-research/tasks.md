# Tasks: Gopass Age Backend Failure Research

**Input**: Design documents from `/specs/078-gopass-age-research/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, quickstart.md

**Tests**: No new unit or contract tests are required. Validation is documentary and operational: source verification, local symptom reproduction, strict unattended acceptance checks, and final decision review against the spec success criteria.

**Organization**: Tasks are grouped by user story so diagnosis, symptom classification, and the final salvage-vs-migration handoff can each be produced and reviewed independently.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the feature-local research deliverables that later phases will populate.

- [X] T001 Create the research verification tracker in `/home/neg/src/salt/specs/078-gopass-age-research/verification.md`
- [X] T002 [P] Create the primary-source evidence matrix scaffold in `/home/neg/src/salt/specs/078-gopass-age-research/evidence-matrix.md`
- [X] T003 [P] Create the diagnosis findings scaffold in `/home/neg/src/salt/specs/078-gopass-age-research/findings.md`
- [X] T004 [P] Create the symptom matrix scaffold in `/home/neg/src/salt/specs/078-gopass-age-research/symptom-matrix.md`
- [X] T005 [P] Create the final decision scaffold in `/home/neg/src/salt/specs/078-gopass-age-research/decision.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Freeze the local baseline, upstream evidence inventory, and non-destructive boundaries before story-specific analysis begins.

**⚠️ CRITICAL**: No user story work should begin until this phase is complete.

- [X] T006 Record the current local baseline commands, environment facts, and failing outputs in `/home/neg/src/salt/specs/078-gopass-age-research/evidence-matrix.md`
- [X] T007 [P] Record maintainer evidence about passphrase caching, agent parity, and release behavior from upstream sources in `/home/neg/src/salt/specs/078-gopass-age-research/evidence-matrix.md`
- [X] T008 [P] Record upstream evidence about encrypted age identities handling and supported key-management workflow in `/home/neg/src/salt/specs/078-gopass-age-research/evidence-matrix.md`
- [X] T009 Define the confirmation-status rubric, severity labels, and review checklist in `/home/neg/src/salt/specs/078-gopass-age-research/verification.md`
- [X] T010 Record the non-destructive investigation guardrails, rollback assumptions, backup constraints, and strict salvage-threshold in `/home/neg/src/salt/specs/078-gopass-age-research/verification.md`

**Checkpoint**: The feature now has a frozen evidence inventory, local baseline, and verification rubric.

---

## Phase 3: User Story 1 - Diagnose the Current Failure Mode (Priority: P1) 🎯 MVP

**Goal**: Produce one evidence-backed diagnosis that explains why the current `gopass` `age` backend still prompts or fails after agent unlock attempts.

**Independent Test**: A reviewer can read `/home/neg/src/salt/specs/078-gopass-age-research/findings.md` and understand one coherent failure hypothesis that explains both repeated prompting and non-interactive `pinentry` failure.

### Implementation for User Story 1

- [X] T011 [P] [US1] Map local baseline observations and upstream evidence IDs into the diagnosis outline in `/home/neg/src/salt/specs/078-gopass-age-research/findings.md`
- [X] T012 [P] [US1] Write the local reproduction narrative for non-interactive `gopass show`, `gopass age agent unlock`, `chezmoi apply`, and encrypted identities-file fallback in `/home/neg/src/salt/specs/078-gopass-age-research/findings.md`
- [X] T013 [US1] Consolidate the primary failure hypothesis, confidence level, and disproving conditions in `/home/neg/src/salt/specs/078-gopass-age-research/findings.md`
- [X] T014 [US1] Validate the diagnosis against FR-001 through FR-006A and record the result in `/home/neg/src/salt/specs/078-gopass-age-research/verification.md`

**Checkpoint**: User Story 1 is complete when the diagnosis explains the current failure mode without relying on destructive backend experiments.

---

## Phase 4: User Story 2 - Enumerate Recognizable Symptoms (Priority: P2)

**Goal**: Build a symptom matrix that lets another operator recognize the same failure class on a different machine.

**Independent Test**: A reviewer can use `/home/neg/src/salt/specs/078-gopass-age-research/symptom-matrix.md` to distinguish trigger context, observed output, and upstream confirmation status for each relevant symptom.

### Implementation for User Story 2

- [X] T015 [P] [US2] Populate the required symptom rows for repeated prompting, non-interactive `pinentry` failure, `chezmoi apply` failure under locked backend, agent-socket-plus-identities access, and plaintext-identity regression in `/home/neg/src/salt/specs/078-gopass-age-research/symptom-matrix.md`
- [X] T016 [P] [US2] Annotate each symptom with trigger context, impacted workflow, and upstream confirmation status in `/home/neg/src/salt/specs/078-gopass-age-research/symptom-matrix.md`
- [X] T017 [US2] Validate the symptom matrix against the quickstart minimum rows and SC-002 in `/home/neg/src/salt/specs/078-gopass-age-research/verification.md`

**Checkpoint**: User Story 2 is complete when the symptom matrix can be used as a repeatable recognition checklist for the same backend failure class.

---

## Phase 5: User Story 3 - Decide Whether Salvage Is Realistic (Priority: P3)

**Goal**: Turn the evidence into a clear decision on whether to continue debugging the current backend or start migration planning, with an explicit handoff to target-backend selection if migration is needed.

**Independent Test**: A reviewer can read `/home/neg/src/salt/specs/078-gopass-age-research/decision.md` and determine within five minutes whether the backend is salvageable for unattended rollout use, whether the strict threshold is met, and what the next feature must decide.

### Implementation for User Story 3

- [X] T018 [P] [US3] Record the unattended-rollout acceptance boundary, explicit stop condition, residual unknowns, and target-backend-selection handoff in `/home/neg/src/salt/specs/078-gopass-age-research/decision.md`
- [X] T019 [P] [US3] Compare the collected evidence and symptom matrix against the strict salvage criteria requiring both non-interactive `gopass show` and `chezmoi apply` in `/home/neg/src/salt/specs/078-gopass-age-research/decision.md`
- [X] T020 [US3] Write the final salvage-vs-migration verdict and the minimum next decision to choose the target backend first in `/home/neg/src/salt/specs/078-gopass-age-research/decision.md`
- [X] T021 [US3] Validate the final decision against SC-001, SC-003, SC-004, FR-008, and FR-008A in `/home/neg/src/salt/specs/078-gopass-age-research/verification.md`

**Checkpoint**: User Story 3 is complete when the feature ends with a defensible branch point and a precise handoff for the next planning feature.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final consistency review across the full research package.

- [X] T022 [P] Sync terminology and cross-links across `/home/neg/src/salt/specs/078-gopass-age-research/research.md`, `/home/neg/src/salt/specs/078-gopass-age-research/quickstart.md`, `/home/neg/src/salt/specs/078-gopass-age-research/evidence-matrix.md`, `/home/neg/src/salt/specs/078-gopass-age-research/findings.md`, `/home/neg/src/salt/specs/078-gopass-age-research/symptom-matrix.md`, and `/home/neg/src/salt/specs/078-gopass-age-research/decision.md`
- [X] T023 [P] Run a placeholder-free and terminology-consistency review across all feature documents and record the result in `/home/neg/src/salt/specs/078-gopass-age-research/verification.md`
- [X] T024 Run `just` and record the verification-gate result in `/home/neg/src/salt/specs/078-gopass-age-research/verification.md`
- [X] T025 Record branch or pull-request CI status, or document the explicit override rationale if CI is unavailable, in `/home/neg/src/salt/specs/078-gopass-age-research/verification.md`
- [X] T026 Validate the full research package against `/home/neg/src/salt/specs/078-gopass-age-research/quickstart.md` and `/home/neg/src/salt/specs/078-gopass-age-research/spec.md`, then record final acceptance in `/home/neg/src/salt/specs/078-gopass-age-research/verification.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; can start immediately.
- **Foundational (Phase 2)**: Depends on Setup; blocks all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational completion.
- **User Story 2 (Phase 4)**: Depends on Foundational completion; can proceed independently of US1 once the evidence inventory is frozen.
- **User Story 3 (Phase 5)**: Depends on US1 and US2 because the final verdict requires both diagnosis and symptom classification.
- **Polish (Phase 6)**: Depends on all selected user stories being complete.

### User Story Dependencies

- **US1 (P1)**: First deliverable; no dependency on other stories after Foundational.
- **US2 (P2)**: Independent of US1 after Foundational, but reuses the same evidence inventory and verification rubric.
- **US3 (P3)**: Depends on both US1 and US2 because the verdict must synthesize diagnosis, symptom labeling, and the clarified handoff decision.

### Parallel Opportunities

- T002, T003, T004, and T005 can run in parallel.
- T007 and T008 can run in parallel.
- T011 and T012 can run in parallel.
- T015 and T016 can run in parallel.
- T018 and T019 can run in parallel.
- T022 and T023 can run in parallel after all story deliverables exist.

---

## Parallel Example: User Story 1

```bash
# Parallelize diagnosis assembly after the evidence inventory is frozen:
Task: "Map local baseline observations and upstream evidence IDs into the diagnosis outline in /home/neg/src/salt/specs/078-gopass-age-research/findings.md"
Task: "Write the local reproduction narrative for non-interactive gopass show, gopass age agent unlock, chezmoi apply, and encrypted identities-file fallback in /home/neg/src/salt/specs/078-gopass-age-research/findings.md"
```

---

## Parallel Example: User Story 2

```bash
# Parallelize symptom-matrix completion:
Task: "Populate the required symptom rows for repeated prompting, non-interactive pinentry failure, chezmoi apply failure under locked backend, agent-socket-plus-identities access, and plaintext-identity regression in /home/neg/src/salt/specs/078-gopass-age-research/symptom-matrix.md"
Task: "Annotate each symptom with trigger context, impacted workflow, and upstream confirmation status in /home/neg/src/salt/specs/078-gopass-age-research/symptom-matrix.md"
```

---

## Parallel Example: User Story 3

```bash
# Parallelize decision preparation before writing the final verdict:
Task: "Record the unattended-rollout acceptance boundary, explicit stop condition, residual unknowns, and target-backend-selection handoff in /home/neg/src/salt/specs/078-gopass-age-research/decision.md"
Task: "Compare the collected evidence and symptom matrix against the strict salvage criteria requiring both non-interactive gopass show and chezmoi apply in /home/neg/src/salt/specs/078-gopass-age-research/decision.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational.
3. Complete Phase 3: User Story 1.
4. Stop and validate that `/home/neg/src/salt/specs/078-gopass-age-research/findings.md` explains the current failure mode clearly enough to guide the next decision.

### Incremental Delivery

1. Finish Setup + Foundational to freeze the evidence inventory and review rubric.
2. Deliver US1 to explain the current failure mode.
3. Deliver US2 to convert raw observations into a reusable symptom matrix.
4. Deliver US3 to make the salvage-vs-migration decision and handoff explicit.
5. Finish Polish with cross-linking and final package validation.

### Suggested MVP Scope

- Phase 1
- Phase 2
- Phase 3 (US1 only)

This yields the smallest valuable increment: a defensible diagnosis of why the current backend keeps breaking rollout-related secret access.

## Notes

- All tasks follow the required checklist format: checkbox, task ID, optional `[P]`, required `[US#]` for story tasks, and exact file paths.
- This feature is intentionally internal and document-focused, so no `contracts/` tasks are generated.
- Validation is operational and documentary rather than test-suite-driven; the acceptance gates are evidence quality, strict unattended success criteria, symptom classification, and a clear final handoff decision.
