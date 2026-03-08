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
ssh-key                   # SSH key passphrase (~/.ssh/id_ed25519)
yubikey-pin               # Yubikey PIN (for GPG unlock)

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
  proxypilot-local        # ProxyPilot client auth key
  proxypilot-management   # ProxyPilot management API key
  anthropic               # Anthropic API key (direct, for OpenClaw)
  openclaw-telegram       # OpenClaw Telegram bot token
  openclaw-telegram-uid   # OpenClaw Telegram allowlist user ID
  groq                    # Groq API key (free fallback provider)
  cerebras                # Cerebras API key (free fallback provider)
  openrouter              # OpenRouter API key (free fallback provider)

lastfm/
  password                # Last.fm password (for mpdas)
  username                # Last.fm username (for mpdas)
  api-key                 # Last.fm API key (for rescrobbled)
  api-secret              # Last.fm API secret (for rescrobbled)
```

For detailed provisioning instructions for each secret, see `gopass-setup.md`.

## Chezmoi Integration

Dotfiles that contain secrets use chezmoi templates (`.tmpl` suffix):

| Dotfile | Template | gopass key |
|---|---|---|
| `~/.config/mbsync/mbsyncrc` | `dot_config/mbsync/mbsyncrc.tmpl` | `email/gmail/app-password`, `email/gmail/address` |
| `~/.config/msmtp/config` | `dot_config/msmtp/config.tmpl` | `email/gmail/app-password`, `email/gmail/address` |
| `~/.config/imapnotify/gmail.json` | `dot_config/imapnotify/gmail.json.tmpl` | `email/gmail/app-password`, `email/gmail/address` |
| `~/.config/vdirsyncer/config` | `dot_config/vdirsyncer/config.tmpl` | `caldav/google/client-id`, `caldav/google/client-secret` |
| `~/.config/rescrobbled/config.toml` | `dot_config/rescrobbled/config.toml.tmpl` | `lastfm/api-key`, `lastfm/api-secret` |
| `~/.config/zsh/10-secrets.zsh` | `dot_config/zsh/10-secrets.zsh.tmpl` | `api/github-token`, `api/brave-search`, `api/context7`, `api/proxypilot-local` |
| `~/.config/proxypilot/config.yaml` | `dot_config/proxypilot/config.yaml.tmpl` | `api/proxypilot-local`, `api/proxypilot-management` |

Template syntax:
```
# in dot_config/msmtp/config.tmpl
passwordeval   "gopass show -o email/gmail/app-password"
user           {{ gopass "email/gmail/address" }}
```

## Salt Integration

Salt states use the `gopass_secret()` Jinja macro (defined in `_macros_common.jinja`)
which gracefully falls back if gopass is unavailable:

```yaml
# In the .sls file:
{%- set lastfm_user = gopass_secret('lastfm/username') | trim %}
{%- set lastfm_pass = gopass_secret('lastfm/password') | trim %}
mpdas_config:
  file.managed:
    - name: {{ home }}/.config/mpdasrc
    - mode: '0600'
    - replace: False
    - contents: |
        host = localhost
        port = 6600
        username = {{ lastfm_user }}
        password = {{ lastfm_pass }}
```

The macro tries `gopass show -o <key>` first. If it fails (retcode != 0),
it runs an optional fallback command (defaults to `true`, yielding empty string).

Salt states using `gopass_secret()` macro (graceful fallback if gopass unavailable):

| State | gopass key | Fallback |
|---|---|---|
| `mpd.sls` | `lastfm/username`, `lastfm/password` | Empty string |
| `opencode.sls` | `api/proxypilot-local`, `api/proxypilot-management`, `api/groq`, `api/cerebras`, `api/openrouter` | Parse existing ProxyPilot config (AWK fallback) |
| `openclaw_agent.sls` | `api/proxypilot-local`, `api/anthropic`, `api/openclaw-telegram`, `api/openclaw-telegram-uid` | Parse existing config / empty string |

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
