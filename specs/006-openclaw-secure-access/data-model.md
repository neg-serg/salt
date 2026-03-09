# Data Model: OpenClaw Secure Access & Capability Expansion

**Feature Branch**: `006-openclaw-secure-access`
**Date**: 2026-03-09

This is an infrastructure-as-code project. "Entities" are configuration objects managed by Salt and chezmoi, not database tables.

## Configuration Entities

### 1. Rathole Client Config

**File**: `states/configs/rathole-client.toml.j2` → deployed to `~/.config/rathole/client.toml`
**Format**: TOML (Jinja2 template)

| Field | Type | Source | Description |
|---|---|---|---|
| `client.remote_addr` | string | `gopass api/openclaw-tunnel-vps` | VPS address:port for tunnel connection |
| `client.default_token` | string | `gopass api/openclaw-tunnel-token` | Shared secret authenticating the tunnel |
| `client.services.openclaw.local_addr` | string | hardcoded `127.0.0.1:18789` | Local OpenClaw gateway to expose |

**Relationships**: Consumed by `openclaw-tunnel.service`. Must match server-side Rathole config on VPS.

### 2. OpenClaw Gateway Config (modified)

**File**: `states/configs/openclaw.json.j2` → deployed to `~/.openclaw/openclaw.json`
**Format**: JSON (Jinja2 template, `replace: False`)

**New/Modified Fields**:

| Field | Type | Default | Description |
|---|---|---|---|
| `agents.list[0]` | object | — | Owner agent (`id: "main"`) with full tool profile |
| `agents.list[1]` | object | — | Guest agent (`id: "guest"`) with minimal tool profile |
| `agents.list[1].tools.profile` | string | `"minimal"` | Restricted tool access for guests |
| `agents.list[1].tools.deny` | array | `["exec","browser","gateway","cron"]` | Blocked tools for guest agent |

**State transitions**: Config is seeded once (`replace: False`). To apply multi-agent changes, the existing migration pattern is used: a migration state deletes old config when it lacks the new structure, allowing re-seed.

### 3. OpenClaw Skill (generic structure)

**Files**: `dotfiles/dot_openclaw/skills/<name>/SKILL.md`
**Format**: Markdown with YAML frontmatter

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Skill identifier |
| `description` | string | yes | Brief explanation |
| `user-invocable` | boolean | no | Expose as `/slash-command` (default: true) |
| `allowed-tools` | string | no | Comma-separated tool declarations |
| `metadata` | JSON string | no | Gating: required binaries, OS, env vars |

**Three instances**:

| Skill | `name` | Key `requires.bins` | Restricted to |
|---|---|---|---|
| Hyprland Desktop | `hyprland-desktop` | `hyprctl`, `grim` | Owner only (via agent routing) |
| File Manager | `file-manager` | `ls`, `find`, `cat` | Owner: all paths; Guest: shared paths |
| Email (notmuch) | `email-notmuch` | `notmuch`, `msmtp`, `mbsync` | Owner only (via agent routing) |

### 4. Systemd Service Units

#### openclaw-tunnel.service

| Field | Value | Description |
|---|---|---|
| Type | `simple` | Long-running daemon |
| ExecStart | `rathole --client %h/.config/rathole/client.toml` | Rathole client mode |
| Restart | `on-failure` | Auto-restart on crash |
| RestartSec | `5` | Initial restart delay |
| StartLimitIntervalSec / StartLimitBurst | `300` / `5` | Exponential backoff: max 5 restarts per 5 min |
| After/Wants | `network-online.target` | Wait for network |

#### openclaw-health.timer

| Field | Value | Description |
|---|---|---|
| OnBootSec | `5min` | First check 5 minutes after boot |
| OnUnitActiveSec | `5min` | Check every 5 minutes |
| Persistent | `true` | Run immediately if missed while off |

#### openclaw-health.service

| Field | Value | Description |
|---|---|---|
| Type | `oneshot` | Runs and exits |
| ExecStart | `%h/.local/bin/openclaw-health-check` | Health check script |

### 5. Health Check Script

**File**: `states/scripts/openclaw-health-check.sh` → deployed to `~/.local/bin/openclaw-health-check`
**Format**: Zsh script

| Check | Command | Failure Action |
|---|---|---|
| Tunnel service active | `systemctl --user is-active openclaw-tunnel` | Alert: "Tunnel down" |
| OpenClaw gateway health | `openclaw health --json` | Alert: "Gateway unhealthy" |
| Tunnel endpoint reachable | `curl -fsS --max-time 5 https://DOMAIN/health` | Alert: "Endpoint unreachable" |

**Alert method**: Direct Telegram Bot API call (`curl` to `api.telegram.org/bot${TOKEN}/sendMessage`). Avoids circular dependency of OpenClaw notifying about its own failure.

**Cooldown**: Alerts are rate-limited — same alert not repeated within 30 minutes (state file at `~/.cache/openclaw-health-state`).

### 6. Guest Credentials

**Storage**: gopass, keyed by guest name

| gopass key | Content | Created by |
|---|---|---|
| `api/openclaw-tunnel-owner` | Caddy basicauth password (owner) | Manual, one-time |
| `api/openclaw-tunnel-guest-<name>` | Caddy basicauth password (per guest) | `openclaw-invite.sh` helper |

**Lifecycle**: Created by invite script → stored in gopass → hashed for Caddy config → revoked by deleting gopass entry and reloading Caddy.

### 7. Versions Data

**File**: `states/data/versions.yaml` (modified)

| Key | Value | Description |
|---|---|---|
| `rathole` | `0.5.x` (pin to latest stable) | Rathole tunnel client version |

## Entity Relationships

```
┌─────────────────┐     ┌──────────────────────┐
│ Rathole Config  │────▶│ openclaw-tunnel.svc  │
│ (client.toml)   │     │ (systemd user svc)   │
└─────────────────┘     └──────────┬───────────┘
                                   │
┌─────────────────┐     ┌──────────▼───────────┐     ┌─────────────┐
│ OpenClaw Config │────▶│ openclaw-gateway.svc │◀────│ Skills      │
│ (openclaw.json) │     │ (existing, modified) │     │ (SKILL.md)  │
│ - owner agent   │     └──────────┬───────────┘     │ - hyprland  │
│ - guest agent   │                │                  │ - files     │
└─────────────────┘     ┌──────────▼───────────┐     │ - email     │
                        │ openclaw-health.tmr  │     └─────────────┘
                        │ (systemd timer)      │
                        └──────────┬───────────┘
                                   │
                        ┌──────────▼───────────┐
                        │ health-check script  │──▶ Telegram API
                        │ (zsh, direct curl)   │
                        └──────────────────────┘
```
