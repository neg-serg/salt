# Rollback Acceptance Evidence

Date: 2026-03-26
Branch: `075-gopass-age-cutover`

## Status

- Rollback exercise not yet executed.
- Rollback package prepared: see `rollback-package.md`.
- Rollback acceptance remains blocked on the same live-session prerequisites as forward cutover:
  - a working legacy decrypt path
  - an interactive passphrase/unlock path for the target backend

## Planned Acceptance Checks

- Restore the previous working store as the active source of truth.
- Re-run representative `gopass` reads from `baseline.md`.
- Re-run `chezmoi apply --force --source /home/neg/src/salt/dotfiles`.
- Re-check the representative special-entry subset.
- Record whether another cutover attempt is allowed.
