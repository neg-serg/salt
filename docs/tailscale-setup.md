# Tailscale VPN Setup

Tailscale is a mesh VPN built on WireGuard that creates a private network (tailnet) connecting all your devices. This guide covers installation, authentication, device onboarding, and common operations.

## Prerequisites

- CachyOS workstation with Salt configured
- Tailscale account — create at [login.tailscale.com](https://login.tailscale.com) (free tier supports up to 100 devices)
- `network.tailscale: true` enabled in `states/data/hosts.yaml` for your host

## Installation

Tailscale is installed automatically via Salt:

```bash
just apply
```

This performs three actions:
1. Installs the `tailscale` package (includes both CLI and daemon)
2. Enables and starts the `tailscaled` systemd service
3. Deploys an Unbound stub zone for MagicDNS (`*.ts.net` → `100.100.100.100`)

Verify the install:

```bash
tailscale --version
systemctl is-enabled tailscaled    # → enabled
systemctl is-active tailscaled     # → active
```

## First-Time Authentication

Authentication is interactive (one-time, requires a browser):

```bash
sudo tailscale up --accept-dns=false
```

The `--accept-dns=false` flag is **critical** — it prevents Tailscale from overriding the existing DNS stack (Unbound + AdGuardHome).

The command prints a URL like:

```
To authenticate, visit:
    https://login.tailscale.com/a/xxxxxxxxxxxx
```

Open the URL in a browser, log in to your Tailscale account, and authorize the device. After authorization, the terminal shows:

```
Success.
```

Verify the connection:

```bash
tailscale status
tailscale ip -4        # shows your 100.x.y.z address
```

## DNS Configuration

### How It Works

The workstation runs a custom DNS stack:
- **AdGuardHome** (127.0.0.1:53) — ad filtering, forwards to Unbound
- **Unbound** (127.0.0.1:5353) — recursive resolver with DNSSEC + DNS-over-TLS

Tailscale's `--accept-dns=false` flag ensures it does NOT modify the system resolver. Instead, a stub zone in Unbound forwards `*.ts.net` queries to Tailscale's built-in MagicDNS resolver at `100.100.100.100`.

### Verify DNS

```bash
# Tailnet hostnames should resolve via MagicDNS
dig <your-device>.ts.net

# Non-tailnet domains should resolve via existing stack (unchanged)
dig example.com

# Check Unbound has the stub zone loaded
unbound-control list_stubs | grep ts.net
```

## Adding Devices

### Linux (Arch/CachyOS/Manjaro)

```bash
sudo pacman -S tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up
```

### Linux (Debian/Ubuntu)

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

### Linux (Fedora)

```bash
sudo dnf install tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up
```

### Android

1. Install **Tailscale** from Google Play Store
2. Open the app, tap **Sign in**
3. Authenticate with your Tailscale account
4. The device appears in your tailnet automatically

### iOS / macOS

1. Install **Tailscale** from the App Store
2. Open the app, tap **Sign in** (iOS) or click the menu bar icon (macOS)
3. Authenticate with your Tailscale account
4. On macOS: you may be prompted to approve the VPN configuration in System Settings

### Windows

1. Download the installer from [tailscale.com/download/windows](https://tailscale.com/download/windows)
2. Run the MSI installer
3. Click the Tailscale icon in the system tray, then **Log in**
4. Authenticate in the browser

### Verifying a New Device

From any device already on the tailnet:

```bash
tailscale status                    # list all devices
tailscale ping <new-device-name>    # verify connectivity
```

## Sharing with External Users

To give someone else access to your tailnet:

1. Go to [login.tailscale.com/admin/settings/sharing](https://login.tailscale.com/admin/settings/sharing)
2. Under **Share your network**, click **Generate invite link** or add users by email
3. The invited user signs up with their own Tailscale account
4. By default, shared users can see all devices — use ACLs to restrict access

### Access Control (ACLs)

ACLs are managed in the Tailscale admin console at [login.tailscale.com/admin/acls](https://login.tailscale.com/admin/acls).

Example: allow a shared user to access only SSH on your workstation:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["shared-user@example.com"],
      "dst": ["telfir:22"]
    }
  ]
}
```

## Common Operations

### SSH Over Tailscale

No port forwarding needed — just use the Tailscale hostname:

```bash
ssh user@<device-name>
# or by Tailscale IP
ssh user@100.x.y.z
```

### File Transfer

Send a file to another device:

```bash
tailscale file cp myfile.txt <device-name>:
```

Receive files on the other device:

```bash
tailscale file get ~/dw/
```

### Exit Node

To use another device as an exit node (route all internet traffic through it):

On the exit node device:

```bash
sudo tailscale set --advertise-exit-node
```

Then approve the exit node in the admin console.

On the client device:

```bash
sudo tailscale set --exit-node=<exit-node-name>
```

To stop using the exit node:

```bash
sudo tailscale set --exit-node=
```

### Subnet Routing

To expose a local network to the tailnet (e.g. home LAN):

On the router device:

```bash
sudo tailscale set --advertise-routes=192.168.1.0/24
```

Approve the route in the admin console. Other devices can then reach `192.168.1.x` hosts.

### Network Diagnostics

```bash
tailscale status           # list all connected devices
tailscale netcheck         # check NAT type, DERP relay latency
tailscale ping <device>    # direct connectivity check
tailscale debug netmap     # full network map (verbose)
```

## Interaction with xray/sing-box

Tailscale and xray/sing-box operate on separate network interfaces:
- **Tailscale**: `tailscale0` TUN interface, routes `100.64.0.0/10` (CGNAT range)
- **xray**: application-level SOCKS/HTTP proxy (no TUN conflict)
- **sing-box**: own TUN interface with split routing

If sing-box TUN is active, ensure its routing rules **exclude** `100.64.0.0/10` to avoid capturing Tailscale traffic. This is typically the default behavior, but verify in your sing-box config if connectivity issues arise.

## Key Expiry and Re-Authentication

Tailscale keys expire after **180 days** by default. When a key expires:

1. The device silently disconnects from the tailnet
2. `tailscale status` shows "Expired" or the device disappears
3. Re-authenticate:

```bash
sudo tailscale up --accept-dns=false
```

To check when your key expires:

```bash
tailscale status --json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('Self',{}).get('KeyExpiry','unknown'))"
```

**Tip**: Set a calendar reminder for 170 days after authentication.

To disable key expiry for a device (useful for always-on servers):
1. Go to [login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines)
2. Click the device menu (⋯) → **Disable key expiry**

## Troubleshooting

| Problem | Diagnosis | Solution |
|---------|-----------|----------|
| `tailscale status` shows "Stopped" | Service not running | `sudo systemctl start tailscaled` |
| Can't resolve `*.ts.net` hostnames | Unbound stub zone missing | Check `unbound-control list_stubs \| grep ts.net`; re-run `just apply` |
| Slow connection to peers | Using DERP relay (UDP blocked) | `tailscale netcheck` — check if direct connection is possible |
| Key expired | 180-day cycle | `sudo tailscale up --accept-dns=false` |
| Local DNS broken after Tailscale | Started without `--accept-dns=false` | `sudo tailscale set --accept-dns=false` then `sudo systemctl restart systemd-resolved` |
| `tailscaled` won't start | Port conflict or stale state | Check `journalctl -u tailscaled -n 50`; if stale, remove `/var/lib/tailscale/tailscaled.state` |
