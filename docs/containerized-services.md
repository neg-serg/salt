# Containerized Services (Podman Quadlet)

This document describes the operational model for services that have been
migrated from native pacman/AUR deployments to digest-pinned Podman Quadlet
containers under the 087-containerize-services feature.

## Why containerize

Five inference and observability services have strong value from
containerization: **runtime isolation** from host package churn, **explicit
and reversible upgrades** via digest bumps, and **reproducible provisioning**
on a fresh host. Bridge services (Telegram / OpenCode) are structurally
supported but their digests are deferred until first-party upstream images
are identified.

Services explicitly kept native (and not to be containerized):

- Audio stack (Pipewire, WirePlumber) — D-Bus session and ALSA/JACK coupling
- VPN and tunneling (Tailscale, AmneziaVPN, Zapret2, Hiddify) — kernel caps,
  TUN devices, raw sockets, iptables/ipset
- DNS (Unbound, AdGuardHome) — tightly coupled to host resolver
- MPD — MPRIS2 D-Bus integration
- NanoClaw — already runs rootless Podman as its core function
- Bitcoin Core, Jellyfin, Transmission — operational concerns outweigh the
  containerization benefit

See `specs/087-containerize-services/spec.md` §Out of scope for the full list
and the reasoning behind each exclusion.

## Per-service status

| Service | Tier | Cutover mode | Quadlet unit | Feature toggle |
|---------|------|--------------|--------------|----------------|
| `ollama` | US1 inference | in-place | `ollama.service` | `features.containers.ollama` |
| `llama_embed` | US1 inference | in-place | `llama_embed.service` | `features.containers.llama_embed` |
| `loki` | US2 observability | blue/green | `loki-container.service` | `features.containers.loki` |
| `promtail` | US2 observability | hard cutover | `promtail-container.service` | `features.containers.promtail` |
| `grafana` | US2 observability | hard cutover | `grafana-container.service` | `features.containers.grafana` |
| `telethon_bridge` | US3 bridge | in-place (deferred) | `telethon-bridge.service` | `features.containers.telethon_bridge` |
| `opencode_serve` | US3 bridge | in-place (deferred) | `opencode-serve.service` | `features.containers.opencode_serve` |
| `opencode_telegram_bot` | US3 bridge | in-place (deferred) | `opencode-telegram-bot.service` | `features.containers.opencode_telegram_bot` |
| `telecode` | US3 bridge | in-place (deferred) | `telecode.service` | `features.containers.telecode` |

"Deferred" means the feature toggle is wired, the Quadlet unit template exists,
and the state file branch is in place, but the digest in
`states/data/container_images.yaml` is null — flipping the toggle today
emits only a visible `_container_deferred` no-op state, and the service
continues to run in its native form.

## Data layout

- `states/data/service_catalog.yaml` — single source of truth for every
  service's port, health endpoint, scope, package set, and (for
  containerizable services) bind mounts, GPU requirement, cutover mode,
  cutover date, and `container_image` key.
- `states/data/container_images.yaml` — digest registry. Each top-level key
  is a `container_image` reference from the service catalog, with
  `registry`, `image`, `variant`, `digest`, `approved_at`, and `note` fields.
  Tag-based references are forbidden (FR-014). A non-null digest MUST match
  `sha256:<64 hex chars>`.
- `states/data/hosts.yaml` — `defaults.features.containers.*` toggles. Each
  boolean is the rollback lever for its service: `false` = native, `true` =
  containerized. Flipping to `true` MUST be paired with setting
  `service_catalog.yaml[<service>].cutover_date` to today's date in the
  same commit.

## Cutover procedure

For the full end-to-end smoke test with timing, verification, and rollback
drill, see `specs/087-containerize-services/quickstart.md`. The condensed
form:

1. **Verify prerequisites**: Podman ≥5.0, GPU devices present (inference
   layer only), model cache populated.
2. **Capture native baseline**: 5-run trimmed-median cold-start protocol
   from `quickstart.md` §Step 1. Record in
   `specs/087-containerize-services/research.md` §Decision 6 table.
3. **Enable toggle**: set `features.containers.<service>: true` in
   `states/data/hosts.yaml` and `cutover_date: <today>` in
   `states/data/service_catalog.yaml` under the service entry.
4. **Resolve digest**: run `podman pull <registry>/<image>:<variant>`,
   then `podman image inspect --format '{{.Id}}'` to capture the sha256
   digest. Write it to `container_images.yaml[<service>].digest` and set
   `approved_at` to today. Commit as a separate single-purpose commit.
5. **Apply**: `sudo salt-call --local state.apply <service>`.
6. **Verify**: the Quadlet file exists, the generated systemd unit is
   active, the health endpoint returns 200, and downstream clients continue
   to work without config changes.
7. **Measure**: run the same cold-start protocol against the containerized
   form. Must be within 150% of the baseline (SC-007).

## Rollback (per cutover mode)

### In-place rollback (Ollama, llama_embed, bridges)

1. Flip `features.containers.<service>: false` in `hosts.yaml`.
2. `sudo salt-call --local state.apply <service>`.
3. Verify: the Quadlet file at `/etc/containers/systemd/<name>.container`
   (or `~/.config/containers/systemd/` for user-scope) is gone, the native
   service is running on the same port, and state (model cache, credentials,
   etc.) is intact via the bind-mounted host paths.

Target: under 5 minutes wall-clock (SC-003).

### Blue/green rollback (Loki)

The native Loki keeps running on port 3101 during the rollback window
precisely so this case is trivial:

1. Flip `features.containers.loki: false` in `hosts.yaml`.
2. `sudo salt-call --local state.apply monitoring_loki`.
3. Salt rebinds the native Loki from 3101 back to 3100 (by updating
   `loki_config` and restarting the native service) and removes the
   containerized `loki-container.service` via `file.absent` on the Quadlet
   unit file.
4. The temporary `loki-native-archive.yaml` Grafana datasource is removed
   in the same apply.
5. Verify: `curl http://127.0.0.1:3100/ready` returns 200, Grafana Explore
   shows only the primary Loki datasource (no archive entry), no stale
   Quadlet file on disk.

### Promtail and Grafana (hard cutover)

Promtail and Grafana use hard cutover (one form active at a time), so their
rollback is the same single-command flip as the in-place case.

## Rollback window (7 days)

Every containerized service has a `cutover_date` field in the service
catalog. Seven days after that date, the `<service>_native_teardown`
`pkg.removed` state becomes eligible to fire. This is a scheduled reminder,
not an automatic action: the operator must run a `state.apply` after the
window closes to actually remove the native package.

Loki's teardown is more than `pkg.removed`: it must atomically remove the
port-3101 config override AND the temporary Grafana archive datasource. See
`tasks.md` T054 for the full checklist.

## Digest bump workflow

Upgrading a containerized service to a newer upstream image is a single
two-line commit to `states/data/container_images.yaml`:

1. `podman pull <registry>/<image>:<variant>` (pull the new tag).
2. `podman image inspect --format '{{.Id}}'` to capture the sha256.
3. Update `digest` and `approved_at` for the service entry.
4. Commit with message `[<service>] bump container digest to <first 12
   chars>`.
5. `sudo salt-call --local state.apply <service>` — the macro's
   `podman image exists` guard skips the pull if the digest is already
   local, then restarts the service via the `watch:` chain.

Rolling back to the previous digest is the symmetric operation: `git
revert` the bump commit, apply.

## Operational FAQ

**Where is the Quadlet unit file on disk?**

- System-scope: `/etc/containers/systemd/<name>.container`
- User-scope: `~/.config/containers/systemd/<name>.container`

Quadlet generates the corresponding systemd unit at `/run/systemd/system/<name>.service`
(system) or `~/.config/systemd/user/<name>.service` (user, at daemon-reload time).

**Why does Loki use `loki-container.service` but Ollama uses `ollama.service`?**

Loki needs both native and containerized forms to coexist during the
rollback window (native on 3101 for historical queries, container on 3100
for new writes). Giving the containerized form a distinct systemd unit
name avoids the runtime-vs-library unit shadowing. Hard-cutover services
(Ollama, Promtail, Grafana, bridges) don't have this requirement so they
reuse the native unit name via Quadlet's default naming.

**How do I check container health?**

```bash
systemctl status <unit>.service        # systemd view
sudo podman ps --format '...'          # Podman view
curl http://127.0.0.1:<port><health_path>   # HTTP probe
```

For containerized services with `Notify=healthy`, `systemctl status` will
only report active AFTER the container's internal HealthCmd passes — so
"active" already implies healthy.

**Where do container logs go?**

Through systemd journal as normal. `journalctl -u <unit>.service` works for
both native and containerized forms without changes.

**Why does `systemctl status ollama` show "inactive (dead)" after state.apply?**

Ollama and llama_embed have `manual_start: true` in the service catalog —
neither form is auto-started at boot because the GPU is shared with the
desktop compositor. The Quadlet unit is installed and ready, but you must
`sudo systemctl start ollama` explicitly before using it. This is the
designed state, not a bug.

## Failure modes

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| `salt-call` render error citing missing digest | null digest for a P1/P2 service | Populate digest via bump workflow, retry |
| Render error citing digest format | digest is not `sha256:<64 hex>` | Fix the digest value (FR-014 violation) |
| Container runs but healthcheck fails | GPU passthrough broken, or HealthCmd path wrong | `podman logs <name>`, verify device nodes in rendered unit file |
| `systemctl status` reports "no such unit" | daemon-reload not triggered, or Quadlet file wrong name | `sudo systemctl daemon-reload`, check file exists under `/etc/containers/systemd/` |
| Cold-start over 150% of baseline | first-time image pull, cold page cache | Re-measure after warm-up; investigate if consistently over |

For anything not in this table: capture
`sudo salt-call --local state.apply <service> -l debug 2>&1 | tail -200`
plus `sudo journalctl -u <unit>.service --since '5 min ago'` and open an
issue with both attached.

## References

- `specs/087-containerize-services/spec.md` — feature specification
- `specs/087-containerize-services/plan.md` — implementation plan
- `specs/087-containerize-services/research.md` — Phase 0 decisions (Podman
  Quadlet, GPU passthrough, digest registry format, NanoClaw deferral,
  rollback window, baseline protocol, P3 upstream-image gate)
- `specs/087-containerize-services/quickstart.md` — operator smoke test
- `specs/087-containerize-services/contracts/` — macro signature, catalog
  schema, Quadlet unit template contract
- `states/_macros_service.jinja` — `container_service` macro source
