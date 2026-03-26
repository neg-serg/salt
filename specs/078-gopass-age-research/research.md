# Phase 0 Research: Gopass Age Backend Failure Research

## Decision 1: Treat passphrase caching gaps as an upstream limitation, not a local guess

- **Decision**: Use upstream maintainer statements about `age` passphrase caching and agent replacement gaps as a primary explanation boundary for the current failure class.
- **Rationale**: In March 2025, a maintainer explicitly stated that `gopass` still has gaps around passphrase caching and does not have a working GPG-agent replacement for the `age` backend. That directly matches the local symptom family where unlocking the `age` agent does not make unattended secret reads reliable.
- **Alternatives considered**:
  - Assume the repeated prompt is only a local `pinentry` packaging problem: rejected because upstream already documents a broader usability gap.
  - Assume the backend is feature-complete because it exists in released builds: rejected because upstream describes remaining behavior gaps despite release availability.

## Decision 2: Treat the current host issue as a combined interactive and non-interactive failure mode

- **Decision**: Model the failure as two linked symptoms: repeated passphrase prompts in interactive use and hard failure in non-interactive use.
- **Rationale**: The current host reproduces `gopass show -o email/gmail/address` failing non-interactively with `pinentry error: failed to ask for PIN: could not get state of terminal: inappropriate ioctl for device`, while interactive attempts still fall back to decrypting `~/.config/gopass/age/identities`. The two symptoms point to the same unreliable unlock path rather than separate independent bugs.
- **Alternatives considered**:
  - Treat only the non-interactive failure as relevant: rejected because repeated interactive prompts also violate the expected agent-assisted usability boundary.
  - Treat only the interactive prompt as relevant: rejected because unattended rollout breakage is the operational acceptance boundary.

## Decision 3: Treat `gopass age agent unlock` as insufficient evidence of unattended readiness

- **Decision**: Do not accept a successful `gopass age agent unlock` invocation as proof that unattended secret reads are fixed.
- **Rationale**: On the current host, `gopass age agent unlock` can complete while later `gopass show` still connects to `gopass-age-agent.sock`, opens the encrypted identities file, and then either prompts again or fails non-interactively. Upstream release work around `age agent unlock` therefore has to be treated as an improvement, not a guarantee of parity with GPG-agent behavior.
- **Alternatives considered**:
  - Treat `age.agent-enabled = true` plus a running agent service as sufficient proof: rejected because observed reads still fail.
  - Increase `age.agent-timeout` and infer success from configuration alone: rejected because the local host already reproduced the failure with `age.agent-timeout = 3600`.

## Decision 4: Reject plaintext identity-file conversion as a validated fix for this setup

- **Decision**: Do not pursue conversion of `~/.config/gopass/age/identities` into a plaintext `AGE-SECRET-KEY-...` file as part of this feature.
- **Rationale**: Maintainer guidance around the `age` backend assumes an internal protected keyring/identities flow, and the current host already demonstrated that replacing the identities file with plaintext broke decryption rather than fixing prompting. That makes plaintext conversion both unvalidated and operationally unsafe for this environment.
- **Alternatives considered**:
  - Keep iterating on plaintext-file formatting until `gopass` accepts it: rejected because it already diverges from the local encrypted-identities model and caused a regression.
  - Store raw keys elsewhere and bypass `gopass` identity handling: rejected because it changes the backend model instead of diagnosing the current one.

## Decision 5: Use encrypted identities handling as a key diagnostic boundary

- **Decision**: Treat the encrypted `~/.config/gopass/age/identities` file as central to the diagnosis rather than an incidental implementation detail.
- **Rationale**: Upstream guidance for modifying age identities involves `gopass age identities add` and explicitly references the protected keyring identities file. On the current host, `file ~/.config/gopass/age/identities` reports an `age encrypted file, scrypt recipient`, and previous `strace` evidence showed `gopass show` opening that file after contacting the agent socket. This makes identities-file handling a necessary part of any explanation.
- **Alternatives considered**:
  - Focus only on the secret store under `~/.local/share/pass`: rejected because the failure occurs before a stable decrypt path is established.
  - Treat the identities file as a generic `age` artifact with no `gopass`-specific meaning: rejected because upstream `gopass age` workflows explicitly manage it.

## Decision 6: Define salvageability by explicit unattended success criteria, not by partial interactive success

- **Decision**: Consider the current backend salvageable only if both non-interactive `gopass show` and `chezmoi apply` succeed on the current machine without a new passphrase prompt.
- **Rationale**: The practical blocker is not whether an operator can eventually unlock a secret in a TTY, but whether the two critical unattended consumers on this workstation can proceed without a fresh prompt. A backend that still breaks either non-interactive `gopass show` or `chezmoi apply` does not satisfy the workstation's operational need.
- **Alternatives considered**:
  - Accept "usable enough for manual shell work" as success: rejected because it leaves rollout blocked.
  - Require parity with every GPG workflow before deciding: rejected because the minimum acceptance boundary is unattended secret consumption for current automation paths.

## Decision 7: If the current evidence remains unchanged, the next step is target-backend selection

- **Decision**: If the clarified salvage threshold is not met, the next feature must first choose the target backend instead of assuming either a return to `gpg` or a different `age` strategy.
- **Rationale**: The current feature is diagnostic. It should hand off a justified decision boundary, not smuggle in an unvetted migration destination. Choosing the backend first keeps the next planning step honest about tradeoffs.
- **Alternatives considered**:
  - Assume a return to `gpg` immediately: rejected because that is a separate decision with its own constraints.
  - Assume another `age` strategy immediately: rejected because that also prejudges the outcome before comparative planning.

## Decision 8: If the current evidence remains unchanged, migration planning is the default operational direction

- **Decision**: Use the following stop condition: if upstream continues to describe passphrase caching/agent parity as incomplete and local unattended reads continue to fail after non-destructive validation, stop iterating on ad hoc backend tweaks and move to migration planning.
- **Rationale**: Continuing to experiment past that boundary increases risk to the password store without changing the operational decision. The research feature should end with a clear branch point, not endless tuning.
- **Alternatives considered**:
  - Continue backend debugging indefinitely until a local workaround appears: rejected because it has already produced unsafe experiments without reliable unattended behavior.
  - Migrate immediately without documenting why: rejected because the next feature still needs a defensible rationale and acceptance boundary.

## Clarifications Resolved

- **Primary failure target**: The feature investigates repeated prompting and non-interactive `pinentry` failure as one failure class.
- **Acceptance boundary**: The backend is salvageable only if both non-interactive `gopass show` and `chezmoi apply` succeed on the current machine without a new prompt.
- **Upstream evidence scope**: Maintainer discussions and release notes are authoritative enough for planning decisions when official docs are sparse.
- **Unsafe workaround boundary**: Plaintext identities conversion is out of scope after demonstrated breakage on the current host.
- **Decision output**: If migration is required, the handoff is a target-backend selection decision, not a preselected cutover destination.

## Related Artifacts

- [evidence-matrix.md](/home/neg/src/salt/specs/078-gopass-age-research/evidence-matrix.md)
- [findings.md](/home/neg/src/salt/specs/078-gopass-age-research/findings.md)
- [symptom-matrix.md](/home/neg/src/salt/specs/078-gopass-age-research/symptom-matrix.md)
- [decision.md](/home/neg/src/salt/specs/078-gopass-age-research/decision.md)
- [verification.md](/home/neg/src/salt/specs/078-gopass-age-research/verification.md)
