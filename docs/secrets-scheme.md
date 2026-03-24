# Secrets Management Scheme

## Architecture

```
gopass (encrypted store; approved backend: gpg or age)
  |
  +---> chezmoi templates   (dotfiles with secrets)
  +---> salt cmd.run        (systemd services, etc.)
```

**Single source of truth**: `gopass` with an approved encrypted backend.
Both chezmoi and Salt read secrets from gopass at deploy time.

Approved backends:

- `gpg`: existing hardware-backed flow (for example YubiKey + GPG agent)
- `age`: password-protected identity flow with documented backup and recovery handling

## gopass Store Layout

```
ssh-key                   # SSH key passphrase (~/.ssh/id_ed25519)
yubikey-pin               # Yubikey PIN (only needed if the GPG/Yubikey backend is used)

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
  openclaw-telegram-uid   # OpenClaw Telegram allowlist user ID (primary)
  telegram-uid-levra      # Telegram user ID for guest user levra
  telegram-uid-guest2     # Telegram user ID for guest user guest2
  groq                    # Groq API key (free fallback provider)
  cerebras                # Cerebras API key (free fallback provider)
  openrouter              # OpenRouter API key (free fallback provider)
  deepseek                # DeepSeek API key (optional — trial 5M tokens)

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
| `openclaw_agent.sls` | `api/proxypilot-local`, `api/openclaw-telegram`, `api/openclaw-telegram-uid`, `api/telegram-uid-levra`, `api/telegram-uid-guest2`, `api/groq` | Parse existing config / credential files |
| `telethon_bridge.sls` | `api/proxypilot-local`, `api/telegram-telethon-id`, `api/telegram-telethon-hash`, `api/openclaw-telegram-uid`, `api/telegram-uid-levra`, `api/telegram-uid-guest2` | Credential files |

## Setup Steps

1. **Initialize gopass store** (if not already done):
   ```
   # Existing hardware-backed flow
   gopass init <GPG-KEY-ID>

   # Password-based age flow
   gopass age identities keygen
   gopass init --crypto age

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

- Secrets remain encrypted at rest through `gopass`
- `gpg` backend can require hardware-backed unlock such as YubiKey touch
- `age` backend can use a password-protected identity with agent-assisted session unlock
- gopass store can be versioned in a separate private git repo
- No plaintext secrets in the salt/ or dotfiles/ repos
- chezmoi templates contain only gopass references, not actual values
- Rendered files with secrets get 0600 permissions
- Backend migrations must preserve secret paths, keep one active source of truth, and retain rollback artifacts until the stabilization window ends
