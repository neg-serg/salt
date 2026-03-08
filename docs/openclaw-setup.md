# OpenClaw Setup Guide

## Overview

OpenClaw is a local AI agent gateway. All models are routed through ProxyPilot
(which provides access to Claude via OAuth, DeepSeek, Groq, Cerebras, etc.).
It provides a Web UI (chat dashboard) and a Telegram bot channel.

## Architecture

```
Browser / Telegram
        │
        ▼
┌─────────────────────────┐
│  openclaw-gateway       │  ← systemd user service
│  ws://127.0.0.1:18789   │     auth: token
└──────────┬──────────────┘
           │
           │
           ▼
┌─────────────────────────┐
│  ProxyPilot             │  ← OpenAI-compatible proxy
│  http://127.0.0.1:8317  │     Claude OAuth, DeepSeek, Groq, etc.
└─────────────────────────┘
```

## Components

| Component | Path / Detail |
|---|---|
| Binary | `~/.local/bin/openclaw` (npm, version-pinned in `data/versions.yaml`) |
| Config | `~/.openclaw/openclaw.json` (Jinja-seeded, self-managed by OpenClaw) |
| Service | `~/.config/systemd/user/openclaw-gateway.service` |
| Salt state | `states/openclaw_agent.sls` |
| Config template | `states/configs/openclaw.json.j2` |
| Unit file | `states/units/user/openclaw-gateway.service` |
| Listen | `127.0.0.1:18789` (loopback only) |
| Auth | Token-based (auto-generated on first start) |

## Secrets (gopass)

| Key | Purpose |
|---|---|
| `api/proxypilot-local` | API key for ProxyPilot (shared with Claude Code, OpenCode) |
| `api/openclaw-telegram` | Telegram Bot Token (`@negserg_openclaw_bot`) |
| `api/openclaw-telegram-uid` | Telegram numeric user ID for allowlist |

Create secrets before first Salt apply:
```bash
gopass insert api/openclaw-telegram   # paste Telegram Bot Token from @BotFather
```

`api/proxypilot-local` is already used by other tools — no action needed.

## Web UI Access

1. Open `http://127.0.0.1:18789/`
2. Enter the gateway auth token when prompted (one-time, stored in browser localStorage)
3. Get the token: `grep -o '"token":"[^"]*"' ~/.openclaw/openclaw.json | head -1`

Or open with token in URL (auto-authenticates):
```bash
handlr open "http://127.0.0.1:18789/?token=$(python3 -c "import json; print(json.load(open('$HOME/.openclaw/openclaw.json'))['gateway']['auth']['token'])")"
```

## CLI Commands

```bash
openclaw status              # gateway status + security audit
openclaw status --deep       # full probe (tests channels, models)
openclaw doctor              # config diagnostics
openclaw doctor --fix        # auto-fix config issues
openclaw models list         # available models
openclaw logs --follow       # live gateway logs
openclaw config get gateway  # view gateway config section
```

## Service Management

```bash
systemctl --user status openclaw-gateway     # status
systemctl --user restart openclaw-gateway    # restart
systemctl --user stop openclaw-gateway       # stop
journalctl --user -u openclaw-gateway -f     # live logs
```

## Models

| Model | Provider | Role |
|---|---|---|
| `proxypilot/claude-sonnet-4-6` | ProxyPilot (Claude OAuth) | Primary |
| `proxypilot/claude-opus-4-6` | ProxyPilot (Claude OAuth) | Fallback |

## Telegram Bot

- Bot: `@negserg_openclaw_bot`
- DM policy: `allowlist` (only whitelisted users)
- Allowed users: numeric ID from `gopass show -o api/openclaw-telegram-uid`
- Group policy: `disabled`
- Session isolation: `per-channel-peer` (each sender gets their own session)

## Config Management

OpenClaw rewrites `~/.openclaw/openclaw.json` at startup (adds metadata, defaults, reorders keys).
Salt uses `replace: False` — it only seeds the initial config on a fresh deploy.

To force re-deploy after changing the Jinja template:
```bash
rm ~/.openclaw/openclaw.json
just   # Salt will re-render the template
systemctl --user restart openclaw-gateway
```

## Troubleshooting

**Version mismatch warnings**: Ensure no system-wide openclaw exists (`which -a openclaw` should show only `~/.local/bin/openclaw`).

**Auth errors in Web UI**: Restart the gateway to clear rate limits, then reload the page with `?token=...` parameter.

**Telegram not connecting**: Check `gopass show -o api/openclaw-telegram` returns a valid bot token. Verify with `openclaw status --deep`.

**ProxyPilot not reachable**: Ensure `systemctl --user is-active proxypilot` returns `active`. The gateway unit has `Wants=proxypilot.service`.
