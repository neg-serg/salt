# Contract: Rollback Acceptance

## Purpose

Define the minimum evidence required to declare rollback successful after a failed live cutover to the `age` backend.

## Required Inputs

- A complete rollback package prepared before live conversion
- The representative validation cases frozen for baseline and cutover acceptance
- Access to the previous working unlock path and related recovery artifacts
- Written rollback steps owned by the single maintainer/operator

## Acceptance Rules

1. The previous working store is restored as the active source of truth.
2. Representative direct secret reads return the same plaintext values as the original baseline.
3. High-priority `chezmoi` secret-backed templates can resolve required secrets again.
4. The first post-rollback `chezmoi` path succeeds in the current user session.
5. Repo-managed secret consumers pass the same local validation step used before cutover.
6. The representative subset of attached files and unusual/non-password entries is readable again.
7. No consumer remains pointed at a partial, mixed, or ambiguous active store after rollback completes.
8. The operator records the failure trigger and whether another cutover attempt is allowed.

## Minimum Evidence

- Proof that the restored store is active
- Successful execution results for representative direct secret reads
- Successful execution results for the current-session `chezmoi` workflow
- Successful execution results for repo-managed validation
- Successful execution results for the representative special-entry subset
- Operator note stating whether the cutover is abandoned, retried, or blocked on remediation
