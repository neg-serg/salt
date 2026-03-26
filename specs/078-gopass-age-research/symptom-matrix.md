# Symptom Matrix: Gopass Age Backend Failure Research

## Related Artifacts

- [evidence-matrix.md](/home/neg/src/salt/specs/078-gopass-age-research/evidence-matrix.md)
- [findings.md](/home/neg/src/salt/specs/078-gopass-age-research/findings.md)
- [decision.md](/home/neg/src/salt/specs/078-gopass-age-research/decision.md)
- [verification.md](/home/neg/src/salt/specs/078-gopass-age-research/verification.md)

| Symptom ID | Context | Trigger | Observable Output / Behavior | Impacted Workflow | Upstream Status | Evidence |
|------------|---------|---------|------------------------------|------------------|-----------------|----------|
| S001 | interactive_tty | `gopass age agent unlock` followed by a later `gopass show` in a TTY | Prompt-free steady-state use is not established; prior local runs fell back to identities decryption or a fresh prompt instead of a clean cached read. | Manual operator use, precursor to rollout trust | partially_confirmed | L009, U001, U003 |
| S002 | noninteractive_shell | `gopass show -o email/gmail/address` without a TTY | `pinentry error: failed to ask for PIN: could not get state of terminal: inappropriate ioctl for device` | Any unattended consumer that shells out to `gopass` | local_only for the exact error text; partially_confirmed for the broader unlock/caching gap | L005, U001, U003 |
| S003 | rollout_path | `chezmoi apply --force --source /home/neg/src/salt/dotfiles` | Template rendering aborts after `gopass` fails to decrypt `~/.config/gopass/age/identities` and returns the same non-interactive `pinentry` error | Rollout / dotfiles application | local_only | L006 |
| S004 | agent_plus_identities_path | Secret read after age-agent participation | The process touches or depends on both `gopass-age-agent.sock` and the encrypted identities file instead of behaving like a one-time unlock with prompt-free reads. | Diagnosis of the backend chain itself | partially_confirmed | L007, L009, U001, U003 |
| S005 | workaround_regression | Replace `~/.config/gopass/age/identities` with plaintext `AGE-SECRET-KEY-...` content | Decryption fails; the workaround does not repair the backend on this workstation | Unsafe debugging path | local_only, with upstream docs showing the generic file format is valid outside this exact setup | L010, U002, U004 |

## Recognition Notes

- S001 and S002 should be treated as one failure family with different surfaces, not as isolated bugs.
- S003 is the acceptance-boundary symptom because it shows the failure inside a real rollout workflow.
- S004 is the strongest clue that the identities file remains in the active decryption path even when the age agent is involved.
- S005 exists to prevent repeating an already disproven workaround on this host.
