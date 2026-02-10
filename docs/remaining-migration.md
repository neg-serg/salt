# NixOS → Salt Migration — Complete

Migration from `nixos-config` (~393 .nix files) to Salt states is **100% complete**.
The `docs/nixos-config-ref/` submodule `modules/` directory is empty.

---

## Salt States

| Salt State | What it covers |
|---|---|
| `states/system_description.sls` | All packages, Flatpak apps, binary installers, COPR repos |
| `states/hardware.sls` | Udev rules (I/O schedulers, RME audio, SATA ALPM), fancontrol |
| `states/monitoring.sls` | sysstat, vnstat, netdata, Loki, Promtail, Grafana |
| `states/dns.sls` | Unbound (DoT recursive resolver), AdGuardHome (DNS filter), Avahi (mDNS) |
| `states/services.sls` | Samba, Jellyfin, Bitcoind, DuckDNS |
| `states/network.sls` | VM bridge (br0), Xray service, Sing-box TUN service |
| `states/sysctl.sls` | Kernel tuning, gaming performance |
| `states/boot.sls` | Kernel args, modules, plymouth |
| `states/mpd.sls` | MPD + ncmpcpp |
| `states/amnezia.sls` | Amnezia VPN (amneziawg-go, amneziawg-tools, client) |
| `states/build_rpms.sls` | RPM build orchestration (36 packages) |
| `states/install_rpms.sls` | rpm-ostree install custom RPMs |
| `states/host_config.jinja` | Feature gates for all services |

## Feature Gates (`host_config.jinja`)

```
features:
    monitoring:   {sysstat, vnstat, netdata, loki, promtail, grafana}
    fancontrol:   bool
    dns:          {unbound, adguardhome, avahi}
    services:     {samba, jellyfin, bitcoind, duckdns}
    network:      {vm_bridge, xray, singbox}
```

## Deferred Items (not in Salt, install manually if needed)

- **Antigravity** — Google AI IDE, niche
- **rewrk / wrk2** — HTTP benchmarks, cargo install / make
- **OpenXR / Monado** — VR dev, COPR or toolbox
- **Unreal Engine** — heavy UE5 env, toolbox container
- **Open WebUI** — Ollama web UI, podman container
- **voxinput** — voice→text, cargo install
- **Groq API** — free cloud LLM (500-1000 tok/s via LPU), OpenAI-compatible endpoint `https://api.groq.com/openai/v1`, key via `gopass insert api/groq` + `GROQ_API_KEY` env
