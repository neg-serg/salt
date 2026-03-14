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

## Systemd Hardening

The `openclaw-gateway.service` unit is hardened with security directives that reduce the attack surface. Security score: **2.9 OK** (down from 8.2 EXPOSED).

Key directives:
- `CapabilityBoundingSet=` — drops all Linux capabilities
- `SystemCallFilter=@system-service` — restricts to standard service syscalls
- `ProtectSystem=strict` — read-only filesystem (except `WorkingDirectory`)
- `ProtectKernel{Tunables,Modules,Logs}=yes` — blocks kernel modification
- `NoNewPrivileges=true`, `RestrictSUIDSGID=yes` — prevents privilege escalation
- `PrivateTmp=yes`, `KeyringMode=private` — isolates temp files and keyrings
- `MemoryMax=2G` — prevents runaway memory usage (OOM-killed if exceeded)
- `StartLimitBurst=5` / `StartLimitIntervalSec=300` — prevents restart storms

**Not enabled** (V8/Node.js constraints):
- `MemoryDenyWriteExecute=yes` — V8 JIT requires W+X pages
- `PrivateDevices=yes` — mpv needs `/dev/dri` for GPU video output

Verify security score:
```bash
systemd-analyze --user security openclaw-gateway.service
```

## Health Checks

OpenClaw exposes a structured health probe via CLI:
```bash
openclaw gateway health --json --timeout 5000
```

Returns JSON with `.ok` (overall health), `.channels.telegram.probe.ok` (Telegram connection), session count, and agent status.

**salt-monitor integration**: The monitoring daemon (`salt-monitor`) polls this command every 15 seconds using `health_cmd` + `health_parse` (jq expression). If unhealthy for 2 consecutive checks, it auto-restarts the service (up to 3 times per 5-minute window). If restarts are exhausted, alerts escalate to critical severity.

Check health manually:
```bash
openclaw gateway health --json | jq '{ok, channels: .channels.telegram.probe.ok}'
openclaw gateway status --json   # detailed status with sessions
```

## Abuse Protection

OpenClaw runs with a dual-agent setup:

| Agent | Access Level |
|---|---|
| **Main (Owner)** | Full tool access (`profile: "full"`) |
| **Guest** | Minimal — denied: `exec`, `browser`, `gateway`, `cron`, `write`, `edit`; filesystem restricted to workspace only |

Additional controls:
- **DM policy**: `allowlist` — only whitelisted Telegram user IDs can interact
- **Group policy**: `disabled` — bot ignores group chats entirely
- **Session isolation**: `per-channel-peer` — each sender gets their own session
- **Concurrency**: `maxConcurrent: 4` (OpenClaw default) limits simultaneous agent turns
- **Agent binding**: Guest users are bound by Telegram peer ID — cannot escalate to Main agent

## Troubleshooting

**Version mismatch warnings**: Ensure no system-wide openclaw exists (`which -a openclaw` should show only `~/.local/bin/openclaw`).

**Auth errors in Web UI**: Restart the gateway to clear rate limits, then reload the page with `?token=...` parameter.

**Telegram not connecting**: Check `gopass show -o api/openclaw-telegram` returns a valid bot token. Verify with `openclaw status --deep`.

**ProxyPilot not reachable**: Ensure `systemctl --user is-active proxypilot` returns `active`. The gateway unit has `Wants=proxypilot.service`. When ProxyPilot is down, the bot returns an error to users within ~15 seconds.

**MemoryMax OOM**: If the service is killed with `oom-kill`, check `journalctl --user -u openclaw-gateway | grep -i oom`. The 2G limit covers normal operation; persistent OOMs may indicate a leak — report upstream.

**StartLimitBurst exhausted**: If the service won't start (`start-limit-hit`), wait 5 minutes or reset: `systemctl --user reset-failed openclaw-gateway.service`.

**Config corruption**: The `ExecStartPre` sanitizer validates JSON syntax before startup. If config is corrupt (invalid JSON), the service won't start and logs show `openclaw-sanitize: invalid JSON in config`. Fix the JSON or re-seed: `rm ~/.openclaw/openclaw.json && just apply openclaw_agent`.
