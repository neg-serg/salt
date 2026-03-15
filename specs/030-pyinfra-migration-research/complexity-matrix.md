# Salt-to-pyinfra Migration Complexity Matrix

All 36 Salt state files categorized by migration difficulty, sorted hardest-first.

## Legend

- **Complexity**: Trivial (1-2h), Medium (4-8h), Hard (1-3 days)
- **Hours**: Estimated wall-clock time for a competent developer familiar with both Salt and pyinfra
- **Salt features**: The specific Salt/Jinja patterns that complicate a 1:1 port

## Hard (1-3 days each)

| File | Hours | Key Challenge | Complicating Salt Features |
|---|---|---|---|
| `system_description.sls` | 16-24 | Top-level orchestrator with `include:` pulling 40+ states; stateful `pacman_db_warmup` with `stateful: True` return parsing; must replicate Salt's include/require DAG | `include:`, `stateful: True`, cross-state `require:` (e.g. `pacman_db_warmup` referenced from other states), `timezone.system`, Jinja host config |
| `installers.sls` | 16-24 | Data-driven from `installers.yaml` with 6 different install strategies (curl_bin, github_tar, pip_pkg, cargo_pkg, curl_extract_zip, curl_extract_tar); each strategy is a macro expanding to multi-step cmd.run with caching, version stamps, retry, parallel | `import_yaml`, 6 macro expansions, `parallel: True`, `retry:`, `creates:`, version-stamp idempotency, `onchanges:` (udev reload) |
| `fonts.sls` | 12-16 | Data-driven from `fonts.yaml` + `versions.yaml`; 3 install strategies (pacman, paru, download_font_zip); Iosevka custom PKGBUILD build (7200s timeout) via `pkgbuild_install` macro | `import_yaml` x2, `pkgbuild_install` macro (container build), `download_font_zip` macro, version interpolation |
| `packages.sls` | 12-16 | Data-driven category loop over `packages.yaml`; `pacman_install` macro generates idempotency guards using cached package list; AUR loop with `paru_install` | `import_yaml`, macro-generated `unless: rg -qx` guards, category iteration, `require: pacman_db_warmup` cross-state dep |
| `custom_pkgs.sls` | 12-16 | Data-driven PKGBUILD builds from `custom_pkgs.yaml`; `pkgbuild_install` macro is ~60 lines handling tmpdir, makepkg, conflict resolution, replace_check | `import_yaml`, `pkgbuild_install` macro (complex shell in cmd.run), `timeout:`, conflict resolution logic |
| `openclaw_agent.sls` | 16-24 | 8 chained config migrations with `creates:` markers; gopass secret resolution with AWK fallback; `replace: False` (seed-only deploy); user service lifecycle (file + override + enable + restart-on-change); sanitizer script deploy | `gopass_secret` macro, `replace: False`, `creates:` chain, `onchanges:`, `user_service_file`, `user_unit_override`, `user_service_enable`, `user_service_restart`, Jinja loop for migrations |
| `services.sls` | 16-24 | Mixed data-driven (`services.yaml`) and inline; Samba (config + manual-start), DuckDNS (timer + companion unit), Transmission (ACL setup + file.replace with regex + prereq stop/start cycle) | `import_yaml`, `simple_service` macro, `service_with_healthcheck`, `file.replace` with regex, `prereq:` (stop before settings change), `watch:` (restart after change), ACL commands |
| `dns.sls` | 12-16 | 3 services (Unbound, AdGuardHome, Avahi) each with install + config + unit override + health check + ensure_running with watch; cross-service dependency (resolved -> AdGuardHome -> Unbound) | `simple_service`, `system_daemon_user`, `service_with_unit`, `service_with_healthcheck`, `ensure_running`, `unit_override`, `watch:`, cross-service `require:` chains |
| `monitoring_loki.sls` | 12-16 | 3 services (Loki, Promtail, Grafana) with system daemon users, custom units, health checks, config templates, dashboard provisioning; cross-service deps (Promtail -> Loki) | `system_daemon_user`, `service_with_unit`, `service_with_healthcheck`, `ensure_running`, `watch:`, Jinja template context, conditional requires |
| `desktop.sls` | 12-16 | Pacman hooks, package pinning (`file.replace`), dconf writes with DBUS session bus, service lifecycle (service_with_unit for salt-daemon), data-driven from `desktop.yaml` | `file.replace`, `service_with_unit` (template + context), `service_stopped`, data-driven loops, dconf `cmd.run` with complex unless guard, DBUS env |
| `video_ai.sls` | 12-16 | ComfyUI bootstrap script (3600s), data-driven custom node cloning, parallel model downloads (14400s timeout), symlink management, workflow deployment | `import_yaml`, `cmd.script` (3600s), nested Jinja loops (models -> files), `parallel: True`, `timeout: 14400`, `creates:`, `retry:` |
| `steam.sls` | 12-16 | Multilib repo setup, `--ask 4` conflict resolution, require chains (multilib -> vulkan -> steam), 7z extraction macro, CSS skin symlink loop, dxvk resolution fix script | Non-macro `cmd.run` with `--ask 4`, `require:` chains, `curl_extract_7z` macro, Jinja loop for symlinks, `cmd.script`, `unless:` with for-loop |
| `installers_desktop.sls` | 12-16 | Data-driven from `installers_desktop.yaml` with 4 strategies; inline PKGBUILD patching for rofi-file-browser (sed + makepkg); AUR loop | `import_yaml`, 3 macro types, inline `cmd.run` with PKGBUILD patching, `retry:`, `parallel: True` (via macros) |

## Medium (4-8 hours each)

| File | Hours | Key Challenge | Complicating Salt Features |
|---|---|---|---|
| `user_services.sls` | 6-8 | Data-driven unit file deployment from `user_services.yaml`; feature-flag filtering of enable/disable lists; batch daemon-reload + enable | `import_yaml`, `user_service_file` macro (generates 2 states each), `user_service_enable`, `user_service_disable`, Jinja list manipulation (`do` append), conditional skip logic |
| `mpd.sls` | 6-8 | Conditional companion services (mpdris2, mpdas) based on package presence (`salt['file.search']`); gopass secrets for lastfm; cargo build with custom CFLAGS; tmpfiles.d FIFO | `salt['file.search']` (runtime package check), `gopass_secret`, `cargo_pkg` macro, `user_service_file`, `user_service_enable`, `replace: False`, `include:` with cross-state `require:` |
| `opencode.sls` | 6-8 | ProxyPilot config with gopass + AWK fallback for hashed secrets; free provider key resolution loop; Codex auth; service restart on config change | `gopass_secret` macro, `salt['cmd.run_stdout']` (runtime AWK), Jinja loop with `do` append, `user_service_restart` with `onchanges:`, `npm_pkg` macro |
| `greetd.sls` | 4-6 | Config generation with host-specific context; greeter/session wrapper scripts via Jinja templates; wallpaper cache logic; stale file cleanup | `file.managed` with `template: jinja` + `context:`, host grain conditionals, `service.enabled`, `file.absent` |
| `kernel_params_limine.sls` | 4-6 | Data-driven kargs assembly with host conditionals; `cmd.script` for limine restructuring; inline sed-based param appending with complex unless guard | `import_yaml`, Jinja list assembly with `do`, `cmd.script`, inline bash with `unless:` containing bash arrays, `require:` chain |
| `amnezia.sls` | 4-6 | Container build via `cmd.script` (3600s timeout); binary deploy + symlinks; verification via `onchanges:`; feature-gated | `cmd.script` (timeout: 3600), `retry:`, `onchanges:`, `require:` chains, Jinja for-loops, feature flag |
| `floorp.sls` | 4-6 | Profile-path file deploys; git_clone_deploy for theme; firefox_extension macro loop; unwanted extension cleanup; extensions.json reset on change | `git_clone_deploy` macro, `firefox_extension` macro loop, `file.absent`, `onchanges:` with multi-source watch, feature gate |
| `kanata.sls` | 4-6 | AUR install + uinput module + udev rule + group management + config + user service; 6 different Salt state types in one file | `paru_install`, `udev_rule` macro, `kmod.present`, `group.present`, `user_service_with_unit` macro, `replace: False` |
| `hardware.sls` | 4-6 | Fan control with hwmon auto-detection; service_with_unit for custom units (template + context); kernel module loading; conditional masking | `service_with_unit` (template + context), `udev_rule` macro, `kmod.present`, `service.masked`, feature flags |
| `network.sls` | 4-6 | VM bridge (netdev + network files + firewall-cmd); Xray AUR + custom unit; sing-box TUN service with template context | `paru_install`, `service_with_unit` (template + context), `onchanges:`, `onlyif:`, feature flags |
| `mounts.sls` | 4-6 | Data-driven disk mounts from `mounts.yaml`; btrfs property commands; nocow attribute management | `import_yaml`, `mount.mounted`, Jinja loops, `unless:` with btrfs/lsattr commands |
| `tidal.sls` | 4-6 | SuperDirt quark install via cmd.script (1200s, downloads ~2GB); config file deps on quark completion | `cmd.script` (timeout: 1200), `retry:`, `creates:`, `require:` chain |
| `kernel_modules.sls` | 4-6 | Data-driven module loading with host conditionals; blacklist template; runtime modprobe with dual guards | `kmod.present` equivalent via cmd.run, `file.managed` with template, Jinja loops, `unless:` + `creates:` combo |
| `monitoring.sls` | 4 | Simple macro invocations; unit_override for netdata; feature-gated | `simple_service` macro, `unit_override` macro, feature flags |
| `installers_themes.sls` | 4 | 3 git_clone_deploy macro calls; straightforward but macro internals are complex | `git_clone_deploy` macro (each expands to ~15 states) |
| `ollama.sls` | 4-6 | Service with custom unit template; health check; parallel model pulls with API-based idempotency | `service_with_unit` (template + context), `service_with_healthcheck`, `parallel: True`, `retry:`, API-based `unless:` |
| `cachyos.sls` | 4-6 | Data-driven verification from `cachyos.yaml`; 4 check categories (files, commands, services, packages) | `import_yaml`, Jinja loops x4, `file.exists`, `service.enabled`, variable interpolation in `unless:` |
| `bind_mounts.sls` | 4 | Data-driven bind mounts; fstab_present + manual mount; cross-state require to disk mounts | `import_yaml`, `mount.fstab_present`, `require:` to external state (`mount_one`/`mount_zero`) |

## Trivial (1-2 hours each)

| File | Hours | Key Challenge | Complicating Salt Features |
|---|---|---|---|
| `users.sls` | 2 | User/group management; sudoers with visudo check | `user.present`, `group.present`, `file.managed` with `check_cmd:` |
| `zsh.sls` | 1 | Two file deploys + directory | `ensure_dir` macro, `file.managed` with inline contents |
| `audio.sls` | 1-2 | Loop of 7 pacman_install macro calls | `pacman_install` macro in loop |
| `snapshots.sls` | 2 | Snapper config + timer enables | `pacman_install` macro, `service.enabled`, `file.managed` |
| `sysctl.sls` | 1 | File deploy + apply on change | `file.managed`, `onchanges:` |
| `llama_embed.sls` | 2 | Macro-driven: paru + http_file + service + health check | `paru_install`, `http_file`, `service_with_unit`, `service_with_healthcheck` |
| `cachyos_all.sls` | 0.5 | Two includes | `include:` only |

## Summary

| Complexity | Count | Total Hours (est.) |
|---|---|---|
| Hard | 13 | 160-220 |
| Medium | 18 | 72-108 |
| Trivial | 7 | 8-12 |
| **Total** | **38** | **240-340** |

**Note**: The macro system (`_macros_*.jinja`, 1,338 lines total) must be ported first as a shared Python library. This is an additional **24-40 hours** of work since every macro expands to 5-20 Salt states and must be reimplemented as pyinfra deploy functions with equivalent idempotency, retry, parallel, and version-stamp logic.

**Total estimated migration effort: 264-380 hours (7-10 weeks full-time).**

## Key Migration Blockers

1. **Macro system** (1,338 lines): Salt macros expand to multiple states via Jinja. pyinfra uses Python decorators/functions, requiring complete reimplementation of retry, parallel, version-stamp, and caching logic.
2. **`import_yaml` data-driven patterns**: 15+ states load YAML data files and iterate. pyinfra has no equivalent; must use Python `yaml.safe_load()` directly.
3. **`watch:`/`onchanges:`/`prereq:` requisites**: Salt's reactive system (restart service when config changes) has no direct pyinfra equivalent. Must use `Changed` handlers or manual if-checks.
4. **`parallel: True`**: Salt runs states concurrently. pyinfra runs operations sequentially by default; parallel execution requires `@deploy` with threading or subprocess orchestration.
5. **Cross-state `require:`**: Salt builds a DAG across included states. pyinfra operations run top-to-bottom; cross-file dependencies need explicit import and ordering.
6. **`salt['cmd.run_stdout']` / `salt['file.search']`**: Runtime state evaluation (check if package installed, read config values). pyinfra equivalent is `host.get_fact()` or inline `python()` operations.
7. **`stateful: True`**: Salt parses cmd.run stdout for `changed=yes/no`. No pyinfra equivalent; must use `_success` callbacks.
8. **`replace: False`**: Deploy file only if it does not exist. pyinfra `files.put()` has no built-in equivalent; needs `if not host.get_fact(File, path=...)` guard.
