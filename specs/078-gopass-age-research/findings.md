# Findings: Gopass Age Backend Failure Research

## Related Artifacts

- [evidence-matrix.md](/home/neg/src/salt/specs/078-gopass-age-research/evidence-matrix.md)
- [symptom-matrix.md](/home/neg/src/salt/specs/078-gopass-age-research/symptom-matrix.md)
- [decision.md](/home/neg/src/salt/specs/078-gopass-age-research/decision.md)
- [verification.md](/home/neg/src/salt/specs/078-gopass-age-research/verification.md)

## Diagnosis Summary

The current workstation is not suffering from a random one-off prompt problem. It shows one combined backend failure class: the `gopass` `age` path still depends on decrypting the protected identities file during secret access, and the current unlock flow does not make that reliable for unattended consumers. In an interactive TTY that degrades into repeated prompting or identities fallback; in a non-interactive context it hard-fails with `pinentry ... inappropriate ioctl for device`.

## Evidence Map

| Diagnosis Topic | Evidence IDs |
|-----------------|--------------|
| Current backend and settings are fixed and known | L001, L002, L003 |
| Agent behavior is part of the intended UX but not sufficient here | L004, L007, U001, U003 |
| The encrypted identities file remains in the critical path | L003, L008, L009, U002, U004 |
| Non-interactive consumers are blocked now | L005, L006 |
| Plaintext identities are not a validated repair path | L010, U002, U004 |

## Local Reproduction Narrative

### Case R001: Non-interactive `gopass show`

1. Baseline the current config with `gopass config`.
2. Confirm the identities file type with `file ~/.config/gopass/age/identities`.
3. Run `gopass show -o email/gmail/address` without a TTY.

Expected result if the backend were salvageable:

- the command would return the secret without prompting again.

Actual result on 2026-03-26:

- `gopass` failed to decrypt `~/.config/gopass/age/identities`;
- `pinentry` reported `could not get state of terminal: inappropriate ioctl for device`;
- no secret value was returned.

### Case R002: `chezmoi apply` as rollout-path consumer

1. Run `chezmoi apply --force --source /home/neg/src/salt/dotfiles`.
2. Let template evaluation reach the first `gopass` lookup.

Expected result if the backend were salvageable:

- `chezmoi` would render templates without a fresh passphrase prompt and without decryption errors.

Actual result on 2026-03-26:

- the same decryption failure on `~/.config/gopass/age/identities` occurred;
- `gopass` returned the same `pinentry` / IOCTL failure;
- `chezmoi` aborted while rendering `dot_config/himalaya/config.toml.tmpl`.

### Case R003: Interactive unlock is not a sufficient acceptance proof

Observed local history for the same workstation on 2026-03-26:

- a prior `strace` showed `gopass show` contacting `gopass-age-agent.sock` and then reopening `~/.config/gopass/age/identities`;
- earlier interactive attempts still fell back to identities decryption instead of becoming prompt-free steady-state reads.

Operational interpretation:

- even when the age-agent path is in play, the backend still relies on identities handling in a way that is not reliable for unattended access.

## Failure Hypothesis

### H001: Age-agent unlock does not provide stable unattended access because the encrypted identities file remains part of the decryption path

- **Summary**: The local backend still needs access to the protected `~/.config/gopass/age/identities` file during reads, and the current `gopass` age-agent flow on this workstation does not eliminate that dependency for unattended execution.
- **Confidence**: strong_inference
- **Supported by**: L002, L003, L004, L005, L006, L007, L009, U001, U003, U004
- **Why this fits the evidence**:
  - the agent is configured but the current read still fails;
  - the identities file is demonstrably encrypted and in active use;
  - the rollout-path consumer fails with the same root symptom as direct non-interactive reads;
  - upstream evidence describes age-agent / passphrase-caching maturity as an area still under active improvement.
- **Disproving conditions**:
  - a repeatable run where both non-interactive `gopass show` and `chezmoi apply` succeed on this host without a fresh prompt;
  - upstream documentation that explicitly states full unattended parity for this identities model and a local reproduction that matches it.

## Why the Plaintext Workaround Fails the Feature Boundary

Replacing `~/.config/gopass/age/identities` with raw `AGE-SECRET-KEY-...` content already caused a regression on this host. That result matters more than the generic fact that `age` itself can read plaintext identity files. The current `gopass` setup is built around its managed identities flow, and this feature is limited to diagnosing that flow without destructive backend migration.

## Operational Conclusion

The current diagnosis supports one conclusion: the workstation is dealing with an age-backend reliability problem, not just a missing prompt frontend. The same failure chain blocks both direct non-interactive secret reads and `chezmoi` rollout rendering, so partial interactive behavior cannot be accepted as a fix.
