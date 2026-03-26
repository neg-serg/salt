# Quickstart: Gopass Age Backend Failure Research

## 1. Preconditions

- Current branch: `078-gopass-age-research`
- The active store remains readable enough to inspect metadata without destructive migration steps
- `gopass 1.16.1` is installed on the workstation
- The operator can run read-only `gopass` diagnostics and inspect `~/.config/gopass/age/identities`
- Primary-source internet access is available for upstream GitHub discussions and releases

## 2. Freeze the Investigation Boundary

Before running more experiments, treat the following as in scope:

1. Repeated prompting or decryption fallback tied to `gopass` `age` identities handling.
2. Non-interactive failures that break `chezmoi apply` or equivalent rollout steps.
3. Upstream maintainer guidance about `age` support, passphrase caching, and agent behavior.

Treat the following as out of scope for this feature:

1. Destructive store migration steps.
2. Plaintext-secret extraction into the repository.
3. Long-term backend implementation changes.

## 3. Capture the Current Local State

Record these baseline facts:

```bash
gopass version
gopass config
file ~/.config/gopass/age/identities
gopass show -o email/gmail/address
```

If deeper confirmation is needed, use non-destructive tracing to confirm whether `gopass show` contacts `gopass-age-agent.sock` and then reopens `~/.config/gopass/age/identities`.

## 4. Gather Primary Sources

Use upstream sources that directly discuss `gopass` `age` behavior:

- `https://github.com/gopasspw/gopass/discussions/3085`
- `https://github.com/gopasspw/gopass/discussions/3032`
- `https://github.com/gopasspw/gopass/releases/tag/v1.16.0`
- `https://github.com/FiloSottile/age`

The minimum acceptable evidence set is:

1. One maintainer statement about passphrase caching or agent behavior.
2. One maintainer statement about how `gopass` expects age identities to be managed.
3. One release or official reference showing relevant `age` support evolution.

## 5. Build the Symptom Matrix

For each locally observed symptom, record:

1. Trigger context: interactive, non-interactive, or rollout path.
2. Exact command or workflow.
3. Observable failure text or behavior.
4. Whether upstream explicitly confirms, partially confirms, or does not confirm it.

Minimum matrix rows for this feature:

- repeated prompting after `gopass age agent unlock`
- non-interactive `pinentry`/IOCTL failure
- identities-file involvement after agent socket activity
- plaintext identities workaround causing decryption regression

## 6. Decide Salvage vs Migration

Use this decision rule:

- If upstream still documents incomplete passphrase caching or missing GPG-agent parity, and either non-interactive `gopass show` or `chezmoi apply` still fails after non-destructive validation, stop debugging the current backend and prepare migration planning.
- If unattended local reads become reliable and upstream evidence no longer contradicts that result, document the conditions and continue with targeted remediation instead of migration.

If migration planning is required, the next feature must decide the target backend first instead of assuming either `gpg` or another `age` strategy in advance.

## 7. Completion Criteria

The research feature is complete when:

- all required primary sources are cited;
- every local symptom is classified by confirmation status;
- the acceptance boundary for unattended rollout use is explicit, including both non-interactive `gopass show` and `chezmoi apply`; and
- the next feature choice is clear: continue debugging or start migration planning.

## 8. Related Artifacts

- [evidence-matrix.md](/home/neg/src/salt/specs/078-gopass-age-research/evidence-matrix.md)
- [findings.md](/home/neg/src/salt/specs/078-gopass-age-research/findings.md)
- [symptom-matrix.md](/home/neg/src/salt/specs/078-gopass-age-research/symptom-matrix.md)
- [decision.md](/home/neg/src/salt/specs/078-gopass-age-research/decision.md)
- [verification.md](/home/neg/src/salt/specs/078-gopass-age-research/verification.md)
