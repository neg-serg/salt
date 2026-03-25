# Contract: Cutover Checkpoints

## Purpose

Define the mandatory go/no-go checkpoints for cutting over the active `gopass` store to an `age` backend on the current workstation session without breaking existing consumers.

## Checkpoints

### 1. Baseline Ready

- Representative direct secret reads are recorded from the current active store.
- The `chezmoi` secret-backed rendering path is included in the acceptance boundary.
- A representative subset of attached files or unusual/non-password entries is selected.
- The validation matrix is frozen as the minimum acceptance set.

### 2. Rollback Package Ready

- Current store contents are backed up.
- Related repository history needed for recovery is backed up.
- Legacy unlock materials remain accessible.
- Written rollback steps exist and are owned by the operator.

### 3. Age Unlock Prepared

- The new backend’s unlock artifacts exist and are protected.
- Same-session unlock steps are documented for the active user session.
- Recovery usage on a later session or machine is documented before legacy retirement.

### 4. Production Cutover Pass

- Pre-cutover validation passed on the live store.
- Live conversion completed without path renames.
- The active store marker reflects the new backend.
- Post-cutover validation passed using the same representative cases captured at baseline.

### 5. Immediate Workflow Recovery

- The first post-cutover `chezmoi apply` succeeds in the current user session.
- Repo-managed validation still succeeds.
- The representative special-entry subset remains readable after cutover.

### 6. Stabilization Exit

- Required day-to-day workflows succeed for 7 consecutive days.
- No fallback to the legacy path occurs during that window.
- No unresolved failures remain open.
- The legacy-retirement decision is recorded.

## Failure Semantics

- Failure before production cutover acceptance: stop and restore the previous working store as the active source of truth.
- Failure after live conversion but before immediate workflow recovery: rollback is mandatory.
- Failure during stabilization: keep the legacy path available and either rollback or extend observation.
- Any missing evidence for a checkpoint counts as a failed checkpoint.
