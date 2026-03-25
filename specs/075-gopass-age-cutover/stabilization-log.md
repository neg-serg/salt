# Stabilization Tracking Log

Date: 2026-03-26
Branch: `075-gopass-age-cutover`

## Status

- Stabilization window has not started.
- Start condition is blocked until:
  - the active store is successfully converted to `age`
  - representative post-cutover reads pass
  - the first post-cutover `chezmoi apply` succeeds in the same session

## Required Workflows to Track

- Representative `gopass show -o <known-key>` checks
- `chezmoi apply --force --source /home/neg/src/salt/dotfiles`
- Secret-dependent Salt/script workflows covered by `contracts/validation-matrix.yaml`

## Fallback / Failure Tracking

- Record any fallback to the legacy GPG/YubiKey path.
- Record unresolved failures that block legacy retirement.
- Record the final legacy-retirement decision only after 7 consecutive clean days.
