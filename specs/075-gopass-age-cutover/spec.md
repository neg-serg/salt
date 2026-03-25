# Feature Specification: Gopass Age Cutover

**Feature Branch**: `075-gopass-age-cutover`  
**Created**: 2026-03-26  
**Status**: Draft  
**Input**: User description: "Мне надо чтобы ты перевел меня на использование age прямо сейчас."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Complete Live Cutover (Priority: P1)

As the workstation operator, I want the active secret store to use the new password-based backend immediately so that daily secret reads, dotfile rendering, and workstation workflows stop depending on the old hardware-backed unlock path.

**Why this priority**: This is the direct user goal. Until the active store is cut over, the workstation still depends on the legacy path and the requested migration is incomplete.

**Independent Test**: Can be fully tested by switching the active store to the new backend, verifying representative secret reads through the existing command-line interface, and confirming that dotfile rendering succeeds in the same user session.

**Acceptance Scenarios**:

1. **Given** the operator starts with a working legacy-backed store and current secret paths, **When** the active store is cut over to the new backend, **Then** the same secret paths remain available through the existing public interface without renaming or re-entering the secrets.
2. **Given** the active store has been cut over, **When** the operator performs representative command-line secret reads and re-runs dotfile application, **Then** all required secrets resolve successfully in the current user session.

---

### User Story 2 - Fail-Closed Recovery (Priority: P2)

As the workstation operator, I want the migration to stop and recover cleanly if validation fails so that I do not strand the workstation in a partially migrated or unreadable state.

**Why this priority**: A live cutover without an immediate recovery path is operationally unsafe. The workstation must remain usable even if the first cutover attempt fails.

**Independent Test**: Can be fully tested by preparing rollback artifacts, forcing at least one validation failure before accepting the cutover, and confirming that the previous working store can be restored with the same representative validation set.

**Acceptance Scenarios**:

1. **Given** a validation step fails before the cutover is accepted, **When** the operator invokes the defined recovery path, **Then** the previous working store becomes the active source of truth again.
2. **Given** rollback has completed, **When** the operator repeats representative secret reads and dependent workflows, **Then** they behave the same as they did before cutover work began.

---

### User Story 3 - Stabilize and Retire Legacy Access (Priority: P3)

As the workstation operator, I want a clear stabilization period after cutover so that I can prove the new backend is reliable before removing the old unlock path.

**Why this priority**: Immediate retirement of legacy access increases recovery risk. A defined observation window keeps the migration reversible until confidence is established.

**Independent Test**: Can be fully tested by completing the required day-to-day workflows during the observation window and verifying that no fallback to the old access path is needed.

**Acceptance Scenarios**:

1. **Given** the live cutover has passed initial validation, **When** the operator completes the defined observation window, **Then** all required workflows succeed without fallback to the old access path.
2. **Given** the observation window completes without unresolved failures, **When** the operator decides whether to retire legacy access, **Then** the decision is based on recorded validation evidence instead of ad hoc judgment.

### Edge Cases

- What happens if the new backend can read standard password entries but fails on attached files or other non-standard records?
- What happens if command-line reads succeed but dotfile rendering still fails in the current user session?
- What happens if rollback artifacts are incomplete when a cutover failure is detected?
- What happens if the operator can unlock the new backend only in one shell session and not in the session used by dependent workflows?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The migration MUST change the active secret store from the legacy backend to the new password-based backend during this feature.
- **FR-002**: The migration MUST preserve the existing public `gopass` interface for operators, Salt-driven workflows, and dotfile rendering workflows.
- **FR-003**: The migration MUST preserve existing secret paths and plaintext equivalence for representative secret entries across the cutover.
- **FR-004**: The migration MUST include a pre-cutover backup package containing the active store copy, store history, legacy unlock materials, and written rollback steps.
- **FR-005**: The migration MUST define and execute a pre-cutover validation set covering representative command-line reads, dotfile rendering, and repo-managed secret consumers.
- **FR-006**: The migration MUST fail closed: any failed validation before final acceptance blocks the cutover from being considered complete.
- **FR-007**: The migration MUST provide an explicit rollback path that restores the previous working store as the active source of truth.
- **FR-008**: The migration MUST validate a representative subset of attached files, unusual entry names, or other non-password records that are present in the store.
- **FR-009**: The migration MUST leave exactly one active source of truth after a successful cutover and exactly one active source of truth after a rollback.
- **FR-010**: The migration MUST define a fixed post-cutover stabilization window during which required workflows are observed before legacy access is retired.
- **FR-011**: The migration MUST retain the legacy unlock path throughout the stabilization window unless rollback has already made it the active path again.
- **FR-012**: The migration MUST record the final cutover outcome, rollback readiness, and the condition for retiring legacy access.

### Key Entities *(include if feature involves data)*

- **Active Secret Store**: The currently authoritative encrypted secret collection used by workstation workflows.
- **Rollback Package**: The set of recovery artifacts and instructions required to restore the last known-good working store.
- **Validation Case**: A representative workflow check proving that a secret consumer still behaves correctly before and after cutover.
- **Stabilization Window**: The defined observation period after successful cutover and before legacy access can be retired.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of representative secret paths in the validation set resolve successfully with identical plaintext values before and after cutover.
- **SC-002**: The operator can complete the first post-cutover dotfile application attempt in the current user session without secret-read failures.
- **SC-003**: If a validation failure is triggered before final acceptance, rollback restores a known-good state and the same representative validation set passes again with no unresolved failures.
- **SC-004**: During the stabilization window, 100% of required day-to-day secret-dependent workflows complete without fallback to the old access path.
- **SC-005**: The operator can determine whether legacy access may be retired by reviewing one recorded cutover outcome and one recorded stabilization outcome, without needing undocumented tribal knowledge.

## Assumptions

- The current store is readable through the legacy path at the start of the migration.
- One maintainer/operator owns the live cutover and rollback decisions end to end.
- The workstation can create and retain rollback artifacts before the live cutover begins.
- The set of representative workflows includes command-line reads, dotfile rendering, and the repo-managed secret consumers already relied on for this machine.
