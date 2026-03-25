# Quickstart: Gopass Age Cutover

## 1. Preconditions

- Current branch: `075-gopass-age-cutover`
- Current `gopass` store is healthy and readable through the legacy path
- One maintainer/operator owns the live cutover and rollback decisions
- The operator can create and retain rollback artifacts before the live conversion starts

## 2. Freeze the Validation Boundary

Before touching the active store, record the minimum acceptance set:

1. Representative direct `gopass` reads from top-level, nested, and automation-facing paths.
2. Current-session `chezmoi` secret-backed rendering paths.
3. Secret-consuming Salt or script workflows that must still work after cutover.
4. A representative subset of attached files or unusual/non-password entries.

Use these repo references as the starting inventory:

- [docs/secrets-scheme.md](/home/neg/src/salt/docs/secrets-scheme.md)
- [docs/gopass-setup.md](/home/neg/src/salt/docs/gopass-setup.md)
- [scripts/salt-apply.sh](/home/neg/src/salt/scripts/salt-apply.sh)
- [contracts/validation-matrix.yaml](/home/neg/src/salt/specs/075-gopass-age-cutover/contracts/validation-matrix.yaml)

## 3. Capture the Baseline and Rollback Package

Before conversion:

1. Confirm representative direct secret reads from the current active store.
2. Confirm the selected special-entry subset remains readable.
3. Confirm `chezmoi` secret-backed templates can still resolve through the current path.
4. Run local repository validation.
5. Archive the active store, associated git history, legacy unlock materials, and written rollback steps into one rollback package.

Minimum repo check:

```bash
just validate
```

## 4. Execute the Live Cutover

1. Generate or confirm the password-protected unlock artifacts for the `age` backend.
2. Reconfirm that rollback artifacts are complete and accessible.
3. Convert the active store to the new backend without renaming secret paths.
4. Verify the active store marker reflects the new backend.
5. Run the post-cutover validation matrix on the same host and in the same user session.
6. Re-run `chezmoi apply` as part of cutover acceptance, not as a deferred follow-up.

Cutover passes only if:

- all high-priority validation cases succeed;
- the first post-cutover `chezmoi apply` succeeds in the current user session;
- the representative special-entry subset remains readable and structurally intact; and
- no consumer requires a path rename or a second source of truth.

## 5. Failure and Rollback

Rollback is required if any of the following occurs before cutover acceptance:

- representative direct secret reads do not match baseline expectations;
- `chezmoi` still cannot resolve required secrets in the current user session;
- repo validation fails in a way attributable to secret access;
- the special-entry subset becomes unreadable or structurally inconsistent; or
- the active store is left in a mixed or ambiguous state.

If rollback is triggered:

1. Restore the previous working store as the active source of truth.
2. Re-run the representative validation set.
3. Record the failure trigger and whether the cutover is abandoned, retried, or blocked on remediation.

## 6. Stabilization

After a successful cutover:

1. Keep the legacy unlock path available for a fixed 7-day stabilization window.
2. Track all required day-to-day secret-dependent workflows during that window.
3. Block legacy retirement if any fallback use or unresolved workflow failure occurs.
4. Retire legacy access only after 7 consecutive days with no fallback and no unresolved failures.

## 7. Completion Criteria

- Live cutover passed the validation matrix on the current host.
- The first post-cutover `chezmoi apply` succeeded in the same user session.
- Rollback artifacts remain available for the full retention window.
- The representative special-entry subset passed baseline, cutover, and rollback-ready validation.
- The final decision on legacy retirement is based on recorded stabilization evidence.
