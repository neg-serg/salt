# Telethon Bridge Setup

## Overview

Telethon Bridge is a standalone AI agent that connects Telegram via MTProto (userbot)
to ProxyPilot for AI-powered conversations. Unlike bot-based integrations, it uses a
regular Telegram account session (Telethon), enabling richer interaction without
BotFather limitations. Deployed as a systemd user service via Salt.

## Architecture

```
Telegram (MTProto)
        |
        v
+---------------------------+
|  telethon-bridge           |  <- systemd user service
|  http://127.0.0.1:8319     |     health endpoint
+------------+--------------+
             |
             v
+---------------------------+
|  ProxyPilot               |  <- OpenAI-compatible proxy
|  http://127.0.0.1:8317    |     Claude OAuth, DeepSeek, Groq, etc.
+---------------------------+
```

## Prerequisites

- ProxyPilot running on port 8317
- gopass configured with GPG/Yubikey
- Telegram API credentials from [my.telegram.org](https://my.telegram.org) (`api_id` + `api_hash`)

## Setup Steps

### 1. Create Gopass Secrets

```bash
gopass insert api/telegram-telethon-id    # Numeric API ID
gopass insert api/telegram-telethon-hash  # Hex API hash
```

`api/proxypilot-local` is already used by other tools -- no action needed.

### 2. Deploy via Salt

```bash
just apply telethon_bridge
```

This deploys the binary/script, config, and systemd unit. The service will not start
automatically -- it requires an initialized session file first.

### 3. Initialize Session

```bash
telethon-bridge-init
```

Prompts for phone number, verification code, and optional 2FA password. On success,
the session is saved to `~/.telethon-bridge/telethon.session`.

This step is interactive and only needs to be done once (or after session invalidation).

### 4. Start Service

```bash
systemctl --user start telethon-bridge
systemctl --user status telethon-bridge
```

The unit has `ConditionPathExists=%h/.telethon-bridge/telethon.session` -- it will
refuse to start without a valid session file.

## Configuration Reference

| Section | Description |
|---|---|
| `telegram` | API credentials, session path, connection settings |
| `ai` | ProxyPilot endpoint, model selection, system prompt |
| `profiles` | Named prompt/model presets (e.g. `default`, `concise`) |
| `allowlist` | Telegram user/chat IDs permitted to interact |
| `channels` | Per-channel behavior overrides |
| `groups` | Group chat settings (enable/disable, mention trigger) |
| `automation` | Auto-reply rules, scheduled messages |
| `service` | Health endpoint bind address, logging level |

## Health Check

```bash
curl -s http://127.0.0.1:8319/health | jq
```

Returns JSON with connection status, uptime, and active session info.

## Owner Commands

Commands sent as Telegram messages in any monitored chat:

| Command | Description |
|---|---|
| `/clear` | Clear conversation history for the current chat |
| `/export <chat_id> [limit]` | Export chat history to JSON file |

## Service Management

```bash
systemctl --user status telethon-bridge      # status
systemctl --user restart telethon-bridge     # restart
systemctl --user stop telethon-bridge        # stop
journalctl --user -u telethon-bridge -f      # live logs
```

## Troubleshooting

**Session invalidated**: Telegram may revoke sessions after password changes or
prolonged inactivity. Re-run `telethon-bridge-init` to create a new session, then
restart the service.

**FloodWait errors**: Telegram rate-limits API calls. The service auto-sleeps for the
required duration. Check logs for `FloodWaitError` and the wait period:
```bash
journalctl --user -u telethon-bridge -f
```

**ProxyPilot down**: Messages receive an error reply, but the service stays connected
to Telegram and recovers automatically when ProxyPilot returns.

**Service won't start**: Verify the session file exists:
```bash
ls -la ~/.telethon-bridge/telethon.session
```
If missing, run `telethon-bridge-init`. If the file exists but the service still
fails, check logs for authentication errors.

**Check logs**:
```bash
journalctl --user -u telethon-bridge -f
journalctl --user -u telethon-bridge --since "10 min ago"
```
