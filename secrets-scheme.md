# Secrets Management Scheme

## Architecture

```
gopass (GPG-encrypted store, Yubikey)
  |
  +---> chezmoi templates   (dotfiles with secrets)
  +---> salt cmd.run         (systemd services, etc.)
```

**Single source of truth**: `gopass` with GPG backend (Yubikey hardware key).
Both chezmoi and Salt read secrets from gopass at deploy time.

## gopass Store Layout

```
email/
  gmail/
    app-password          # Gmail App Password (for mbsync/msmtp/imapnotify)
    address               # serg.zorg@gmail.com

caldav/
  google/
    client-id             # Google Calendar OAuth client ID
    client-secret         # Google Calendar OAuth client secret

api/
  brave-search            # Brave Search API key
  github-token            # GitHub personal access token
  context7                # Context7 API key

lastfm/
  password                # Last.fm password (for mpdas)
  username                # Last.fm username (for mpdas)
  api-key                 # Last.fm API key (for rescrobbled)
  api-secret              # Last.fm API secret (for rescrobbled)
```

## Chezmoi Integration

Dotfiles that contain secrets use chezmoi templates (`.tmpl` suffix):

| Dotfile | Template | gopass key |
|---|---|---|
| `~/.config/mbsync/mbsyncrc` | `dot_config/mbsync/mbsyncrc.tmpl` | `email/gmail/app-password`, `email/gmail/address` |
| `~/.config/msmtp/config` | `dot_config/msmtp/config.tmpl` | `email/gmail/app-password`, `email/gmail/address` |
| `~/.config/imapnotify/gmail.json` | `dot_config/imapnotify/gmail.json.tmpl` | `email/gmail/app-password`, `email/gmail/address` |
| `~/.config/vdirsyncer/config` | `dot_config/vdirsyncer/config.tmpl` | `caldav/google/client-id`, `caldav/google/client-secret` |
| `~/.config/rescrobbled/config.toml` | `dot_config/rescrobbled/config.toml.tmpl` | `lastfm/api-key`, `lastfm/api-secret` |
| `~/.config/zsh/10-secrets.zsh` | `dot_config/zsh/10-secrets.zsh.tmpl` | `api/github-token`, `api/brave-search`, `api/context7` |

Template syntax:
```
# in dot_config/msmtp/config.tmpl
passwordeval   "gopass show -o email/gmail/app-password"
user           {{ gopass "email/gmail/address" }}
```

## Salt Integration

For Salt states that need secrets (e.g. mpdas config in `mpd.sls`):

```yaml
mpdas_config:
  cmd.run:
    - name: |
        USER=$(gopass show -o lastfm/username)
        PASS=$(gopass show -o lastfm/password)
        cat > ~/.config/mpdas/mpdas.rc << EOF
        host = localhost
        port = 6600
        service = lastfm
        username = ${USER}
        password = ${PASS}
        EOF
    - runas: neg
    - creates: ~/.config/mpdas/mpdas.rc
```

## Setup Steps

1. **Initialize gopass store** (if not already done):
   ```
   gopass init <GPG-KEY-ID>
   gopass git init
   ```

2. **Populate secrets**:
   ```
   gopass insert email/gmail/app-password
   gopass insert email/gmail/address
   gopass insert caldav/google/client-id
   gopass insert caldav/google/client-secret
   gopass insert api/brave-search
   gopass insert api/github-token
   gopass insert api/context7
   gopass insert lastfm/password
   gopass insert lastfm/username
   gopass insert lastfm/api-key
   gopass insert lastfm/api-secret
   ```

3. **Configure chezmoi** (deployed by Salt from `dotfiles/dot_config/chezmoi/chezmoi.toml`):
   ```toml
   [gopass]
   command = "gopass"
   ```

4. **Deploy dotfiles with secrets**:
   ```
   chezmoi apply
   ```

## Security Properties

- Secrets encrypted at rest with GPG (AES-256)
- Decryption requires Yubikey physical touch
- gopass store can be versioned in a separate private git repo
- No plaintext secrets in the salt/ or dotfiles/ repos
- chezmoi templates contain only gopass references, not actual values
- Rendered files with secrets get 0600 permissions

## Files Requiring Secrets (Migration Status)

| Config | Secrets needed | Status |
|---|---|---|
| mbsync/mbsyncrc | Gmail app password, address | [x] chezmoi template |
| msmtp/config | Gmail app password, address | [x] chezmoi template |
| imapnotify/gmail.json | Gmail app password, address | [x] chezmoi template |
| notmuch/notmuchrc | No secrets (just config) | [x] plain dotfile |
| vdirsyncer/config | Google OAuth client ID + secret | [x] chezmoi template |
| khal/config | No secrets (reads vdirsyncer data) | [x] plain dotfile |
| rescrobbled/config.toml | Last.fm API key + secret | [x] chezmoi template |
| zsh/10-secrets.zsh | API keys (GitHub, Brave, Context7) | [x] chezmoi template |
| mpdas/mpdas.rc | Last.fm username + password | [x] Salt cmd.run + gopass |
