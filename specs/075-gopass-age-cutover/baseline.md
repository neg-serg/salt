# Baseline Evidence

Date: 2026-03-26
Branch: `075-gopass-age-cutover`

## Active Store State

- Active store path: `/home/neg/.local/share/pass`
- Current backend marker: `.gpg-id` present
- Current age marker: `.age-recipients` absent
- `gopass` config `mounts.path`: `/home/neg/.local/share/pass`
- `gopass` version: `1.16.1`
- Session observation:
  - `gopass ls` succeeds in the current user session
  - decrypting reads do not succeed in the current session
  - `chezmoi diff --source /home/neg/src/salt/dotfiles` fails with `gopass` decryption errors in the current session

## Validation Boundary

High-priority cases frozen from `contracts/validation-matrix.yaml`:

- `cli-root-secret`
- `cli-nested-secret`
- `chezmoi-secret-templates`
- `chezmoi-apply-current-session`
- `salt-proxypilot-consumers`
- `salt-apply-preflight`
- `repo-validation`

Medium-priority cases included for baseline continuity:

- `salt-lastfm-consumer`
- `special-entry-subset`

## Representative Secret Consumers

- CLI:
  - `ssh-key`
  - `email/gmail/app-password`
  - `api/proxypilot-local`
- chezmoi templates:
  - `dotfiles/dot_config/himalaya/config.toml.tmpl`
  - `dotfiles/dot_config/mbsync/mbsyncrc.tmpl`
  - `dotfiles/dot_config/zsh/10-secrets.zsh.tmpl`
- Salt/script consumers:
  - `states/mpd.sls`
  - `states/opencode.sls`
  - `states/openclaw_agent.sls`
  - `states/telethon_bridge.sls`
  - `scripts/salt-apply.sh`

## Special-Entry Subset

Representative non-standard records selected for continuity checks:

- `recov/MEGA-RECOVERYKEY.txt`
- `recov/github-recovery-codes.txt`

## Baseline Command Outcomes

- `gopass ls`: success
- `gopass sum ssh-key email/gmail/app-password api/proxypilot-local`: failed because the current session has no working GPG decrypt path
- `gopass sum recov/MEGA-RECOVERYKEY.txt recov/github-recovery-codes.txt`: failed because the current session has no working GPG decrypt path
- `chezmoi diff --source /home/neg/src/salt/dotfiles`: failed because `gopass show --password email/gmail/address` failed to decrypt
- `gpg --card-status`: failed because no `gpg-agent` was running in the current session

## Immediate Blocker

The legacy decrypt path is not healthy enough to prove plaintext equivalence before cutover:

- listing the store works
- decrypting reads do not
- cutover must not proceed until the legacy path can decrypt representative entries or an explicit override is accepted
