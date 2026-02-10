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

## ~~Monitoring Stack~~ — MIGRATED

Full stack migrated to `states/monitoring.sls`:
sysstat + vnstat service enables, Netdata systemd override (Nice=19, MemoryMax=256M),
Loki (binary + config + systemd), Promtail (binary + journal/varlogs scraping),
Grafana (RPM repo + Loki datasource provisioning, port 3030).
PHP-FPM exporter skipped (not needed on workstation).

---

## ~~Hardware: Fan Control, QMK, Udev Rules~~ — MIGRATED

Fan control (fancontrol-setup + systemd services + resume hook), custom udev rules
(I/O schedulers, RME audio, SATA ALPM), and QMK keyboard rules migrated to
`states/hardware.sls` + `scripts/fancontrol-setup.sh`. QMK rules were already in
`system_description.sls` (install_qmk_udev_rules).

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
