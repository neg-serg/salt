# Remaining NixOS → Salt Migration Items

What's left in `docs/nixos-config-ref/modules/` after removing all migrated configs.
Each file remaining in the submodule = unmigrated item.

---

## Services (modules/servers/)

### AdGuardHome — `servers/adguardhome/default.nix`
**Priority: High** — DNS filtering + ad blocking for the whole LAN.
- Runs on port 3000 (admin UI), DNS on 127.0.0.1:53
- Upstream: Unbound on 127.0.0.1:5353
- Immutable settings (config-as-code)
- Integrates with systemd-resolved (stub resolver)
- Filter lists + DNS rewrites
- **Salt approach**: Install from Fedora repos or static binary, manage config via file.managed + service.running

### Unbound — `servers/unbound/default.nix`
**Priority: High** — Recursive DNS resolver, upstream for AdGuardHome.
- Listens on 127.0.0.1:5353
- DNSSEC enabled, prefetch, qname-minimisation
- DoT forwarding to Cloudflare (1.1.1.1:853) and Quad9 (9.9.9.9:853)
- Remote control on 127.0.0.1:8953 (for Prometheus exporter)
- **Salt approach**: `dnf install unbound`, manage `/etc/unbound/unbound.conf`

### Avahi — `servers/avahi/default.nix`
**Priority: Medium** — mDNS/Bonjour local service discovery.
- nssmdns4/6 enabled, publish workstation + user services
- Open firewall
- **Salt approach**: `dnf install avahi nss-mdns`, enable service

### Samba — `servers/samba/default.nix`
**Priority: Low** — SMB file sharing.
- Share: `/zero/sync/smb` (guest-ok, read-write)
- Workgroup: WORKGROUP
- Not started at boot (manual)
- Firewall: 137-139, 445
- **Salt approach**: `dnf install samba`, manage `/etc/samba/smb.conf`

### Jellyfin — `servers/jellyfin/default.nix`
**Priority: Low** — Media server.
- Minimal config, firewall closed by default
- **Salt approach**: Install from Jellyfin repo or Flatpak

### Bitcoind — `servers/bitcoind/default.nix`
**Priority: Low** — Bitcoin Core node.
- Configurable dataDir, p2pPort
- Log rotation: weekly, 8 rotations, 50MB
- **Salt approach**: Static binary + systemd unit + logrotate config

### DuckDNS — `servers/duckdns/default.nix`
**Priority: Low** — Dynamic DNS (currently disabled in NixOS config).
- Requires domain + DUCKDNS_TOKEN env file
- **Salt approach**: Simple cron/timer script calling DuckDNS API

### Netdata (server) — `servers/netdata/default.nix`
**Priority: Low** — Netdata via Podman container (alternative to package install).
- Host network mode, SYS_PTRACE + SYS_ADMIN caps
- Auto-start: false
- Already installed as package in system_description.sls; this is the containerized variant

---

## Monitoring Stack (modules/monitoring/)

### Grafana — `monitoring/grafana/default.nix`
**Priority: Medium** — Dashboard with Loki datasource.
- Port 3030 (avoids AdGuardHome 3000)
- Auto-provisioned Loki datasource on 127.0.0.1:3100
- Optional Caddy HTTPS reverse proxy
- Admin password via SOPS
- **Salt approach**: Install from Grafana repo, manage provisioning YAML, systemd unit

### Loki — `monitoring/loki/default.nix`
**Priority: Medium** — Log aggregation.
- Port 3100, localhost only
- Filesystem storage: /var/lib/loki/{chunks,rules}
- 30-day retention, boltdb-shipper schema v13
- **Salt approach**: Static binary from GitHub releases, systemd unit, config YAML

### Promtail — `monitoring/promtail/default.nix`
**Priority: Medium** — Log shipper for Loki.
- Port 9080
- Scrapes: systemd journal (/var/log/journal, max_age=12h) + /var/log/*.log
- Relabels: unit, priority, host from journal metadata
- **Salt approach**: Static binary, systemd unit, config YAML

### Sysstat — `monitoring/sysstat/default.nix`
**Priority: Low** — Already installed as package; this enables the service.
- **Salt approach**: `systemctl enable --now sysstat`

### Vnstat — `monitoring/vnstat/default.nix`
**Priority: Low** — Network traffic statistics.
- **Salt approach**: `systemctl enable --now vnstat`

### Netdata (config) — `monitoring/netdata/default.nix`
**Priority: Low** — Hardened Netdata with resource limits.
- Nice=19, MemoryMax=256M, CPUWeight=10
- Localhost only (127.0.0.1:19999)
- **Salt approach**: systemd override for netdata.service

---

## Hardware (modules/hardware/)

### Fan Control — `hardware/cooling.nix`
**Priority: High** — Motherboard + GPU fan curve management.
- Loads nct6775 Super I/O driver (ASUS motherboards)
- Auto-generates /etc/fancontrol from detected hwmon devices
- CPU fans: 35–75°C ramp, min PWM 70, hysteresis 3°C, 2s interval
- GPU fans: 50–85°C ramp, separate PWM channels
- Reapplies PWM ownership after suspend (system-sleep hook)
- **Salt approach**: Install lm_sensors, create systemd units for fancontrol-setup + fancontrol, sleep hook script

### QMK Keyboard — `hardware/qmk/default.nix`
**Priority: Medium** — USB udev rules for QMK keyboard flashing.
- Comprehensive rules for: Atmel DFU, STM32duino, BootloadHID, Caterina (Pro Micro), HalfKay, APM32, GD32V, WB32, AT32, hidraw
- Creates `plugdev` group, adds user
- Excludes ModemManager for bootloader devices
- **Salt approach**: Install qmk-udev-rules package or deploy rules file to /etc/udev/rules.d/

### Audio DSP — `hardware/audio/dsp/default.nix`
**Priority: Low** — Pro audio DSP plugins.
- Packages: brutefir, camilladsp, jamesdsp, lsp-plugins, yabridge, yabridgectl
- camilladsp already has installer in system_description.sls
- **Salt approach**: Some available via COPR (yabridge), others need RPM specs or Flatpak

### Udev Rules — `hardware/udev-rules/default.nix`
**Priority: Medium** — I/O scheduler + device-specific rules.
- NVMe → scheduler "none", SSD → "mq-deadline", HDD → "bfq"
- Audio group access to cpu_dma_latency (mode 0660)
- Vendor HID rules (RME audio interfaces: 3434:0b10, 3554:f54b, etc.)
- SATA ALPM → max_performance
- **Salt approach**: Deploy rules file to /etc/udev/rules.d/99-custom.rules

---

## Networking & VPN (modules/system/net/)

### VM Bridge — `system/net/bridge.nix`
**Priority: Medium** — Virtual bridge (br0) for KVM/libvirt VMs.
- Bridge: br0, address 192.168.122.1/24
- DHCP server: pool 192.168.122.50–150, lease 12h
- DNS/router: 192.168.122.1
- Firewall: UDP 67-68 on br0
- **Salt approach**: NetworkManager bridge profile or libvirt default network

### Xray/VLESS Proxy — `system/net/vpn/xray.nix`, `system/net/proxy.nix`
**Priority: Medium** — Proxy infrastructure.
- xray package (VLESS/Reality-capable)
- xhost for nekoray UI
- throne GUI (already installed in system_description.sls)
- **Salt approach**: xray binary already available; config files via gopass for secrets

### Sing-box TUN — `system/net/proxy.nix`
**Priority: Low** — Advanced proxy with TUN interface (currently disabled).
- Creates sb0 virtual interface
- IP routing rules (pref 100, 200)
- DNS via resolvectl to 1.1.1.1
- Capabilities: CAP_NET_ADMIN, CAP_NET_RAW, CAP_NET_BIND_SERVICE
- **Salt approach**: Static binary + systemd unit + ip rule setup

### VPN Packages — `system/net/vpn/pkgs.nix`
**Priority: Low** — Amnezia VPN, WireGuard tools, OpenVPN.
- amnezia-vpn already built in amnezia.sls
- wireguard-tools: `dnf install wireguard-tools`
- openvpn with PKCS#11: `dnf install openvpn`

---

## Development (modules/dev/)

### Android — `dev/android/default.nix`
**Priority: Low** — Android dev environment.
- Creates adbusers group, adds user
- Packages in devShells (not system-wide)
- **Salt approach**: `dnf install android-tools`, group setup

### Ansible — `dev/ansible.nix`
**Priority: Low** — Already installed in system_description.sls.
- This adds config files: ~/.config/ansible/ansible.cfg, hosts
- Settings: forks=20, strategy=free, SSH pipelining, fact caching
- **Salt approach**: Deploy config via chezmoi dotfiles

### Antigravity — `dev/antigravity.nix`
**Priority: Low** — Google agentic IDE (conditional feature).
- **Salt approach**: GitHub binary download if needed

### Benchmarks — `dev/benchmarks/default.nix`
**Priority: Low** — HTTP benchmarking tools.
- memtester (already in system_description.sls), rewrk, wrk2
- **Salt approach**: rewrk/wrk2 via cargo install or RPM spec

### OpenCode — `dev/opencode.nix`
**Priority: Low** — AI coding terminal agent.
- Already has installer in system_description.sls (install_opencode)
- This adds a desktop entry
- **Salt approach**: Desktop entry via chezmoi dotfile

### OpenXR/VR — `dev/openxr/default.nix`
**Priority: Low** — Monado OpenXR runtime for VR dev.
- Packages: envision, monado, basalt-monado, motoc
- Env: STEAMVR_LH_ENABLE=true
- **Salt approach**: COPR or build from source if VR dev needed

### Unreal Engine — `dev/unreal/default.nix`
**Priority: Low** — UE5 build environment (heavy).
- LLVM 20, mono, dotnet-sdk_8, cmake, ninja, protobuf, grpc
- **Salt approach**: devShell or toolbox container, not system-wide

---

## LLM / AI (modules/llm/)

### Codex Config — `llm/codex-config.nix`
**Priority: Low** — System-wide /etc/xdg/codex/config.yaml.
- Catppuccin Mocha color theme, vim mode, architect mode
- Models: deepseek-reasoner + deepseek-chat
- **Salt approach**: chezmoi dotfile for ~/.config/codex/ or file.managed

### Open WebUI — `llm/open-webui.nix`
**Priority: Low** — Web interface for Ollama (currently disabled).
- Port 11111, open firewall
- **Salt approach**: Podman container or pip install

### LLM Packages — `llm/pkgs.nix`
**Priority: Low** — voxinput (voice-to-text via dotool/uinput).
- Most LLM tools moved to devShells
- **Salt approach**: Cargo install or GitHub binary

---

## ~~Flatpak Apps~~ — MIGRATED

All Flatpak apps (OBS, Live Captions, Obsidian, Chromium, GIMP, Chrome, LibreOffice, Lutris)
and global Wayland overrides (XCURSOR_PATH, GTK_THEME) migrated to `states/system_description.sls`.

---

## Virtualization (modules/system/)

### KVM/Libvirt — `system/virt/default.nix`, `system/virt.nix`
**Priority: Low** — Currently empty in NixOS config (migrated or removed upstream).
- KVM/libvirt basics already in system_description.sls (qemu-kvm, virt-manager)
- **Status**: Likely already covered; can delete these files

---

## Misc (modules/)

### Roles — `roles/*.nix`
**Priority: Low** — Architectural reference for role-based config.
- Defines which services/features to enable per role (workstation, homelab, media, monitoring, server)
- Salt uses host_config.jinja instead; roles are informational
- **Status**: Reference only, no direct migration needed

### Hiddify VPN — `tools/hiddify.nix`
**Priority: Low** — VPN client AppImage (v2.0.5).
- Wraps AppImage with GTK/X11 deps
- **Salt approach**: Download AppImage + desktop entry, or skip (throne covers proxy needs)
