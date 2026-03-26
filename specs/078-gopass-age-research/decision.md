# Decision: Gopass Age Backend Failure Research

## Related Artifacts

- [evidence-matrix.md](/home/neg/src/salt/specs/078-gopass-age-research/evidence-matrix.md)
- [findings.md](/home/neg/src/salt/specs/078-gopass-age-research/findings.md)
- [symptom-matrix.md](/home/neg/src/salt/specs/078-gopass-age-research/symptom-matrix.md)
- [verification.md](/home/neg/src/salt/specs/078-gopass-age-research/verification.md)

## Verdict

`plan_migration`

The current `gopass` `age` backend path is not salvageable for unattended rollout use under the clarified acceptance boundary. The feature should stop at a migration-planning handoff, and the next feature must choose the target backend first.

## Acceptance Boundary

The backend counts as salvageable only if both of the following succeed on the current workstation without a fresh passphrase prompt:

1. non-interactive `gopass show -o email/gmail/address`
2. `chezmoi apply --force --source /home/neg/src/salt/dotfiles`

## Evidence Against the Boundary

| Criterion | Required Result | Actual Result | Status | Evidence |
|-----------|-----------------|---------------|--------|----------|
| Non-interactive `gopass show` | Returns the secret without a new prompt | Fails with `pinentry ... inappropriate ioctl for device` while decrypting `~/.config/gopass/age/identities` | FAIL | L005 |
| `chezmoi apply` | Renders templates without a new prompt | Aborts during `gopass` template lookup with the same decryption and `pinentry` failure chain | FAIL | L006 |
| Agent-assisted maturity | Upstream and local evidence should support unattended reliability for the current identities model | Upstream evidence shows age-agent ergonomics are still evolving, and local evidence does not show prompt-free unattended behavior | FAIL | U001, U003, L007, L009 |

## Stop Condition

Stop debugging the current backend path when both of the following remain true after non-destructive validation:

1. upstream evidence still describes passphrase caching / GPG-agent parity as incomplete for the `age` path; and
2. either non-interactive `gopass show` or `chezmoi apply` still fails on the current workstation.

That stop condition is met now.

## Residual Unknowns

- Whether a future `gopass` release materially changes unattended age-agent behavior for the current identities model.
- Whether a different local agent lifecycle arrangement could reduce prompts without meeting full unattended parity.
- Whether the exact failure path differs when the age agent is already running before the first secret read in a fresh login session.

None of these unknowns are strong enough to override the present acceptance failure.

## Minimum Next Decision

The next feature must choose the target backend first.

That comparison may include:

- returning to `gpg` with hardware-backed access; or
- designing another approved `age` strategy with a different unlock and recovery model.

This feature does not choose between them. It only establishes that the current backend path should not continue as the unattended rollout backend in its present form.

## Reviewer Summary

A reviewer should be able to answer the feature question in under five minutes:

- Is the current backend salvageable for unattended rollout use? No.
- Why not? Both required unattended consumers still fail, and the encrypted identities file remains in the active failure path.
- What happens next? A separate feature chooses the replacement backend before any cutover plan is written.
