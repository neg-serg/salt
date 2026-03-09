# Research: OpenClaw Secure Access & Capability Expansion

**Feature Branch**: `006-openclaw-secure-access`
**Date**: 2026-03-09

## R1: Secure Tunnel Technology

### Decision: Rathole (tunnel) + Caddy (TLS + auth) on a VPS

### Rationale

The user's core requirement is privacy ("not sticking out naked on the internet") combined with browser-only access for invited users. This eliminates:

- **Cloudflare Tunnel**: Excellent auth (Zero Trust), but Cloudflare terminates TLS and sees all plaintext traffic — unacceptable for an AI chat gateway carrying sensitive conversations. The user explicitly values privacy.
- **Tailscale Funnel**: No tunnel-level auth for public visitors. Token ends up in URL (browser history, referrer headers). Traffic routes through Tailscale relays.
- **SSH Reverse Tunnel**: Fragile, silent failures. By the time you add TLS + auth + auto-recovery, you've rebuilt the VPS approach with worse tooling.

**Rathole** is a Rust-based, purpose-built tunneling tool (~2MB binary). It handles NAT traversal via outbound connection from workstation to VPS, with token-authenticated tunnel and automatic reconnection. Simpler than WireGuard for this use case (no IP allocation, routing tables, or kernel modules on VPS).

**Caddy** replaces both nginx and certbot with a single binary that auto-provisions Let's Encrypt TLS certificates. Handles HTTP Basic Auth or OAuth via plugins. Zero-config certificate renewal.

### Architecture

```
[Browser] ──HTTPS──▶ [VPS: Caddy (TLS + auth)] ──rathole tunnel──▶ [Workstation: OpenClaw :18789]
                        ▲                              ▲
                  DuckDNS domain              Outbound connection
                  Let's Encrypt cert          (NAT-piercing)
```

### Alternatives Considered

| Option | Why Rejected |
|---|---|
| Cloudflare Tunnel + Zero Trust | Privacy: Cloudflare sees all plaintext. Best auth, zero cost, but contradicts privacy requirement |
| Tailscale Funnel | No tunnel-level auth for public visitors. Token in URL. Traffic through third-party relays |
| WireGuard + nginx | Same result as Rathole+Caddy but more moving parts (WireGuard kernel module, separate certbot, nginx config) |
| frp (fast reverse proxy) | Similar to Rathole but weaker visitor auth. Would need Caddy/nginx anyway |
| SSH Reverse Tunnel | Fragile, silent failures, no built-in TLS or auth |
| Direct port forward + Caddy | Exposes home network port to internet. User wants zero exposed ports at home |

### Arch Linux Packages

- `rathole` — AUR (`paru -S rathole`)
- `caddy` — official `extra` repo (VPS side, not managed by Salt)

### VPS Requirement

Requires a minimal VPS ($2-4/month). The user likely already has VPS infrastructure (Xray/Sing-box configs in `network.sls` reference remote VLESS servers). If no VPS exists, Oracle Cloud free tier or Hetzner CAX11 are viable options.

### Fallback Option

If VPS is unacceptable, **Cloudflare Tunnel** is the documented fallback — zero cost, 15-minute setup, best-in-class auth, but with the privacy trade-off explicitly accepted.

---

## R2: OpenClaw Skill System

### Decision: Deploy skills as SKILL.md files to `~/.openclaw/skills/` via Salt `file.managed`

### Rationale

OpenClaw skills are the primary extension mechanism. They work via system prompt injection — the SKILL.md markdown body is injected into the agent's system prompt, teaching it how to use built-in tools (`exec`, `read`, `write`, etc.). Skills cannot define new tools or use native MCP protocol.

### Key Constraints

- **No native MCP**: `mcpServers` config key is silently ignored. Skills wrap shell commands via `exec`/`bash`.
- **No per-user skills**: Skills apply per-agent, not per-user. All users on the same agent see the same skills.
- **`allowed-tools` is advisory**: Declared tools hint at what the skill needs but don't override deny lists.
- **Single-line metadata**: The YAML frontmatter parser requires `metadata` to be a single-line JSON object.

### Skill Format

```markdown
---
name: skill-name
description: Brief description
user-invocable: true
allowed-tools: Bash(hyprctl:*), Read
metadata: {"openclaw":{"emoji":"🖥️","os":["linux"],"requires":{"bins":["hyprctl"]}}}
---

# Skill Instructions

[Markdown body injected into system prompt]
```

### Deployment Strategy

Skills deployed via Salt to `~/.openclaw/skills/<name>/SKILL.md`:
- Salt manages the file content (idempotent via `file.managed`)
- No `replace: False` needed (skills don't self-modify unlike `openclaw.json`)
- OpenClaw discovers skills on next session start or via watcher hot-reload

### Three Skills to Create

1. **hyprland-desktop**: Wraps `hyprctl` for workspace/window/screenshot control
2. **file-manager**: Wraps `ls`, `find`, `cat`, `cp`, `mv` with path restriction logic
3. **email-notmuch**: Wraps `notmuch search/show` + `msmtp` for email management

---

## R3: Multi-User Authentication & Permission Model

### Decision: Dual-agent architecture (owner agent + guest agent) with tunnel-level auth

### Rationale

OpenClaw is a single-operator model — one gateway token, no per-user RBAC. To provide different capability levels for owner vs. invited users, we use two agents within one gateway:

- **Owner agent (`main`)**: Full capabilities — all skills (desktop, files, email), `tools.profile: "full"`
- **Guest agent (`guest`)**: Restricted — chat only + limited file read, `tools.profile: "minimal"`, `deny: ["exec", "browser", "gateway", "cron"]`

### User Routing

- **Owner**: Authenticated at tunnel level (Caddy basicauth with owner credentials). Connects to owner agent by default.
- **Invited users**: Each gets unique Caddy credentials. Connects to guest agent.
- **Telegram**: Already has allowlist policy (`dmPolicy: "allowlist"`, `allowFrom: ["109503498"]`). Uses owner agent.

### Session Isolation

Already configured: `session.dmScope: "per-channel-peer"`. Each user gets isolated conversation context. No user can see another's history.

### Alternatives Considered

| Option | Why Rejected |
|---|---|
| Multiple gateways | Overkill: doubles resource usage, separate ports, separate processes. One gateway with two agents is simpler |
| Soft enforcement in skills | Single agent, permission checks in skill instructions. Too fragile — agent might ignore instructions |
| Tailscale ACLs | Requires Tailscale client on all devices (violates FR-020) |

### Credential Management

- Owner credentials: gopass (`api/openclaw-tunnel-owner`)
- Guest credentials: generated per invite, stored in gopass (`api/openclaw-tunnel-guest-<name>`)
- Caddy config on VPS uses hashed passwords (bcrypt)

---

## R4: Health Monitoring & Self-Healing

### Decision: systemd watchdog + timer-based health check + Telegram notification via OpenClaw

### Rationale

The system needs three layers of health monitoring:

1. **Tunnel health**: systemd `Restart=on-failure` with `RestartSec` exponential backoff for the Rathole client service
2. **OpenClaw health**: Periodic `openclaw health --json` via systemd timer
3. **Certificate health**: Caddy handles auto-renewal natively (no monitoring needed on workstation side)
4. **Notification**: Health check script sends alerts via the OpenClaw Telegram channel when issues persist

### Health Check Script

```bash
#!/usr/bin/env zsh
# Check tunnel connectivity + OpenClaw health
# Exit 0 = healthy, Exit 1 = alert needed

# 1. Check rathole tunnel service
systemctl --user is-active openclaw-tunnel.service || alert "Tunnel down"

# 2. Check OpenClaw gateway
openclaw health --json | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('healthy') else 1)" || alert "Gateway unhealthy"

# 3. Check tunnel endpoint reachability (curl the VPS)
curl -fsS --max-time 5 "https://openclaw.DOMAIN/health" || alert "Tunnel endpoint unreachable"
```

### Systemd Timer

```ini
[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Persistent=true
```

Runs every 5 minutes. On failure, sends notification via Telegram (using `curl` to Telegram Bot API directly, not through OpenClaw agent — avoids circular dependency).

### Notification Method

Direct Telegram Bot API call (not through OpenClaw):
```bash
curl -s "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -d "chat_id=${OWNER_UID}" \
  -d "text=⚠️ OpenClaw health check failed: ${ERROR}"
```

This avoids the circular dependency of OpenClaw notifying about its own failure.

---

## R5: Email Skill via notmuch + msmtp

### Decision: Wrap existing mail pipeline (notmuch search/show + msmtp send) in an OpenClaw skill

### Rationale

The user's mail infrastructure is already deployed:
- **mbsync** syncs Gmail IMAP → local maildir at `~/.local/mail/gmail/`
- **notmuch** indexes and provides full-text search with structured JSON output
- **msmtp** sends via Gmail SMTP
- **goimapnotify** triggers sync on new mail (IMAP IDLE)

notmuch is ideal for AI agent interaction:
- `notmuch search --format=json` — structured query results
- `notmuch show --format=json` — full message content as JSON
- Powerful query DSL: `date:1week.. tag:unread from:boss subject:report`
- Tag-based organization: agent can tag messages as processed

### Email Skill Operations

| Operation | Command |
|---|---|
| Check inbox | `notmuch search tag:unread tag:inbox --format=json` |
| Search | `notmuch search "<query>" --format=json` |
| Read message | `notmuch show --format=json id:<message-id>` |
| Send (via msmtp) | Compose message → pipe to `msmtp -a gmail` |
| Sync now | `mbsync gmail` (trigger immediate sync) |
| Tag as read | `notmuch tag -unread id:<message-id>` |

### Safety: Draft-Before-Send

The skill instructions explicitly require: compose draft → present to user → wait for approval → only then pipe to msmtp. No auto-send.

---

## R6: Hyprland Desktop Skill

### Decision: Wrap `hyprctl` CLI commands (not MCP server) in an OpenClaw skill

### Rationale

The Hyprland MCP server is configured for Claude Code (`.mcp.json`) but OpenClaw cannot use MCP servers natively. Instead, the skill teaches the agent to use `hyprctl` directly via `exec`/`bash`:

- `hyprctl dispatch workspace 5` — switch workspace
- `hyprctl clients -j` — list windows as JSON
- `hyprctl dispatch closewindow address:<addr>` — close window
- `hyprctl dispatch exec <app>` — launch application
- `grim -g "$(slurp)" /tmp/screenshot.png` — take screenshot (or `grim` for full screen)

The `hyprctl -j` flag outputs JSON, which the AI agent can parse reliably.

### Screenshot Delivery

For remote screenshot viewing: the skill saves to a temp file, then the agent can describe it or (if the Web UI supports image display) embed it. The OpenClaw Web UI supports image rendering in messages.

### Environment Requirement

`hyprctl` requires `HYPRLAND_INSTANCE_SIGNATURE` environment variable. The OpenClaw gateway service must have access to the Hyprland socket. Since both run as user `neg` in the same session, this works if the service inherits the user's environment (ensured by `loginctl enable-linger`).

Potential issue: if the service starts before Hyprland, the env var won't exist. Solution: the skill checks for Hyprland availability before executing commands.
