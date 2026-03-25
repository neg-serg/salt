# Phase 0 Research: Gopass Age Cutover

## Decision 1: Keep `gopass` as the public interface and change only the crypto backend

- **Decision**: Preserve `gopass` as the single interface used by operators, `chezmoi`, Salt states, and scripts; migrate the active store backend rather than replacing the password manager interface.
- **Rationale**: Existing repo consumers already call `gopass`. Keeping that interface stable avoids consumer rewrites and fits the requirement to preserve secret paths and workflow behavior.
- **Alternatives considered**:
  - Replace `gopass` with another secret manager: rejected because it expands scope and breaks current consumers.
  - Run dual live stores during migration: rejected because it violates the single-source-of-truth requirement and introduces drift risk.

## Decision 2: Use a live cutover on the current host, but only after baseline capture and rollback preparation

- **Decision**: Treat this feature as a direct production cutover on the current workstation session, with baseline capture and rollback package preparation required before any conversion step.
- **Rationale**: The user explicitly wants to switch to `age` now, not just document a rehearsal. The safe way to honor that request is to keep the cutover live but fail closed until backups, validation scope, and rollback inputs are ready.
- **Alternatives considered**:
  - Rehearsal-only work with no live cutover: rejected because it does not satisfy the immediate request.
  - Convert the live store immediately without baseline capture: rejected because it would make rollback and equivalence verification unreliable.

## Decision 3: Make current-session `chezmoi` success part of cutover acceptance

- **Decision**: Require the first successful post-cutover `chezmoi apply` in the same user session as a high-priority acceptance check.
- **Rationale**: The immediate operational pain point is that Salt succeeded while dotfiles were skipped because the secret path was not usable in the current session. A cutover that leaves `chezmoi` broken has not solved the user’s actual problem.
- **Alternatives considered**:
  - Limit validation to generic `gopass` CLI reads: rejected because it would miss the exact workflow that failed.
  - Defer `chezmoi` verification to the stabilization window: rejected because the user needs the fix now.

## Decision 4: Preserve entry paths and plaintext equivalence exactly

- **Decision**: Treat path continuity and plaintext equivalence as non-negotiable validation rules for the live cutover.
- **Rationale**: Current consumers rely on stable paths such as `api/proxypilot-local` and `email/gmail/app-password`. Preserving those paths keeps the migration narrow and lowers operational risk.
- **Alternatives considered**:
  - Rename entries during the cutover: rejected as unrelated scope expansion.
  - Re-enter secrets manually in a new store layout: rejected because it increases human error and weakens rollback guarantees.

## Decision 5: Validate real repo consumers and a representative special-entry subset

- **Decision**: Build the validation matrix from actual consumers already documented in the repository, plus a representative subset of attached files or non-password entries present in the store.
- **Rationale**: Repo consumers define the real acceptance boundary. Special entries remain part of the active store and must not be silently lost in an otherwise “successful” migration.
- **Alternatives considered**:
  - Validate only command-line reads: rejected because it misses rendering and workflow failures.
  - Exclude attached files and non-password records: rejected because it creates hidden post-cutover risk.

## Decision 6: Keep the legacy GPG/YubiKey path available through the stabilization window

- **Decision**: Retain the legacy unlock path throughout a fixed 7-day stabilization window after successful cutover.
- **Rationale**: Immediate legacy retirement would make any latent compatibility issue a full recovery event. Temporary coexistence provides a controlled safety margin while still preserving a clear end state.
- **Alternatives considered**:
  - Remove the legacy path immediately after cutover validation: rejected as unnecessarily risky.
  - Keep the legacy path indefinitely: rejected because it leaves the migration incomplete and support boundaries unclear.

## Decision 7: Treat rollback as a first-class deliverable

- **Decision**: Require a minimum rollback package consisting of the active store copy, store git history, legacy unlock materials, and written rollback steps before any live conversion begins.
- **Rationale**: Rollback quality is the main safety property for a live cutover. A vague rollback note is not operationally sufficient.
- **Alternatives considered**:
  - Rely on store git history alone: rejected because local state and unlock artifacts may not be fully recoverable from history alone.
  - Define rollback only after conversion issues appear: rejected because it fails the fail-closed requirement.

## Decision 8: Retain existing git history during the main cutover

- **Decision**: Leave current store history unchanged during the main cutover and record any residual-history handling as a separate follow-up decision after stabilization.
- **Rationale**: History rewriting is operationally separate from making the active store usable through the new backend. Keeping it out of the main cutover reduces risk and keeps the request scoped.
- **Alternatives considered**:
  - Rewrite history as part of the same cutover: rejected because it materially increases complexity.
  - Ignore residual-history handling entirely: rejected because the decision should be explicit even if deferred.

## Clarifications Resolved

- **Cutover mode**: This feature is an immediate live cutover, not a rehearsal-only exercise.
- **Primary success boundary**: The first post-cutover `chezmoi apply` in the current user session is mandatory for acceptance.
- **Validation boundary**: The minimum set includes representative CLI reads, `chezmoi` secret templates, secret-consuming Salt paths, repo validation, and a representative special-entry subset.
- **Rollback timing**: Rollback preparation must be complete before live conversion starts.
- **Legacy-path retirement**: The old path remains available for a fixed 7-day stabilization window after successful cutover.
