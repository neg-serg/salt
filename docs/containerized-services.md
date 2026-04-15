# Containerized Services (Podman Quadlet)

All containerizable services run exclusively as Podman Quadlet containers.
There is no dual-mode, no feature toggles, and no native fallback.

## Containerized services

| Service | Image | Scope | Notes |
|---------|-------|-------|-------|
| `ollama` | `docker.io/ollama/ollama:rocm` | system | ROCm GPU passthrough; manual start |
| `llama_embed` | `ghcr.io/ggml-org/llama.cpp:server-vulkan` | system | Vulkan GPU passthrough; manual start |
| `t5_summarization` | `ghcr.io/ggml-org/llama.cpp:server-vulkan` | system | Vulkan GPU passthrough; manual start |
| `loki` | `docker.io/grafana/loki:3.x` | system | Log aggregation |
| `promtail` | `docker.io/grafana/promtail:3.x` | system | Log shipper to Loki |
| `grafana` | `docker.io/grafana/grafana-oss:11.x-oss` | system | Dashboards |
| `telethon_bridge` | `localhost/telethon-bridge` | user | Built locally; Telegram MTProto bridge |
| `opencode_serve` | `localhost/opencode-serve` | user | Built locally; OpenCode HTTP API |
| `opencode_telegram_bot` | `localhost/opencode-telegram-bot` | user | Built locally; Telegram bot |
| `telecode` | `localhost/telecode` | user | Built locally; Go binary |

Services explicitly kept native:

- Audio stack (PipeWire, WirePlumber) — D-Bus session and ALSA/JACK coupling
- VPN and tunneling (Tailscale, AmneziaVPN, Zapret2, Hiddify) — kernel caps, TUN devices, raw sockets
- DNS (Unbound, AdGuardHome) — tightly coupled to host resolver
- MPD — MPRIS2 D-Bus integration
- NanoClaw — already runs rootless Podman as its core function
- Bitcoin Core, Jellyfin, Transmission — operational concerns outweigh containerization benefit

## Data layout

- `states/data/service_catalog.yaml` — single source of truth for every service's port, health endpoint, scope, package set, and (for containerized services) bind mounts and GPU requirements.
- `states/data/container_images.yaml` — digest registry. Remote images (docker.io, ghcr.io) MUST have a non-null `digest`. Localhost images (built manually via `podman build`) have `digest: null`.
- `states/_macros_service.jinja` — `container_service()` macro. Skips `podman pull` for `localhost` registry images.

## Digest bump workflow

Upgrading a containerized service to a newer upstream image is a single two-line commit to `states/data/container_images.yaml`:

1. `podman pull <registry>/<image>:<variant>` (pull the new tag).
2. `podman image inspect --format '{{.Id}}'` to capture the sha256.
3. Update `digest` and `approved_at` for the service entry.
4. Commit with message `[<service>] bump container digest to <first 12 chars>`.
5. `sudo salt-call --local state.apply <service>` — the macro's `podman image exists` guard skips the pull if the digest is already local, then restarts the service via the `watch:` chain.

Rolling back to the previous digest: `git revert` the bump commit, then apply.

## Building localhost images

Bridge-tier services use `localhost` registry images that must be built manually:

```bash
cd path/to/service/Dockerfile
podman build -t localhost/<service-name> .
```

After building, run `salt-call state.apply` to deploy the Quadlet unit.

## Operational FAQ

**Where is the Quadlet unit file on disk?**

- System-scope: `/etc/containers/systemd/<name>.container`
- User-scope: `~/.config/containers/systemd/<name>.container`

Quadlet generates the corresponding systemd unit at `/run/systemd/system/<name>.service` (system) or `~/.config/systemd/user/<name>.service` (user).

**How do I check container health?**

```bash
systemctl status <unit>.service        # systemd view
sudo podman ps --format '...'          # Podman view
curl http://127.0.0.1:<port><health_path>   # HTTP probe
```

For containerized services with `Notify=healthy`, `systemctl status` will only report active AFTER the container's internal HealthCmd passes.

**Where do container logs go?**

Through systemd journal as normal. `journalctl -u <unit>.service` works for both native and containerized forms.

**Why does `systemctl status ollama` show "inactive (dead)" after state.apply?**

Ollama, llama_embed, and t5_summarization have `manual_start: true` — they are not auto-started at boot because the GPU is shared with the desktop compositor. The Quadlet unit is installed and ready, but you must `sudo systemctl start <service>` explicitly.

## References

- `states/_macros_service.jinja` — `container_service` macro source
- `states/data/service_catalog.yaml` — service definitions
- `states/data/container_images.yaml` — image digest registry
