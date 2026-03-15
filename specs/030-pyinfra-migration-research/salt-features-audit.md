# Salt Features Audit

Comprehensive audit of Salt features used across 47 `.sls` state files and 7 `.jinja` macro files in `states/`.

## Summary Table

| # | Feature | Count | Files | Migration Impact |
|---|---------|------:|------:|------------------|
| 1 | `require:` | 93 | 33 | High — core DAG dependency; pyinfra uses Python ordering + `op()` dependencies |
| 2 | `require_in:` | 0 | 0 | None — not used |
| 3 | `watch:` | 4 | 3 | Medium — restart-on-change; pyinfra has `restart=True` on service ops or handler pattern |
| 4 | `watch_in:` | 0 | 0 | None — not used |
| 5 | `onchanges:` | 11 | 6 | Medium — conditional execution on change; pyinfra uses `_if_changed` callbacks |
| 6 | `onchanges_in:` | 0 | 0 | None — not used |
| 7 | `parallel: True` | 19 | 7 | Low — pyinfra parallelizes across hosts by default; single-host needs threading |
| 8 | `creates:` | 26 | 10 | Low — direct mapping to file-existence checks in Python |
| 9 | `unless:` | 37 | 23 | Low — shell guards translate directly to Python conditionals or `_if` params |
| 10 | `onlyif:` | 24 | 15 | Low — same as `unless:` but inverted; direct Python conditional |
| 11 | `import_yaml` | 33 | 27 | Low — replace with Python `yaml.safe_load()` or direct dict literals |
| 12 | `runas:` | 27 | 11 | Low — pyinfra `_su_user` parameter or `sudo()` context |
| 13 | `file.managed` | 67 | 28 | Low — direct mapping to `files.put` / `files.template` |
| 14 | `service.running` | 5 | 4 | Low — `systemd.service(running=True)` |
| 15 | `service.enabled` | 8 | 5 | Low — `systemd.service(enabled=True)` |
| 16 | `cmd.run` | 68 | 30 | Low — `server.shell()` |
| 17 | `cmd.script` | 5 | 5 | Low — `files.put` + `server.shell()` or `server.script()` |
| 18 | `retry:` | 31 | 12 | Medium — no built-in retry in pyinfra; needs Python wrapper/decorator |
| 19 | `file.directory` | 7 | 6 | Low — `files.directory()` |
| 20 | `file.absent` | 11 | 9 | Low — `files.file(present=False)` |
| 21 | `pkg.installed` | 0 | 0 | None — all packages go through macros (`pacman_install`/`paru_install`) |

**Totals:** 476 feature occurrences across 54 source files.

---

## Detailed Findings

### 1. `require:` — 93 occurrences in 33 files

The most heavily used Salt feature. Establishes explicit execution ordering between states.

**Files:** `_macros_service.jinja` (13), `_macros_pkg.jinja` (4), `_macros_install.jinja` (4), `_macros_github.jinja` (1), `amnezia.sls` (6), `bind_mounts.sls` (1), `code_rag.sls` (1), `desktop.sls` (3), `dns.sls` (4), `flatpak.sls` (1), `greetd.sls` (5), `image_generation.sls` (1), `installers_desktop.sls` (1), `installers_mpv.sls` (2), `kanata.sls` (3), `kernel_modules.sls` (1), `kernel_params_limine.sls` (2), `monitoring_alerts.sls` (2), `monitoring_loki.sls` (1), `mounts.sls` (1), `mpd.sls` (1), `ollama.sls` (1), `openclaw_agent.sls` (3), `opencode.sls` (2), `services.sls` (4), `snapshots.sls` (2), `steam.sls` (7), `telethon_bridge.sls` (2), `tidal.sls` (3), `user_services.sls` (1), `users.sls` (1), `video_ai.sls` (6), `zsh.sls` (2)

**Migration impact:** High. This is the backbone of Salt's dependency DAG. In pyinfra, execution follows Python source order by default, but explicit dependencies require `op()` with `name=` and manual ordering. Complex multi-step chains (e.g. `amnezia.sls` with 6 require chains, `steam.sls` with 7) need careful restructuring.

### 2. `require_in:` — 0 occurrences

Not used. No migration impact.

### 3. `watch:` — 4 occurrences in 3 files

Triggers service restart when a watched file/state changes.

**Files:** `_macros_service.jinja` (2), `dns.sls` (1), `services.sls` (1)

**Migration impact:** Medium. The `watch:` semantic (restart only if config changed) needs explicit change detection. pyinfra's `systemd.service(restarted=True)` always restarts; change-conditional restart requires checking file hashes or using callbacks.

### 4. `watch_in:` — 0 occurrences

Not used. No migration impact.

### 5. `onchanges:` — 11 occurrences in 6 files

Run a command only when a referenced state made changes (e.g. reload udev after rule change).

**Files:** `_macros_service.jinja` (6), `amnezia.sls` (1), `floorp.sls` (1), `installers.sls` (1), `network.sls` (1), `sysctl.sls` (1)

**Migration impact:** Medium. All 6 macro occurrences are in service management (daemon-reload, udev reload, systemd user reload). These are Salt's reactive trigger pattern. pyinfra equivalent: `_if_changed` callback or handler functions. The macro-generated ones (6 of 11) are particularly important since they cascade to every state that uses those macros.

### 6. `onchanges_in:` — 0 occurrences

Not used. No migration impact.

### 7. `parallel: True` — 19 occurrences in 7 files

Allows independent states to execute concurrently within a single Salt run.

**Files:** `_macros_install.jinja` (9), `_macros_github.jinja` (3), `_macros_pkg.jinja` (2), `installers.sls` (1), `installers_mpv.sls` (1), `ollama.sls` (1), `video_ai.sls` (1)

**Migration impact:** Low for multi-host (pyinfra parallelizes across hosts natively). Medium for single-host: pyinfra does not have built-in single-host parallelism. The 14 macro occurrences mean every tool/package downloaded via macros runs in parallel today — losing this would significantly slow applies. Would need Python `concurrent.futures` or similar.

### 8. `creates:` — 26 occurrences in 10 files

Idempotency guard: skip state if the target file already exists.

**Files:** `_macros_install.jinja` (10), `_macros_github.jinja` (3), `_macros_pkg.jinja` (2), `dns.sls` (2), `installers.sls` (1), `installers_mpv.sls` (1), `kernel_modules.sls` (1), `openclaw_agent.sls` (1), `tidal.sls` (1), `video_ai.sls` (3)

**Migration impact:** Low. Direct translation to Python `os.path.exists()` checks or pyinfra `_if=lambda: not os.path.exists(...)`.

### 9. `unless:` — 37 occurrences in 23 files

Idempotency guard: skip state if the shell command succeeds (returns 0).

**Files:** `_macros_pkg.jinja` (5), `_macros_service.jinja` (2), `_macros_install.jinja` (1), `amnezia.sls` (1), `bind_mounts.sls` (1), `cachyos.sls` (2), `code_rag.sls` (1), `desktop.sls` (2), `flatpak.sls` (1), `greetd.sls` (1), `installers_desktop.sls` (1), `kanata.sls` (1), `kernel_modules.sls` (1), `kernel_params_limine.sls` (3), `mounts.sls` (2), `mpd.sls` (1), `ollama.sls` (1), `openclaw_agent.sls` (1), `services.sls` (1), `steam.sls` (4), `system_description.sls` (1), `telethon_bridge.sls` (1), `users.sls` (1)

**Migration impact:** Low. Shell guards translate to Python subprocess checks or pyinfra `_if` parameter. Many use `rg -qx` against a package list cache — this pattern would need a Python helper function.

### 10. `onlyif:` — 24 occurrences in 15 files

Conditional guard: only run state if the shell command succeeds.

**Files:** `_macros_service.jinja` (6), `_macros_install.jinja` (1), `code_rag.sls` (1), `desktop.sls` (1), `dns.sls` (1), `installers.sls` (2), `kanata.sls` (1), `kernel_params_limine.sls` (1), `monitoring_loki.sls` (2), `mounts.sls` (1), `network.sls` (2), `openclaw_agent.sls` (1), `services_bitcoind.sls` (1), `steam.sls` (1), `video_ai.sls` (1)

**Migration impact:** Low. Same as `unless:` but inverted. Direct Python conditional.

### 11. `import_yaml` — 33 occurrences in 27 files

Loads external YAML data files into Jinja context for data-driven state generation.

**Files:** `amnezia.sls`, `bind_mounts.sls`, `cachyos.sls`, `custom_pkgs.sls`, `desktop.sls`, `flatpak.sls`, `floorp.sls`, `fonts.sls`, `host_config.jinja` (2), `image_generation.sls`, `installers.sls` (2), `installers_desktop.sls` (2), `installers_mpv.sls` (2), `kernel_params_limine.sls`, `llama_embed.sls`, `monitoring_alerts.sls`, `mounts.sls`, `music_analysis.sls` (2), `ollama.sls`, `openclaw_agent.sls`, `opencode.sls`, `packages.sls`, `services.sls`, `steam.sls`, `telethon_bridge.sls`, `user_services.sls`, `video_ai.sls`

**Migration impact:** Low. Replace with `yaml.safe_load(open(...))` in Python. The data-driven pattern (load YAML, iterate, generate states) maps cleanly to Python loops calling pyinfra operations.

### 12. `runas:` — 27 occurrences in 11 files

Execute commands as a specific user (typically `neg`).

**Files:** `_macros_install.jinja` (11), `_macros_github.jinja` (2), `_macros_service.jinja` (5), `_macros_pkg.jinja` (1), `desktop.sls` (1), `greetd.sls` (1), `installers.sls` (1), `installers_mpv.sls` (1), `steam.sls` (1), `tidal.sls` (1), `video_ai.sls` (3)

**Migration impact:** Low. pyinfra supports `_su_user` parameter or `sudo(user=...)` context manager.

### 13. `file.managed` — 67 occurrences in 28 files

The most-used Salt state module. Deploys files from templates or source.

**Files:** `_macros_service.jinja` (6), `amnezia.sls` (4), `desktop.sls` (1), `dns.sls` (4), `floorp.sls` (1), `greetd.sls` (3), `hardware.sls` (2), `image_generation.sls` (1), `kanata.sls` (2), `kernel_modules.sls` (2), `kernel_params_limine.sls` (1), `monitoring_alerts.sls` (3), `monitoring_loki.sls` (6), `mpd.sls` (3), `network.sls` (2), `openclaw_agent.sls` (2), `opencode.sls` (2), `services.sls` (2), `services_bitcoind.sls` (1), `snapshots.sls` (2), `steam.sls` (3), `sysctl.sls` (1), `system_description.sls` (2), `telethon_bridge.sls` (3), `tidal.sls` (2), `users.sls` (2), `video_ai.sls` (2), `zsh.sls` (2)

**Migration impact:** Low. Direct mapping to `files.put()`, `files.template()`, or `files.file()`. Key Salt features used alongside: `source:` (salt:// paths), `template: jinja`, `context:` (template variables), `mode:`, `user:`/`group:`, `replace: False`. The Jinja template rendering needs migration to Jinja2 (pyinfra supports it) or Python f-strings.

### 14. `service.running` — 5 occurrences in 4 files

Ensure a system service is running.

**Files:** `_macros_service.jinja` (2), `desktop.sls` (1), `dns.sls` (1), `services.sls` (1)

**Migration impact:** Low. Direct mapping to `systemd.service(service, running=True)`.

### 15. `service.enabled` — 8 occurrences in 5 files

Ensure a system service is enabled at boot.

**Files:** `_macros_pkg.jinja` (1), `cachyos.sls` (1), `desktop.sls` (2), `greetd.sls` (2), `snapshots.sls` (2)

**Migration impact:** Low. Direct mapping to `systemd.service(service, enabled=True)`.

### 16. `cmd.run` — 68 occurrences in 30 files

The second most-used feature. Executes shell commands.

**Files:** `_macros_service.jinja` (11), `_macros_pkg.jinja` (5), `_macros_install.jinja` (10), `_macros_github.jinja` (3), `amnezia.sls` (1), `bind_mounts.sls` (1), `cachyos.sls` (2), `code_rag.sls` (1), `desktop.sls` (2), `dns.sls` (2), `flatpak.sls` (1), `greetd.sls` (1), `installers.sls` (2), `installers_desktop.sls` (1), `installers_mpv.sls` (1), `kanata.sls` (1), `kernel_modules.sls` (1), `kernel_params_limine.sls` (3), `mounts.sls` (2), `mpd.sls` (1), `network.sls` (1), `ollama.sls` (1), `openclaw_agent.sls` (2), `services.sls` (1), `steam.sls` (3), `sysctl.sls` (1), `system_description.sls` (2), `telethon_bridge.sls` (1), `users.sls` (1), `video_ai.sls` (3)

**Migration impact:** Low. Direct mapping to `server.shell()`. The 29 macro-generated `cmd.run` calls mean most shell commands come from reusable patterns — migrating the macros covers the majority.

### 17. `cmd.script` — 5 occurrences in 5 files

Executes external script files (complex multi-step operations).

**Files:** `amnezia.sls` (1), `kernel_params_limine.sls` (1), `steam.sls` (1), `tidal.sls` (1), `video_ai.sls` (1)

**Migration impact:** Low. Map to `files.put()` + `server.shell()` or `server.script()`. All 5 use `source: salt://scripts/` and have explicit `timeout:` and `shell: /bin/bash`.

### 18. `retry:` — 31 occurrences in 12 files

Automatic retry on failure for network operations.

**Files:** `_macros_install.jinja` (10), `_macros_github.jinja` (3), `_macros_pkg.jinja` (5), `amnezia.sls` (1), `flatpak.sls` (1), `installers.sls` (1), `installers_desktop.sls` (1), `installers_mpv.sls` (1), `ollama.sls` (1), `steam.sls` (3), `tidal.sls` (1), `video_ai.sls` (3)

**Migration impact:** Medium. pyinfra has no built-in retry mechanism. Need a Python decorator or wrapper function:
```python
def with_retry(fn, attempts=3, interval=10):
    ...
```
The 18 macro occurrences mean this decorator would be applied in the macro equivalents, covering most cases automatically.

### 19. `file.directory` — 7 occurrences in 6 files

Create directories with specific ownership and permissions.

**Files:** `_macros_service.jinja` (2), `_macros_install.jinja` (1), `monitoring_loki.sls` (1), `mounts.sls` (1), `mpd.sls` (1), `user_services.sls` (1)

**Migration impact:** Low. Direct mapping to `files.directory()`.

### 20. `file.absent` — 11 occurrences in 9 files

Remove files or directories.

**Files:** `dns.sls` (1), `floorp.sls` (2), `greetd.sls` (1), `installers.sls` (1), `kanata.sls` (1), `monitoring_alerts.sls` (1), `monitoring_loki.sls` (2), `network.sls` (1), `services_bitcoind.sls` (1)

**Migration impact:** Low. Direct mapping to `files.file(present=False)` or `files.directory(present=False)`.

### 21. `pkg.installed` — 0 occurrences

Not used directly. All package installation goes through the `pacman_install` and `paru_install` macros in `_macros_pkg.jinja`, which use `cmd.run` with `pacman -S --noconfirm` / `paru -S --noconfirm` under the hood (with `unless:` guards checking against a cached package list).

**Migration impact:** None for this specific feature, but the macro-based package management pattern needs migration.

---

## Macro Amplification

The 7 macro files act as code generators. A single macro call in a `.sls` file expands to multiple Salt states. Actual runtime state count is significantly higher than the raw file counts suggest:

| Macro file | Features generated per call |
|---|---|
| `_macros_pkg.jinja` | `cmd.run` + `unless:` + `retry:` + `require:` (+ optional `service.enabled`) |
| `_macros_install.jinja` | `cmd.run` + `creates:` + `parallel:` + `retry:` + `runas:` |
| `_macros_github.jinja` | `cmd.run` + `creates:` + `parallel:` + `retry:` + `runas:` |
| `_macros_service.jinja` | `file.managed` + `file.directory` + `cmd.run` + `onchanges:` + `require:` + `service.running` |

**Key insight:** Migrating the 7 macro files (to Python functions/decorators) would automatically cover ~60% of all feature usage. The remaining ~40% is in direct `.sls` state definitions.

---

## Migration Risk Assessment

### High Risk (need architectural decisions)
- **`require:` (93 uses)** — Salt's implicit DAG must become explicit Python ordering or operation dependencies. Most chains are linear and can be expressed via source order, but cross-file dependencies (e.g. `packages.sls` → `steam.sls`) need a strategy.

### Medium Risk (need custom abstractions)
- **`retry:` (31 uses)** — No pyinfra built-in; need a retry decorator.
- **`watch:` / `onchanges:` (15 uses combined)** — Reactive triggers need change-detection wrappers.
- **`parallel: True` (19 uses)** — Single-host parallelism for downloads needs threading abstraction.

### Low Risk (direct API mapping)
- All file operations (`file.managed`, `file.directory`, `file.absent`) — 85 uses total
- All command execution (`cmd.run`, `cmd.script`) — 73 uses total
- All service management (`service.running`, `service.enabled`) — 13 uses total
- All guards (`creates:`, `unless:`, `onlyif:`) — 87 uses total
- Data loading (`import_yaml`) — 33 uses
- User context (`runas:`) — 27 uses
