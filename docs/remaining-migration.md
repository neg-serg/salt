# Remaining NixOS → Salt Migration Items

What's left in `docs/nixos-config-ref/modules/` after removing all migrated configs.
Each file remaining in the submodule = unmigrated item.

**7 deferred files remain** — all low-priority niche items (toolbox/devshell territory).

---

## Deferred: Development (modules/dev/)

### Antigravity — `dev/antigravity.nix`
**Priority: Low** — Google agentic IDE (conditional feature).
- NixOS-specific package wrapper
- **Status**: Deferred — niche tool, install manually if needed

### Benchmarks — `dev/benchmarks/default.nix`
**Priority: Low** — HTTP benchmarking tools.
- memtester already in system_description.sls
- rewrk, wrk2 need Rust builds (cargo install or RPM spec)
- **Status**: Deferred — add RPM specs if needed

### OpenXR/VR — `dev/openxr/default.nix`
**Priority: Low** — Monado OpenXR runtime for VR dev.
- Packages: envision, monado, basalt-monado, motoc
- **Status**: Deferred — COPR or toolbox container if VR dev needed

### Unreal Engine — `dev/unreal/default.nix`, `dev/unreal/packages.nix`
**Priority: Low** — UE5 build environment (heavy).
- LLVM 20, mono, dotnet-sdk_8, cmake, ninja, protobuf, grpc
- **Status**: Deferred — toolbox container, not system-wide

---

## Deferred: LLM / AI (modules/llm/)

### Open WebUI — `llm/open-webui.nix`
**Priority: Low** — Web interface for Ollama (disabled in NixOS too).
- Port 11111
- **Status**: Deferred — podman container if needed

### LLM Packages — `llm/pkgs.nix`
**Priority: Low** — voxinput (voice-to-text via dotool/uinput).
- Most LLM tools moved to devShells
- **Status**: Deferred — cargo install if needed

---

## Migrated States

| Salt State | What it covers |
|---|---|
| `states/system_description.sls` | All packages, Flatpak apps, binary installers, COPR repos |
| `states/hardware.sls` | Udev rules (I/O schedulers, RME audio, SATA ALPM), fancontrol |
| `states/monitoring.sls` | sysstat, vnstat, netdata, Loki, Promtail, Grafana |
| `states/dns.sls` | Unbound (DoT recursive resolver), AdGuardHome (DNS filter), Avahi (mDNS) |
| `states/services.sls` | Samba, Jellyfin, Bitcoind, DuckDNS |
| `states/network.sls` | VM bridge (br0), Xray service, Sing-box TUN service |
| `states/host_config.jinja` | Feature gates for all above services |

## Feature Gates (`host_config.jinja`)

```
features:
    monitoring:   {sysstat, vnstat, netdata, loki, promtail, grafana}
    fancontrol:   bool
    dns:          {unbound, adguardhome, avahi}
    services:     {samba, jellyfin, bitcoind, duckdns}
    network:      {vm_bridge, xray, singbox}
```

## Already Covered (removed from submodule)

- **Audio DSP** (brutefir, camilladsp, jamesdsp, lsp-plugins, yabridge) → system_description.sls
- **Android tools** → system_description.sls
- **Codex config** → chezmoi dotfile territory
- **Xray/Sing-box binaries** → system_description.sls (services in network.sls)
- **Ansible** → system_description.sls + chezmoi dotfiles
- **OpenCode** → system_description.sls
- **Hiddify** → throne covers proxy needs
- **Roles** → host_config.jinja features
- **Virtualization** → system_description.sls (qemu-kvm, virt-manager, podman)
- **VPN packages** → amnezia.sls + simple dnf
- **Netdata container** → monitoring.sls package + override
