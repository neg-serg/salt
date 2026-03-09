# Quickstart: OpenClaw Secure Access & Capability Expansion

**Feature Branch**: `006-openclaw-secure-access`

## Prerequisites

- CachyOS workstation with Salt and OpenClaw already deployed (feature 005)
- A VPS with SSH access (any provider: Hetzner, Oracle Cloud free tier, etc.)
- DuckDNS domain configured (or willingness to set one up)
- gopass accessible with Yubikey

## VPS One-Time Setup (outside Salt)

The VPS side is managed separately from Salt (Salt manages the workstation only).

### 1. Install Rathole server + Caddy on VPS

```bash
# On VPS (Debian/Ubuntu example)
apt install caddy
# Download rathole binary from GitHub releases
curl -fsSL https://github.com/rapiz1/rathole/releases/latest/download/rathole-x86_64-unknown-linux-gnu.zip -o /tmp/rathole.zip
unzip /tmp/rathole.zip -d /usr/local/bin/
```

### 2. Configure Rathole server

```toml
# /etc/rathole/server.toml
[server]
bind_addr = "0.0.0.0:2333"

[server.default_token]
token = "GENERATE_A_STRONG_TOKEN_HERE"

[server.services.openclaw]
bind_addr = "127.0.0.1:18789"
```

### 3. Configure Caddy

```
# /etc/caddy/Caddyfile
your-domain.duckdns.org {
    basicauth {
        owner $2a$14$BCRYPT_HASH_OF_OWNER_PASSWORD
        # Add guests as needed:
        # guest1 $2a$14$BCRYPT_HASH_OF_GUEST_PASSWORD
    }
    reverse_proxy 127.0.0.1:18789
}
```

### 4. Start services on VPS

```bash
systemctl enable --now rathole-server caddy
```

### 5. Point DuckDNS to VPS IP

Update DuckDNS domain to point to VPS public IP (not workstation IP).

## Workstation Setup (via Salt)

### 1. Store secrets in gopass

```bash
gopass insert api/openclaw-tunnel-token    # Same token as VPS rathole config
gopass insert api/openclaw-tunnel-vps      # VPS address, e.g., "203.0.113.1:2333"
gopass insert api/openclaw-tunnel-owner    # Your basicauth password
```

### 2. Enable feature and apply Salt

```bash
# Edit states/data/hosts.yaml to enable tunnel feature for your host
# Then apply:
just
```

### 3. Verify

```bash
# Check tunnel is up
systemctl --user status openclaw-tunnel

# Check from remote device
curl -u owner:PASSWORD https://your-domain.duckdns.org/
```

## Using Skills

After Salt apply deploys the skills, interact via OpenClaw Web UI or Telegram:

### Desktop Control

```
> switch to workspace 3
> take a screenshot
> list open windows
> launch firefox
```

### File Management

```
> list files in ~/doc
> find PDFs in ~/dw modified this week
> read the file ~/doc/notes.txt
> move ~/dw/report.pdf to ~/doc/
```

### Email

```
> check my email
> search emails from boss about project
> read the latest unread email
> draft a reply saying I'll review it tomorrow
> [agent shows draft] → approve and send
```

## Inviting a Guest

```bash
# Generate credentials and add to Caddy
~/.local/bin/openclaw-invite guest-name
# Share the URL + credentials with the guest
```

## Health Monitoring

Health checks run every 5 minutes automatically. On failure, you'll get a Telegram notification.

```bash
# Manual health check
~/.local/bin/openclaw-health-check

# Check logs
journalctl --user -u openclaw-health -n 20
```

## Revoking Access

```bash
# Remove guest from gopass
gopass rm api/openclaw-tunnel-guest-guest-name
# Regenerate Caddy config on VPS (or use the invite script with --revoke)
```
