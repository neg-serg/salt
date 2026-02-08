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
    app-password          # Gmail App Password (for mbsync/msmtp)
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
```

## Chezmoi Integration

Dotfiles that contain secrets use chezmoi templates (`.tmpl` suffix):

| Dotfile | Template | gopass key |
|---|---|---|
| `~/.config/mbsync/mbsyncrc` | `dot_config/mbsync/mbsyncrc.tmpl` | `email/gmail/app-password` |
| `~/.config/msmtp/config` | `dot_config/msmtp/config.tmpl` | `email/gmail/app-password` |
| `~/.config/imapnotify/gmail.json` | `dot_config/imapnotify/gmail.json.tmpl` | `email/gmail/app-password` |
| `~/.config/vdirsyncer/config` | `dot_config/vdirsyncer/config.tmpl` | `caldav/google/*` |
| `~/.config/opencode/opencode.json` | `dot_config/opencode/opencode.json.tmpl` | `api/*` |

Template syntax:
```
# in dot_config/msmtp/config.tmpl
password {{ gopass "email/gmail/app-password" }}
```

## Salt Integration

For Salt states that need secrets (e.g. systemd service env files):

```yaml
# In system_description.sls or a dedicated state
mpdas_config:
  cmd.run:
    - name: |
        PASS=$(gopass show -o lastfm/password)
        cat > ~/.config/mpdas/mpdas.conf << EOF
        [mpdas]
        password = ${PASS}
        EOF
    - runas: neg
```

## Setup Steps

1. **Initialize gopass store**:
   ```
   gopass init <GPG-KEY-ID>
   gopass git init
   ```

2. **Populate secrets**:
   ```
   gopass insert email/gmail/app-password
   gopass insert caldav/google/client-id
   gopass insert caldav/google/client-secret
   gopass insert api/brave-search
   gopass insert api/github-token
   gopass insert api/context7
   gopass insert lastfm/password
   ```

3. **Configure chezmoi** (in `~/.config/chezmoi/chezmoi.toml`):
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

## Files Requiring Secrets (Migration Status)

| Config | Secrets needed | Status |
|---|---|---|
| mbsync/mbsyncrc | Gmail app password | [ ] |
| msmtp/config | Gmail app password | [ ] |
| imapnotify/gmail.json | Gmail app password | [ ] |
| notmuch/notmuchrc | No secrets (just config) | [ ] |
| vdirsyncer/config | Google OAuth client ID + secret | [ ] |
| khal/config | No secrets (reads vdirsyncer data) | [ ] |
| opencode/opencode.json | Brave, GitHub, Context7 API keys | [ ] |
| mpdas/mpdas.conf | Last.fm password | [ ] |
