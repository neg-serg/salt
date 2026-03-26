# gopass Setup Guide

Step-by-step instructions for provisioning all secrets required by Salt/chezmoi configuration.
Each secret is consumed by chezmoi templates or Salt states — deployment will fail without them.

## 0. Pre-flight check

```bash
# Verify gopass is initialized
gopass ls

# Check which secrets exist and which are missing
for key in \
    email/gmail/app-password email/gmail/address \
    caldav/google/client-id caldav/google/client-secret \
    lastfm/username lastfm/password lastfm/api-key lastfm/api-secret \
    api/github-token api/brave-search api/context7 \
    api/proxypilot-local api/proxypilot-management \
    api/anthropic api/openclaw-telegram api/openclaw-telegram-uid \
    ssh-key yubikey-pin; do
  if gopass show -o "$key" >/dev/null 2>&1; then
    echo "  ✓ $key"
  else
    echo "  ✗ $key  (MISSING)"
  fi
done
```

---

## 1. Initialize gopass (if store doesn't exist)

Choose one approved backend and keep the same `gopass` entry paths regardless of backend:

```bash
# GPG backend (existing hardware-backed flow)
gopass init <GPG-KEY-ID>
gpg-connect-agent /bye
~/.local/bin/gpg-warmup
gopass show -o email/gmail/address

# age backend (password-protected identity flow)
export GPG_TTY="$(tty)"
gopass age identities keygen
gopass init --crypto age

gopass git init

# Verify
gopass ls
```

---

## 2. SSH and backend-specific unlock material (`unlock` script)

Used by: `~/.local/bin/unlock` — automatic SSH key unlock at login.

### 2a. SSH key passphrase

```bash
# Passphrase for ~/.ssh/id_ed25519
gopass insert ssh-key
```

### 2b. Yubikey PIN

```bash
# PIN for unlocking the Yubikey GPG key. Only used with the GPG/Yubikey backend.
gopass insert yubikey-pin
```

If the current fallback path is `gpg + gpg-agent`, validate it from an interactive
session with one real decrypt, not just `gpg --list-keys`:

```bash
gpg-connect-agent /bye
~/.local/bin/gpg-warmup
gopass show -o email/gmail/address
```

### 2c. age identity unlock

If using the `age` backend, protect the generated identity with a strong password and
store the recovery instructions outside the store itself. Recommended session flow:

```bash
# One-time setup
export GPG_TTY="$(tty)"
gopass age identities keygen

# Optional session agent
gopass config age.agent-enabled true
gopass age agent start
gopass age agent unlock
```

Run the initial identity generation and later unlock commands from an interactive user
session with a working TTY or pinentry path. `gopass ls` alone is not enough to prove
that decryption works; verify the unlock path with `gopass show -o <known-key>`.

Keep a secure backup of the `age` identity and the password needed to unlock it.
Do not remove the previous GPG/Yubikey access path until a 7-day stabilization
window has passed with no fallback to the old path and no unresolved required-workflow
failures.

---

## 3. Email — Gmail

Used by: `mbsync` (mail fetch), `msmtp` (send), `imapnotify` (push notifications).
Templates: `dot_config/mbsync/mbsyncrc.tmpl`, `dot_config/msmtp/config.tmpl`, `dot_config/imapnotify/gmail.json.tmpl`

### 3a. Gmail address

```bash
gopass insert email/gmail/address
# Enter: your gmail address (e.g. serg.zorg@gmail.com)
```

### 3b. Gmail App Password

**How to obtain:**
1. Go to https://myaccount.google.com/apppasswords
2. Choose an app name (e.g. "mbsync")
3. Click "Create"
4. Copy the generated 16-character password

**Requirement:** 2FA must be enabled on the account (App Passwords are unavailable without it).

```bash
gopass insert email/gmail/app-password
# Enter: 16-character App Password (no spaces)
```

---

## 4. Calendar — Google OAuth (vdirsyncer)

Used by: `vdirsyncer` (sync Google Calendar → local .ics files).
Template: `dot_config/vdirsyncer/config.tmpl`

**How to obtain:**
1. Go to https://console.cloud.google.com/
2. Create a project (or select existing)
3. Go to **APIs & Services → Library**
4. Find and enable **Google Calendar API**
5. Go to **APIs & Services → Credentials**
6. Click **Create Credentials → OAuth client ID**
7. Application type: **Desktop app**
8. Name: anything (e.g. "vdirsyncer")
9. Click **Create**
10. Copy **Client ID** and **Client Secret**

**Important:** You also need to configure the OAuth consent screen:
- **APIs & Services → OAuth consent screen**
- User type: External (or Internal for Google Workspace)
- Add scope: `Google Calendar API — .../auth/calendar`
- Add your email to test users (if app is in Testing status)

```bash
gopass insert caldav/google/client-id
# Enter: Client ID (format: xxxx.apps.googleusercontent.com)

gopass insert caldav/google/client-secret
# Enter: Client Secret (format: GOCSPX-xxx)
```

---

## 5. Last.fm (mpdas + rescrobbled)

Used by: `mpdas` (scrobbler via Salt state `mpd.sls`), `rescrobbled` (alternative scrobbler).
Template: `dot_config/rescrobbled/config.toml.tmpl`

### 5a. Last.fm credentials

```bash
gopass insert lastfm/username
# Enter: your Last.fm username

gopass insert lastfm/password
# Enter: your Last.fm password
```

### 5b. Last.fm API keys

**How to obtain:**
1. Go to https://www.last.fm/api/account/create
2. Log in (if not already)
3. Fill the form:
   - Application name: anything (e.g. "rescrobbled")
   - Application description: anything
   - Callback URL: leave empty
4. Click **Submit**
5. Copy **API key** and **Shared secret**

```bash
gopass insert lastfm/api-key
# Enter: API key (32 hex characters)

gopass insert lastfm/api-secret
# Enter: Shared secret (32 hex characters)
```

---

## 6. API keys (zsh environment)

Used by: `~/.config/zsh/10-secrets.zsh` — exported as environment variables.
Template: `dot_config/zsh/10-secrets.zsh.tmpl`

### 6a. GitHub Personal Access Token

**How to obtain:**
1. Go to https://github.com/settings/tokens?type=beta
2. Click **Generate new token**
3. Select permissions (minimum: `repo`, `read:org`)
4. Set expiration
5. Click **Generate token**
6. Copy the token (shown only once!)

```bash
gopass insert api/github-token
# Enter: github_pat_xxx or ghp_xxx
```

### 6b. Brave Search API Key

**How to obtain:**
1. Go to https://api.search.brave.com/app/keys
2. Register / log in
3. Create a key (Free plan: 2000 requests/month)
4. Copy the API key

```bash
gopass insert api/brave-search
# Enter: BSA-xxx
```

### 6c. Context7 API Key

**How to obtain:**
1. Go to https://context7.com/
2. Register / log in
3. Get the API key from account settings

```bash
gopass insert api/context7
# Enter: your Context7 API key
```

---

## 7. ProxyPilot + OpenClaw (AI tooling)

Used by: ProxyPilot (AI API proxy), OpenClaw (AI agent gateway), OpenCode (TUI agent).
Templates: `dot_config/proxypilot/config.yaml.tmpl`, `dot_config/zsh/10-secrets.zsh.tmpl`
Salt states: `opencode.sls`, `openclaw_agent.sls`

### 7a. ProxyPilot API Key (client auth)

This key authenticates local AI tools (Claude Code, OpenCode) against the ProxyPilot proxy.

```bash
gopass insert api/proxypilot-local
# Enter: API key for ProxyPilot client auth
```

### 7b. ProxyPilot Management Key

Dashboard/stats access for the proxy management API (localhost only).

```bash
gopass insert api/proxypilot-management
# Enter: management API key
```

### 7c. Anthropic API Key (direct)

Used by OpenClaw as primary provider (direct Anthropic API access).

```bash
gopass insert api/anthropic
# Enter: sk-ant-xxx (Anthropic API key)
```

### 7d. OpenClaw Telegram Bot

Used by OpenClaw for Telegram integration.

```bash
gopass insert api/openclaw-telegram
# Enter: Telegram bot token (format: 123456:ABC-DEF...)

gopass insert api/openclaw-telegram-uid
# Enter: Telegram user ID for allowlist (e.g. 109503498)
```

---

## 8. Backend bootstrap reference

### 8a. GPG Key ID

When initializing the GPG backend (step 1), `<GPG-KEY-ID>` is your GPG key fingerprint.
To find it:

```bash
gpg --list-keys --keyid-format long
# Look for the 40-character fingerprint or the 16-char key ID after "rsa4096/"
# Example: gpg --list-keys shows "Key fingerprint = ABCD 1234 ..."
# Use the full fingerprint: gopass init ABCD1234...
```

If using a Yubikey, the key is on the card:

```bash
gpg --card-status
# Look for "General key info" line — that's your key ID
```

### 8b. age identity recovery

When initializing the `age` backend:

- generate the identity once and protect it with a strong password;
- back up the identity file separately from the working store;
- record how to unlock it on a new machine before retiring any legacy GPG access.

For the short transfer/recovery runbook, see `docs/gopass-age-recovery.md`.

### 8c. Migration cutover guardrails

If you are migrating an existing store from GPG/Yubikey to `age`:

- keep `gopass` as the only public interface for Salt, chezmoi, and scripts;
- build a rollback package before cutover: active store copy, store git history, legacy unlock materials, and written rollback steps;
- validate representative CLI reads, chezmoi templates, Salt consumers, and a representative subset of attached files or other non-password entries;
- keep existing git history unchanged during the main migration and document the residual risk instead of rewriting history inline;
- use one maintainer/operator as the cutover and rollback owner;
- retire the legacy path only after 7 consecutive days with no fallback use and no unresolved failures.

---

## 9. Apply

After provisioning all secrets:

```bash
# Verify all secrets are present (script from step 0)
# Then:

# Salt state — deploys configs, systemd services
sudo salt-call state.apply

# Chezmoi — renders templates with secrets (requires a working gopass unlock path)
chezmoi diff      # preview changes
chezmoi apply -v  # apply
```

If `chezmoi apply` fails after a successful Salt run, re-check the active backend
unlock path for the current user session, then see `scripts/salt-apply.sh` diagnostics.

---

## 10. Enable services

```bash
# Mail
systemctl --user enable --now mbsync-gmail.timer
systemctl --user enable --now imapnotify-gmail.service

# Calendar
systemctl --user enable --now vdirsyncer.timer

# Verify
systemctl --user list-timers
systemctl --user status mbsync-gmail.timer imapnotify-gmail vdirsyncer.timer
```

---

## 11. Initial sync

```bash
# Mail — first full sync (may take a while)
mbsync gmail

# Notmuch — initialize search database
notmuch new

# Calendar — first sync (opens browser for OAuth authorization)
vdirsyncer discover
vdirsyncer sync
```

---

## 12. Final verification

```bash
# All secrets present
gopass ls

# chezmoi — no drift
chezmoi verify

# Mail
ls ~/.local/mail/gmail/INBOX/

# Calendar
khal list today 7d

# MPD scrobbling
systemctl --user status rescrobbled

# API keys in environment
source ~/.config/zsh/10-secrets.zsh
echo $GITHUB_TOKEN | head -c4    # token prefix
echo $BRAVE_API_KEY | head -c4
```
