# Future Expansion: OpenClaw Remote Access

## Tailscale for Remote Web UI Access

Currently OpenClaw is accessible only via:
- **Localhost** (127.0.0.1:18789) — Web UI on the workstation itself
- **Telegram bot** — remote AI interaction via allowlisted chat

When remote Web UI access becomes needed, **Tailscale** is the recommended path:

### Why Tailscale
- Mesh VPN — no VPS, no exposed ports, no port forwarding
- Free for personal use (up to 100 devices)
- WireGuard under the hood — fast, modern crypto
- Works behind NAT/CGNAT without router config
- MagicDNS gives stable hostnames (e.g., `workstation.tail12345.ts.net`)

### Implementation Plan
1. Install Tailscale on workstation: `paru -S tailscale` + `systemctl enable --now tailscaled`
2. Install Tailscale on remote devices (phone, laptop)
3. Bind OpenClaw gateway to Tailscale interface (change `gateway.mode` or add reverse proxy)
4. Access Web UI at `http://workstation:18789/` from any Tailscale-connected device
5. Optional: Tailscale ACLs for guest access (maps to dual-agent config already in `openclaw.json.j2`)

### Salt Integration
- New state: `states/tailscale.sls` — install, enable, configure
- Feature gate: `host.features.tailscale | default(false)`
- OpenClaw config: update `gateway.host` from `127.0.0.1` to `0.0.0.0` (safe behind Tailscale)
- Guest access: Tailscale node sharing + dual-agent routing

### Dual-Agent Config (Already Prepared)
`states/configs/openclaw.json.j2` already contains `agents.list` with:
- `main` (owner) — full tool access
- `guest` — restricted (`tools.deny: ["exec","browser","gateway","cron"]`)

This will be useful when Tailscale enables remote Web UI access with guest sharing.
