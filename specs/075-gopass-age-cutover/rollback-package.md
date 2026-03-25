# Rollback Package Manifest

Date: 2026-03-26
Branch: `075-gopass-age-cutover`

## Backup Artifacts

- Active store copy: `/tmp/gopass-age-cutover-backup/store`
- Active store tarball: `/tmp/gopass-age-cutover-backup/store.tar`
- Store git history tarball: `/tmp/gopass-age-cutover-backup/store-git.tar`

Observed sizes at capture time:

- `/tmp/gopass-age-cutover-backup/store`: `2.3M`
- `/tmp/gopass-age-cutover-backup/store.tar`: `1.6M`
- `/tmp/gopass-age-cutover-backup/store-git.tar`: `1.3M`

## Legacy Unlock Materials

- Current GPG/YubiKey access path remains the only approved rollback decrypt path at capture time.
- The current session could not start a usable `gpg-agent`, so recovery still depends on restoring a healthy legacy decrypt session before rollback validation can be proven.

## Written Rollback Steps

1. Stop any in-progress cutover activity before accepting a mixed or ambiguous store state.
2. Restore the active store contents from `/tmp/gopass-age-cutover-backup/store` or `/tmp/gopass-age-cutover-backup/store.tar`.
3. Restore store git history from `/tmp/gopass-age-cutover-backup/store-git.tar` if store metadata or revision history was modified during cutover.
4. Re-establish the legacy decrypt path so representative `gopass` reads can succeed again.
5. Re-run the frozen validation set from `contracts/validation-matrix.yaml`.
6. Re-run `chezmoi apply --force --source /home/neg/src/salt/dotfiles`.
7. Record whether the cutover is abandoned, retried, or blocked on remediation.

## Age Unlock Artifacts

Current status:

- No working `age` identity has been generated yet.
- Temp-profile rehearsal showed `gopass age identities keygen` requires an interactive passphrase flow.
- Temp-profile rehearsal also confirmed `XDG_CACHE_HOME` must be writable for age backend creation.

## Current Blocker

Live conversion is blocked until both prerequisites exist:

- a working legacy decrypt path for baseline equivalence checks
- a password-protected age identity and unlock flow for the target backend
