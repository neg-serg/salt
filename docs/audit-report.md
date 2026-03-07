# Salt Infrastructure Audit Report

Audit of CachyOS workstation Salt states + chezmoi dotfiles per `docs/audit-prompt.xml`.

**Date:** 2026-03-07
**Scope:** `states/*.sls`, `states/_macros_*.jinja`, `states/data/*.yaml`, `states/scripts/*`, `states/units/*`, `states/configs/*`

## Executive Summary

| Severity | Total | Fixed | Accepted | Open |
|----------|-------|-------|----------|------|
| Critical | 0     | —     | —        | —    |
| High     | 4     | 4     | 0        | 0    |
| Medium   | 3     | 1     | 2        | 0    |
| Low      | 2     | 1     | 1        | 0    |

**Overall state: GOOD.** No critical issues found. All high-severity findings have been fixed.
The codebase demonstrates strong patterns: consistent macro usage, proper idempotency guards on
all 59 cmd.run/cmd.script states, correct dependency chains, and comprehensive network resilience.

## Phase 1 Analysis Results (T1.1–T1.9)

### T1.1 Idempotency — PASS

All 59 cmd.run/cmd.script states have correct guards:
- `creates:` — 18 states (file artifact check)
- `unless:` — 28 states (state condition check)
- `onchanges:` — 8 states (event-driven)
- `onlyif:` — 3 states (conditional execution)
- `stateful: True` — 1 state (pacman_db_warmup, self-reporting)
- `prereq:` — 1 state (transmission stop-before-config)

All 3 `replace: False` usages are justified (self-modifying configs: kanata, AdGuardHome, OpenClaw).
Service patterns are correct: socket-activated services (libvirtd, pcscd) use `service.enabled` only.
No restart loops detected — `replace: False` prevents cascading restarts on unchanged configs.

### T1.2 Dependencies — PASS

25+ cross-file require/watch/onchanges references validated — all point to existing state IDs.
Macro-generated IDs (install_*, *_enabled, *_daemon_reload) verified against template code.
No circular dependencies. No implicit ordering issues.
All pkg.installed → service.enabled orderings correct.
All file.managed → service.running watches present.
Conditional requires handled properly via Jinja feature flags.

### T1.3 Network Resilience — PASS

All network operations use macros with built-in retry (`attempts: 3, interval: 10`),
`curl -fsSL` flags, and `parallel: True` where safe. Timeouts appropriate:
- Default downloads: 60s
- Ollama model pulls: 660s (large models)
- Amnezia container build: 3600s
- Tidal SuperCollider build: 1200s

No `parallel: True` on states with require chains to other network states.

### T1.4 Health Checks — PASS

All services listed in G4 acceptance criteria have health checks:
- **dns.sls:** Unbound (`unbound-control status`, 30s), AdGuardHome (`GET /`, 30s)
- **monitoring.sls:** Loki (`GET /ready`, 30s), Promtail (`GET /ready`, 30s), Grafana (`GET /api/health`, 30s)
- **ollama.sls:** Ollama (`GET /api/tags`, 30s)
- **llama_embed.sls:** Llama-embed (`GET /health`, 90s — extended for GPU model loading)
- **services.sls:** Jellyfin (`GET /health`, 30s), Transmission (`GET /transmission/web/`, 30s)

Services without health checks (justified):
- Avahi: passive service discovery, no startup issues
- Bitcoind: manual-start only (`enabled=False`)
- DuckDNS: timer-driven oneshot, no persistent server
- Samba: manual-start only (`service_stopped`)
- Xray/sing-box: no built-in health endpoint

### T1.5 Security — PASS

No plaintext secrets found in state files — all use gopass references.
File modes properly restricted: openclaw.json (0600), mpdasrc (0600), sudoers (0440).
DuckDNS token passed via stdin (`curl -d @-`), not command-line arguments.
Sudoers grants narrowly scoped to specific binaries.
Udev rules use safe patterns (MODE, GROUP, TAG+="uaccess").

### T1.6 Style — PASS (98.3%)

115+ state IDs checked — 98.3% follow `target_descriptor` pattern.
2 minor deviations: `qmk_udev_rules_reload` (action suffix), `transmission_stop_before_settings_change` (verbose).
No inline implementations duplicating macro functionality.
All paths use `{{ home }}`/`{{ user }}` — zero hardcoded `/home/neg`.
All inline content blocks appropriately sized (<30 lines).
All 17 `import_yaml` references point to existing files.

### T1.7 Systemd Units — PASS

21 units analyzed (10 system, 11 user).
All enabled services have `[Install]` sections (duckdns-update.service intentionally lacks one — timer-driven).
Restart policies configured: `on-failure` (most services), `always` (ollama, llama-embed).
All network services have `After=network-online.target`.
Hardening applied: NoNewPrivileges (20/21), RestrictNamespaces (19/21), PrivateTmp (19/21).
ProtectHome omitted for ollama/llama-embed (need model access) — accepted risk.
PrivateDevices omitted for fancontrol/sing-box (need hardware access) — accepted risk.
Timer configs correct: `Persistent=true` on all timers.

### T1.8 Macros — PASS

34 macros across 5 files. All have:
- Correct `creates:`/`unless:` guards matching real artifacts
- `retry: {attempts: 3, interval: 10}` on network operations
- `parallel: True` where appropriate
- Proper shell quoting — no injection vectors found

`gopass_secret` uses `python_shell=True` with string concatenation, but key paths are
always static literals (e.g., `'api/anthropic'`) — accepted risk with documentation.
No unused macros identified.
No state ID conflicts from macro expansion — all IDs namespaced by name parameter.

### T1.9 Data Files — PASS

17 YAML data files validated — all syntactically correct and actively consumed.
No orphaned entries. No duplicates within files.
`feature_matrix.yaml` initially flagged as unused — actually consumed by `host_config.jinja`
for render-matrix testing (synthetic host scenarios for CI).
`hosts.yaml` is the production host config source, not deprecated.
25 versions pinned in `versions.yaml`, all referenced via `${VER}` substitution.

## Findings

### High Severity

| ID  | File | Category | Description | Status |
|-----|------|----------|-------------|--------|
| F01 | services.sls | Health | Missing health checks for Jellyfin and Transmission | **FIXED** |
| F10 | monitoring.sls, snapshots.sls, desktop.sls | Deps | Bare service.enabled without pacman_install (sysstat, vnstat, snapper, libvirt, pcsclite) — breaks G2 on clean system | **FIXED** |
| F02 | scripts/duckdns-update.sh | Security | DuckDNS token was passed via curl cmdline args | **FIXED** (ba8880c) |
| F03 | dotfiles/dot_config/ | Security | Secret files (zsh secrets, mbsync, msmtp, vdirsyncer, rescrobbled, imapnotify) lacked chezmoi `private_` prefix for 0600 mode | **FIXED** (ba8880c) |
| F04 | _macros_pkg.jinja, _macros_common.jinja | Macros | npm `--prefix` missing (EACCES on global install); gopass fallback pattern absent | **FIXED** (8ad94a8) |

### Medium Severity

| ID  | File | Category | Description | Status |
|-----|------|----------|-------------|--------|
| F05 | states/units/*.service | Hardening | System services missing ProtectSystem/ProtectHome/NoNewPrivileges/PrivateTmp | **FIXED** (cd91a38) |
| F06 | states/units/ollama.service, llama-embed.service | Hardening | No ProtectHome — services need `$HOME` or `/mnt` access for model cache | **ACCEPTED** |
| F07 | states/units/fancontrol.service, sing-box-tun.service | Hardening | No PrivateDevices — services need direct hardware/TUN device access | **ACCEPTED** |

### Low Severity

| ID  | File | Category | Description | Status |
|-----|------|----------|-------------|--------|
| F08 | Multiple .sls files | Style | Unused Jinja imports (imported macros not called) | **FIXED** (24c7b35) |
| F09 | _macros_common.jinja:32 | Macros | `gopass_secret` uses `python_shell=True` with key path concatenation | **ACCEPTED** — key paths are static literals only |

## Accepted Risks

**F06 — Ollama/Llama-embed without ProtectHome:**
These services load ML models from `$HOME/.ollama` and `/mnt/one`. Adding `ProtectHome=read-only`
would require relocating model storage to a system directory. Current setup follows Ollama upstream defaults.

**F07 — Fancontrol/Sing-box without PrivateDevices:**
Fancontrol reads hardware sensors via `/sys/class/hwmon`. Sing-box creates TUN network adapters.
Both require direct device access by design.

**F09 — gopass_secret python_shell:**
The macro concatenates `'gopass show -o ' ~ key` where `key` is always a hardcoded string
like `'api/anthropic'` or `'lastfm/password'`. No user input reaches this path.
Documented in CLAUDE.md memory as a convention constraint.

## Readiness Criteria

| ID  | Test | Blocking | Status |
|-----|------|----------|--------|
| RC1 | `just` exits with code 0 | Yes | Verified |
| RC2 | Second `just` run — zero changed states | Yes | Verified |
| RC3 | All critical/high findings fixed | Yes | **PASS** — 0 critical, 4/4 high fixed |
| RC4 | Medium findings fixed or documented | No | **PASS** — 1 fixed, 2 accepted with rationale |
| RC5 | No new lint errors | No | Verified |
| RC6 | No regressions introduced | Yes | **PASS** — all services remain enabled, configs deployed |
