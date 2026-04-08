# Xray VPN — CLI Usage

## Overview

Xray is used as a CLI VPN client with VLESS + Reality + XHTTP protocol stack. The configuration was extracted from AmneziaVPN and can be used independently via the `xray` binary bundled with `v2rayn-bin`.

## Architecture

```
Application → tun2 (tun2socks) → SOCKS5 127.0.0.1:10808 → Xray → VPN server → Internet
```

Two independent components:

1. **Xray** — VLESS proxy client, exposes SOCKS5 on `127.0.0.1:10808`
2. **tun2socks** — creates a TUN interface and routes all system traffic through the SOCKS5 proxy (optional, only needed for system-wide VPN)

## Prerequisites

- `v2rayn-bin` (AUR) — provides `/opt/v2rayn-bin/bin/xray/xray`
- Symlink: `~/.local/bin/xray` → `/opt/v2rayn-bin/bin/xray/xray`

## Configuration

Config file: `~/.config/xray/config.json`

Protocol stack:

| Layer | Value |
|-------|-------|
| Protocol | VLESS |
| Transport | XHTTP |
| Security | Reality (TLS fingerprint: random) |
| SNI | `www.google.com` |
| Server | `204.152.223.171:8443` |
| Local SOCKS5 | `127.0.0.1:10808` |

## Usage

### Mode 1: SOCKS5 Proxy Only (recommended)

Start Xray as a local SOCKS5 proxy without touching system routing:

```bash
xray run -c ~/.config/xray/config.json
```

Use from applications:

```bash
# curl
curl -x socks5h://127.0.0.1:10808 https://ifconfig.me

# Environment variable (works with many CLI tools)
export ALL_PROXY=socks5h://127.0.0.1:10808

# Browser — set SOCKS5 proxy to 127.0.0.1:10808 in network settings
```

### Mode 2: System-wide VPN (via tun2socks)

Route all system traffic through the VPN, same as AmneziaVPN does:

```bash
# 1. Start xray
xray run -c ~/.config/xray/config.json &

# 2. Create TUN interface
sudo ip tuntap add mode tun dev tun2
sudo ip addr add 10.33.0.2/24 dev tun2
sudo ip link set tun2 up

# 3. Add route to VPN server via real gateway (prevent routing loop)
sudo ip route add 204.152.223.171/32 via 192.168.2.1 dev eno1

# 4. Set default route through TUN
sudo ip route add default via 10.33.0.1 dev tun2 metric 50

# 5. Start tun2socks
/opt/AmneziaVPN/client/bin/tun2socks -device tun://tun2 -proxy socks5://127.0.0.1:10808
```

To tear down:

```bash
sudo ip route del default via 10.33.0.1 dev tun2
sudo ip route del 204.152.223.171/32 via 192.168.2.1
sudo ip link del tun2
# Kill xray and tun2socks processes
```

### Mode 3: Per-application proxying (proxychains)

```bash
proxychains -q firefox
```

Requires `proxychains-ng` with SOCKS5 `127.0.0.1 10808` in `/etc/proxychains.conf`.

## Diagnostics

```bash
# Check if xray is running
pgrep -a xray

# Check SOCKS5 port
ss -tlnp | grep 10808

# Check external IP through proxy
curl -x socks5h://127.0.0.1:10808 https://ifconfig.me

# Check external IP direct
curl https://ifconfig.me

# Check current default route
ip route show default
```

## Relation to AmneziaVPN

AmneziaVPN stores the same Xray config embedded in `~/.config/AmneziaVPN.ORG/AmneziaVPN.conf` (Qt settings format, JSON inside `@ByteArray`). The standalone config at `~/.config/xray/config.json` is a clean extraction of that embedded config.

If the AmneziaVPN config changes (new server, new keys), re-extract the `last_config` JSON from `AmneziaVPN.conf` and update `~/.config/xray/config.json`.

## Notes

- Reality protocol makes the connection look like regular HTTPS traffic to `www.google.com` — effective against DPI-based blocking.
- SOCKS5 proxy mode does not affect system DNS. Use `socks5h://` (with `h`) to resolve DNS through the proxy.
- The VPN server description in AmneziaVPN is "LA-VPN-lev-ra" (Los Angeles).
