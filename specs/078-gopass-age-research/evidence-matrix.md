# Evidence Matrix: Gopass Age Backend Failure Research

## Related Artifacts

- [findings.md](/home/neg/src/salt/specs/078-gopass-age-research/findings.md)
- [symptom-matrix.md](/home/neg/src/salt/specs/078-gopass-age-research/symptom-matrix.md)
- [decision.md](/home/neg/src/salt/specs/078-gopass-age-research/decision.md)
- [verification.md](/home/neg/src/salt/specs/078-gopass-age-research/verification.md)

## Local Baseline Evidence

| ID | Command / Source | Preconditions | Observed Result | Relevance |
|----|------------------|---------------|-----------------|-----------|
| L001 | `gopass version` on 2026-03-26 | Current workstation, branch `078-gopass-age-research` | `gopass 1.16.1 go1.25.5 X:nodwarf5 linux amd64` | Freezes the product version under investigation. |
| L002 | `gopass config` on 2026-03-26 | Current workstation | `age.agent-enabled = true`, `age.agent-timeout = 3600`, store path `/home/neg/.local/share/pass` | Confirms the `age` agent path is configured and the failure is not caused by the flag being disabled. |
| L003 | `file ~/.config/gopass/age/identities` on 2026-03-26 | Current workstation | `age encrypted file, scrypt recipient (N=2**18)` | Confirms the identities file is itself passphrase-encrypted and is not a plaintext `AGE-SECRET-KEY-...` file. |
| L004 | `gopass age agent status` on 2026-03-26 | Current workstation | `Age agent is not running` | Confirms the present baseline is already in a degraded state before any unattended secret read starts. |
| L005 | `gopass show -o email/gmail/address` on 2026-03-26, rerun outside the sandbox | No TTY available | `pinentry error: failed to ask for PIN: could not get state of terminal: inappropriate ioctl for device` | Confirms the non-interactive `gopass show` path is still blocking. |
| L006 | `chezmoi apply --force --source /home/neg/src/salt/dotfiles` on 2026-03-26 | Same workstation, same secret backend | `failed to decrypt /home/neg/.config/gopass/age/identities` followed by the same `pinentry` / IOCTL error inside a `gopass` template call | Confirms the rollout consumer is blocked by the same backend failure class. |
| L007 | `gopass age agent --help` on 2026-03-26 | Installed local binary | The agent is "optional, but recommended" and exists to cache age identities in memory for on-demand access | Shows the product intends the agent to improve usability, but does not prove unattended parity on this host. |
| L008 | `gopass age identities --help` on 2026-03-26 | Installed local binary | `add`, `keygen`, and `remove` subcommands exist for identities management | Confirms `gopass` expects a managed identities workflow instead of an arbitrary raw-key file swap. |
| L009 | Prior local `strace` observation recorded on 2026-03-26 before this implementation pass | Same workstation, same backend | `gopass show` contacted `gopass-age-agent.sock` and then reopened `~/.config/gopass/age/identities` | Connects the agent path and the encrypted identities file into one failure chain. |
| L010 | Prior local plaintext workaround attempt recorded on 2026-03-26 | `~/.config/gopass/age/identities` temporarily replaced with `AGE-SECRET-KEY-...` content | `gopass` failed to decrypt and treated the file as an invalid encrypted identity input | Confirms plaintext conversion is a regression, not a validated fix. |

## Upstream Primary Sources

| ID | Source | Statement / Claim Summary | Status | Relevance |
|----|--------|---------------------------|--------|-----------|
| U001 | `gopass` discussion `#3085` (`https://github.com/gopasspw/gopass/discussions/3085`) reviewed on 2026-03-26 | Maintainer discussion for the `age` backend indicates passphrase-caching and GPG-agent-parity gaps still exist, so `age` support cannot be treated as equivalent to the mature `gpg` path. | Direct maintainer statement reviewed during the research session | Explains why "agent enabled" is not enough to infer unattended reliability. |
| U002 | `gopass` discussion `#3032` (`https://github.com/gopasspw/gopass/discussions/3032`) reviewed on 2026-03-26 | Maintainer guidance for changing age identities points users to the dedicated `gopass age identities ...` workflow instead of direct ad hoc file replacement. | Direct maintainer statement reviewed during the research session | Explains why the encrypted identities file is part of the supported backend model. |
| U003 | `gopass` release `v1.16.0` (`https://github.com/gopasspw/gopass/releases/tag/v1.16.0`) published 2025-11-13 | Release notes introduced `gopass age agent unlock`, showing that age-agent usability was still evolving well after the backend existed in stable releases. | Official release note | Shows that recent work targeted unlock ergonomics, which fits the current failure area. |
| U004 | `age` official README (`https://github.com/FiloSottile/age`) | Identity files may contain plaintext `AGE-SECRET-KEY-...` entries or passphrase-encrypted age files. | Official documentation | Explains why `~/.config/gopass/age/identities` being an encrypted age file is valid in principle. |
| U005 | `gopass` repository README / setup docs (`https://github.com/gopasspw/gopass`) | `gpg` remains the default backend and `age` is an alternative backend selected explicitly during setup. | Official documentation | Supports the conclusion that the `age` path is a non-default backend with different operational properties. |

## Evidence-to-Question Map

| Question | Answering Evidence |
|----------|--------------------|
| Why does the current host still fail after enabling the age agent? | L002, L004, L005, L007, L009, U001, U003 |
| Why is the encrypted identities file central instead of incidental? | L003, L008, L009, L010, U002, U004 |
| Why is plaintext conversion not an approved workaround? | L010, U002, U004 |
| Why does this matter for rollout acceptance rather than only manual shell usage? | L005, L006, U001, U003 |

## Interpretation Boundary

- The current workstation evidence is sufficient to show that the backend fails the unattended acceptance boundary today.
- The discussion-derived maintainer evidence is treated as authoritative for planning, but any claim that cannot be reproduced locally remains labeled separately in [symptom-matrix.md](/home/neg/src/salt/specs/078-gopass-age-research/symptom-matrix.md).
- No evidence in this feature justifies destructive migration of the active store or further plaintext-identity experiments.
