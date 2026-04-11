# Salt Infrastructure Audit Report

## Version History

| Version | Date | Scope |
|---------|------|-------|
| v1.0 | 2026-03-07 | Code quality: idempotency, deps, network resilience, security, style |
| v2.0 | 2026-03-07 | Reproducibility: full deployment walkthrough, secrets, feature flags, URLs, boundaries |

---

## Executive Summary

| Severity | Count | Description |
|----------|-------|-------------|
| Critical | 0 | No deploy-blocking issues |
| High | 5 | Degraded deploy or runtime failures |
| Medium | 10 | Suboptimal resilience, cosmetic, implicit deps |
| Low | 7 | Documentation gaps, dead code, minor duplication |

**Overall assessment: MOSTLY REPRODUCIBLE.** A fresh CachyOS install following the documented
steps will produce a functional workstation, but with several gaps requiring manual intervention
or prior knowledge. The Salt state layer is robust — excellent idempotency (100% guard coverage),
correct dependency chains, and comprehensive macro enforcement. The main gaps are at the
**boundaries**: Salt/chezmoi overlap, gopass dependency for chezmoi `.tmpl` files, documentation
of post-deploy manual steps, and unpinned external URLs.

**Confidence level**: A developer familiar with the system can deploy successfully.
A new developer following only the documentation would hit 3-5 blockers requiring troubleshooting.

---

## Deployment Walkthrough

Tracing a fresh deployment through the documented flow (steps from `docs/deploy-cachyos.md`):

### Step 1: Bootstrap (`scripts/bootstrap-cachyos.sh`)

| Action | Expected | Actual | Gap |
|--------|----------|--------|-----|
| Run bootstrap as root | Creates rootfs at `/mnt/one/cachyos-root/` | Works | None |
| Podman available | Required by script (line 92-95) | Validated | **Docs don't mention podman prerequisite** |
| Salt repo copied | Copied to `/mnt/one/salt/` | Works | None |
| Custom packages built | iosevka-neg-fonts, raise, etc. | Works but `gem install ansi` fails silently | **F01: ruby not in PACMAN_PKGS** |

### Step 2: Deploy (`scripts/deploy-cachyos.sh /dev/nvme0n1`)

| Action | Expected | Actual | Gap |
|--------|----------|--------|-----|
| Partition NVMe | GPT + LVM + btrfs | Works | **Docs lack data destruction warning** |
| Install Limine | Bootloader configured | Works | None |
| Generate fstab | Correct mount points | Works | None |
| Write POST-BOOT.md | Post-boot instructions to /root/ | Works | POST-BOOT.md more detailed than deploy-cachyos.md |

### Step 3: First Boot

| Action | Expected | Actual | Gap |
|--------|----------|--------|-----|
| Activate VGs | `vgchange -ay xenon argon` | Works | None |
| Mount XFS disks | `/mnt/one`, `/mnt/zero` | Works | None |
| hostname = "cachyos" | Aliases to telfir config | Works | **Second machine would get telfir's 4K/fancontrol config** |

### Step 4: gopass + Salt Apply

| Action | Expected | Actual | Gap |
|--------|----------|--------|-----|
| `gopass clone <store-url>` | Secrets available | **Placeholder URL in docs** | **F06: no store URL or GPG key IDs documented** |
| `scripts/cachyos-packages.sh` | ~400 packages installed | Works (with retries) | None |
| `scripts/salt-apply.sh` | All states pass | Works | None |
| Salt: mpdas_config | Configures Last.fm scrobbler | **Fails if gopass unavailable** | **F02: raw gopass without fallback** |
| chezmoi apply | Dotfiles deployed | **Fails if gopass unavailable** | **F03: 7 .tmpl files need gopass** |
| floorp config (non-telfir) | Browser profile configured | **Files written to wrong directory** | **F04: empty floorp_profile default** |

### Step 5: Reboot and Verify

| Action | Expected | Actual | Gap |
|--------|----------|--------|-----|
| greetd starts | Login screen | Works (cage + regreet, agreety fallback) | None |
| Services running | All enabled services up | Works | None |
| DNS configured | Unbound + optional AdGuardHome | Works | **Docs don't mention DNS will change** |

---

## Findings by Severity

### HIGH

**F01 — Missing `ruby` package for taoup color output**
- Task: T1 (Tool Dependencies)
- File: `scripts/cachyos-packages.sh:507`
- Problem: `gem install ansi --no-document --no-user-install` requires `ruby`, which is not in
  `PACMAN_PKGS` or `AUR_PKGS`. Fails silently (`|| true`), but `taoup` lacks ANSI color output.
- Fix: Add `ruby` to `PACMAN_PKGS` in `scripts/cachyos-packages.sh`.
- Verify: `gem install ansi` succeeds; `taoup` outputs colored text.

**F02 — `mpdas_config` uses raw gopass without fallback**
- Task: T2 (Secrets)
- File: `states/mpd.sls:80-92`
- Problem: Uses inline `gopass show -o lastfm/username` and `gopass show -o lastfm/password`
  inside `set -eo pipefail`. If gopass is unavailable on first run (before `~/.config/mpdasrc`
  exists), the state fails hard. All other Salt states use the `gopass_secret()` macro with
  graceful fallback.
- What breaks: `mpdas_config` state fails, Salt reports error. Subsequent runs skip it (`creates:` guard).
- Fix: Refactor to use `gopass_secret()` macro, or add `|| true` with empty-value check.
- Verify: `just test` with gopass unavailable; state should degrade, not fail.

**F03 — chezmoi apply fails without gopass (7 `.tmpl` files)**
- Task: T2 (Secrets)
- File: `scripts/salt-apply.sh:282`, `dotfiles/dot_config/` (7 template files)
- Problem: `chezmoi apply --force` is called after Salt succeeds. All `.tmpl` files with
  `{{ gopass "..." }}` fail if gopass is unavailable. Since `set -euo pipefail` is active,
  the script exits non-zero even though Salt states all passed.
- Affected templates: `proxypilot/config.yaml.tmpl`, `mbsync/private_mbsyncrc.tmpl`,
  `imapnotify/private_gmail.json.tmpl`, `msmtp/private_config.tmpl`,
  `rescrobbled/private_config.toml.tmpl`, `vdirsyncer/private_config.tmpl`,
  `zsh/private_10-secrets.zsh.tmpl`
- Fix options: (a) Add `--exclude` patterns for `.tmpl` files on first run, or (b) wrap chezmoi
  in a non-fatal block with diagnostic output, or (c) document that Yubikey/gopass must be
  configured before salt-apply.
- Verify: `salt-apply.sh` completes end-to-end with gopass configured.

**F04 — `floorp_profile=""` creates orphaned configs**
- Task: T4 (Feature Flags) / T8 (Host Config)
- File: `states/floorp.sls:7`
- Problem: Default `floorp_profile: ""` with `floorp: true` (also default) causes
  `{% set floorp_profile = home ~ '/.floorp/' ~ host.floorp_profile %}` to resolve to
  `~/.floorp/` (the profile root, not a specific profile). All config files (user.js,
  userChrome.css, extensions) are written to a directory Floorp ignores.
- Affects: Any non-telfir host using defaults.
- Fix: Add guard in `floorp.sls`: `{% if host.features.floorp and host.floorp_profile %}`
  to skip states when no profile is configured.
- Verify: `just render-matrix` with a synthetic host having empty `floorp_profile`.

**F05 — Python 3.14 sed patch is fragile**
- Task: T11 (Runtime Stability)
- File: `scripts/salt-apply.sh:55-61`
- Problem: `sed -i` patches Salt's `url.py` source with a fixed pattern. If Salt's code changes
  (even within the `>=3006,<3008` range), the sed silently does nothing, and Salt breaks on
  Python 3.14's `urlunparse` behavior. Manual `pip install --upgrade salt` loses the patch.
- Fix: Pin exact Salt version in `requirements.txt` (e.g., `salt==3006.10`), or move the patch
  to `salt_compat.py` as a runtime monkey-patch (survives pip upgrades).
- Verify: Delete `.venv`, re-run `salt-apply.sh`, confirm Salt works.

### MEDIUM

**F06 — gopass store URL placeholder in documentation**
- Task: T9 (Documentation)
- File: `docs/deploy-cachyos.md` (Step 4)
- Problem: `gopass clone <store-url>` has placeholder. No GPG key IDs, no Yubikey init steps.
  A new deployer cannot complete this step.
- Fix: Add gopass store URL (or reference to `docs/gopass-setup.md`) and GPG key fingerprints.

**F07 — Implicit ordering on `user_neg` state**
- Task: T3 (Execution Order)
- Files: `zsh.sls`, `desktop.sls`, `greetd.sls`, and others
- Problem: States that set file ownership to `neg` rely on `users.sls` running first via include
  order but have no explicit `require: user: user_neg`. Salt guarantees include order within a
  highstate, but explicit requires are more robust.
- Risk: LOW in practice (users.sls is always first include), MEDIUM architecturally.
- Fix: Add `require: user: user_neg` to key states in `zsh.sls` that own files as `neg`.

**F08 — Promtail without Loki = runtime log spam**
- Task: T4 (Feature Flags)
- File: `states/monitoring.sls`, `states/configs/promtail.yaml.j2:7`
- Problem: If `promtail=true` and `loki=false`, Promtail pushes to `127.0.0.1:3100` endlessly.
  Salt apply succeeds, but journal fills with connection errors.
- Fix: Add cross-flag validation: `{% if host.features.monitoring.promtail and not host.features.monitoring.loki %}` → warning or skip promtail.

**F09 — No hash pinning in requirements.txt**
- Task: T11 (Runtime Stability)
- File: `requirements.txt`
- Problem: No `--require-hashes` flag. Salt venv runs as root — a compromised PyPI package
  could execute arbitrary code as root during bootstrap.
- Fix: Add hash pinning or use a lockfile (`pip-compile` with hashes).

**F10 — Salt/chezmoi dual-write for 8 paths**
- Task: T7 (Boundary)
- Files: `opencode.sls`, `mpd.sls`, `zsh.sls`, `user_services.sls`
- Problem: 8 file paths are managed by both Salt (`file.managed`/`file.recurse` sourced from
  `salt://dotfiles/...`) and chezmoi (which deploys from the same source tree). Content is
  identical but the double-write is wasteful and permissions may diverge.
- Fix: Choose one owner per file. Salt should manage files it needs for `watch`/`onchanges`
  triggers; chezmoi should own purely declarative dotfiles.

**F11 — chezmoi apply has no retry or diagnostic on failure**
- Task: T7 (Boundary) / T11 (Runtime)
- File: `scripts/salt-apply.sh:282`
- Problem: `chezmoi apply --force` runs once, no retry. On failure (gopass timeout, Yubikey
  not present), `set -euo pipefail` exits immediately with no indication of which files failed.
- Fix: Wrap in a diagnostic block that lists which `.tmpl` files need gopass, or add
  `|| { echo "chezmoi failed — check gopass/Yubikey"; exit 1; }`.

**F12 — amnezia.sls no explicit require on mount_one**
- Task: T4 (Feature Flags) / T3 (Execution Order)
- File: `states/amnezia.sls:4`
- Problem: Uses `host.mnt_one` for cache directory without explicit `require: mount: mount_one`.
  Relies on `mounts.sls` running earlier via include order.
- Fix: Add explicit require.

**F13 — ProxyPilot pre-release version (0.3.0-dev-0.39)**
- Task: T5 (URL Resilience)
- File: `states/data/versions.yaml:32`
- Problem: Pre-release version may be removed from GitHub when stable releases. Download cache
  mitigates this for existing installs, but fresh deploys would fail.
- Mitigation: Already cached locally. Monitor for stable release.

**F14 — Documentation missing error recovery guidance**
- Task: T9 (Documentation)
- File: `docs/deploy-cachyos.md`
- Problem: No guidance on: (a) what to do if salt-apply partially fails, (b) whether re-running
  is safe, (c) manual steps needed after salt-apply (Floorp profile, Steam login, email setup).
- Fix: Add "Troubleshooting" section covering partial failure recovery and post-deploy checklist.

**F15 — Display manager swap risk on partial failure**
- Task: T11 (Runtime Stability)
- File: `states/greetd.sls`
- Problem: If SDDM is disabled but greetd enable fails, no display manager on next reboot.
  Mitigated by `getty@tty2` emergency TTY, but docs should mention this recovery path.

### LOW

**F16 — `kernel.variant` is a dead feature flag**
- Task: T4 (Feature Flags)
- File: `states/data/hosts.yaml:32`
- Problem: `features.kernel.variant: lto` defined in defaults but never referenced by any `.sls` file.
- Fix: Remove the dead flag or implement kernel-variant-specific behavior.

**F17 — Feature matrix missing edge case tests**
- Task: T4 (Feature Flags)
- File: `states/data/feature_matrix.yaml`
- Problem: No test scenario for `floorp=true, floorp_profile=""` or "all features off".
- Fix: Add synthetic host scenarios for these edge cases.

**F18 — 2 accidental AUR package duplicates**
- Task: T10 (Package Overlap)
- Files: `scripts/cachyos-packages.sh`, `states/installers_desktop.sls`, `states/desktop.sls`
- Problem: `overskride-bin` and `xdg-desktop-portal-termfilechooser-...-git` installed by both
  `cachyos-packages.sh` and Salt, with no additional Salt config management.
- Fix: Remove from one location (prefer `cachyos-packages.sh` since Salt adds no config).

**F19 — 26+ HIGH-risk unpinned external URLs**
- Task: T5 (URL Resilience)
- Files: Various `.sls`, `data/mpv_scripts.yaml`, `data/floorp.yaml`
- Problem: Multiple URLs pointing to git HEAD (`zi`, `hyprevents`, `dr14_tmeter`, `rustnet`,
  `kora-icons`, `matugen-themes`), master branch raw files (mpv scripts, qmk udev rules,
  blesh nightly), `/latest/` endpoints (all 21 Floorp extensions), and unpinned PyPI/crates.io
  packages (`httpstat`, `scdl`, `faker`, `pzip`, `wiremix`).
- All have retry + idempotency guards (no CRITICAL), but content reproducibility is not guaranteed.
- Fix: Pin versions where possible. For git repos, use tagged releases or commit SHAs.

**F20 — Grafana datasource references dead Loki when loki=false**
- Task: T4 (Feature Flags)
- File: `states/monitoring.sls:80-88`
- Problem: When `grafana=true` but `loki=false`, a Loki datasource is provisioned pointing to
  `127.0.0.1:3100`. Grafana works but shows a red/errored datasource.
- Fix: Conditionalize datasource provisioning on `loki` flag.

**F21 — `cachyos -> telfir` alias affects all fresh CachyOS installs**
- Task: T8 (Host Config)
- File: `states/data/hosts.yaml:87`
- Problem: Any fresh CachyOS install (hostname = "cachyos") gets telfir-specific config
  (4K display, fancontrol, monitoring stack). A second machine would need manual hostname
  change before running Salt.
- Fix: Document this behavior in `docs/adding-host.md` or remove the alias.

**F22 — opencode.sls has no feature gate** (openclaw_agent removed 2026-04-11)
- Task: T4 (Feature Flags)
- Files: `states/opencode.sls`
- Problem: This state always runs regardless of host config. On a minimal host profile,
  it would install npm packages and configure services unconditionally.
- Severity: Low — currently intentional (single workstation), but limits multi-host flexibility.

---

## Dependency Maps

### Tool Dependency Summary (T1)

100+ external commands audited across all 37 `.sls` files. **1 missing tool found:**

| Tool | Source | Used By | Impact |
|------|--------|---------|--------|
| `gem` (Ruby) | **MISSING** | `scripts/cachyos-packages.sh:507` | taoup lacks color output (silent failure) |

All other tools correctly sourced from: BASE system (coreutils, systemd, kmod, btrfs-progs),
PACMAN_PKGS (ripgrep, curl, git, cargo, pipx, npm, gopass, podman, etc.),
AUR_PKGS (paru, mpdas, mpdris2, etc.), or Salt-installed binaries (via macros).
**No ordering issues found** — all require chains are correct.

### Secrets Dependency Summary (T2)

16 unique gopass key paths identified:

| Secret Key | Layer | Fallback | Impact if Missing |
|------------|-------|----------|-------------------|
| `api/proxypilot-local` | Salt + chezmoi | awk parse config | Degraded (empty key) |
| `api/proxypilot-management` | Salt + chezmoi | awk parse config | Degraded (no dashboard) |
| `api/anthropic` | Salt | empty string | Degraded (no Anthropic API) |
| `api/nanoclaw-telegram` | Salt | empty string | Degraded (no Telegram bot) |
| `api/nanoclaw-telegram-uid` | Salt | empty string | Degraded (same) |
| `lastfm/username` | Salt (raw!) | **NONE** | **BROKEN** (F02) |
| `lastfm/password` | Salt (raw!) | **NONE** | **BROKEN** (F02) |
| `lastfm/api-key` | chezmoi | **NONE** | **BROKEN** (chezmoi fails) |
| `lastfm/api-secret` | chezmoi | **NONE** | **BROKEN** (chezmoi fails) |
| `email/gmail/address` | chezmoi | **NONE** | **BROKEN** (chezmoi fails) |
| `email/gmail/app-password` | runtime only | N/A | App-level auth failure |
| `caldav/google/client-id` | chezmoi | **NONE** | **BROKEN** (chezmoi fails) |
| `caldav/google/client-secret` | chezmoi | **NONE** | **BROKEN** (chezmoi fails) |
| `api/github-token` | chezmoi | **NONE** | **BROKEN** (chezmoi fails) |
| `api/brave-search` | chezmoi | **NONE** | **BROKEN** (chezmoi fails) |
| `api/context7` | chezmoi | **NONE** | **BROKEN** (chezmoi fails) |

**Salt rendering phase**: Degrades gracefully (except mpdas_config F02).
**chezmoi phase**: Hard fails on all 7 `.tmpl` files (F03).

### External URL Risk Summary (T5)

| Risk Level | Count | Examples |
|------------|-------|---------|
| LOW | 16 | All `data/installers.yaml` entries (version + hash + retry + guard) |
| MEDIUM | 15 | kanata (no hash), tailray (cargo git), AUR packages, HuggingFace model |
| HIGH | 26+ | git HEAD clones, master raw files, Floorp /latest/, unpinned pip/cargo |
| CRITICAL | 0 | All URLs have at least retry + idempotency guard |

---

## Remediation Roadmap

### Phase 1: Deploy Blockers (before next fresh deploy)

| Finding | Fix | Effort |
|---------|-----|--------|
| F03 | Wrap chezmoi apply with diagnostic error handling | 15 min |
| F06 | Fill in gopass store URL + GPG key IDs in docs | 10 min |
| F14 | Add troubleshooting/recovery section to deploy docs | 30 min |

### Phase 2: High-Severity Fixes

| Finding | Fix | Effort |
|---------|-----|--------|
| F01 | Add `ruby` to PACMAN_PKGS | 1 min |
| F02 | Refactor mpdas_config to use gopass_secret() macro | 15 min |
| F04 | Add `floorp_profile` guard in floorp.sls | 5 min |
| F05 | Pin exact Salt version or move patch to salt_compat.py | 30 min |

### Phase 3: Medium-Severity Improvements

| Finding | Fix | Effort |
|---------|-----|--------|
| F07 | Add explicit `require: user: user_neg` to zsh.sls | 5 min |
| F08 | Add promtail cross-flag validation | 10 min |
| F09 | Add hash pinning to requirements.txt | 20 min |
| F10 | Deduplicate Salt/chezmoi file ownership | 30 min |
| F11 | Add chezmoi retry/diagnostic | 15 min |
| F12 | Add mount_one require to amnezia.sls | 2 min |

### Phase 4: Low-Severity Polish

| Finding | Fix | Effort |
|---------|-----|--------|
| F16 | Remove dead kernel.variant flag | 2 min |
| F17 | Add edge case feature matrix scenarios | 10 min |
| F18 | Remove 2 AUR duplicates from one location | 5 min |
| F19 | Pin versions for high-risk URLs (ongoing) | Variable |
| F20 | Conditionalize Grafana Loki datasource | 5 min |
| F21 | Document cachyos alias behavior | 5 min |
| F22 | Consider feature flag for opencode | 5 min |

---

## v1.0 Findings (Preserved)

The following findings from the v1.0 audit remain valid and are preserved for reference.
All v1.0 HIGH findings were fixed in prior commits.

### v1.0 Summary

| Severity | Total | Fixed | Accepted |
|----------|-------|-------|----------|
| Critical | 0 | — | — |
| High | 4 | 4 | 0 |
| Medium | 3 | 1 | 2 |
| Low | 2 | 1 | 1 |

All 59 cmd.run/cmd.script states passed idempotency checks.
25+ cross-file dependency chains validated.
21 systemd units analyzed for hardening.
34 macros across 5 files validated.
17 YAML data files syntactically correct and consumed.

### v1.0 Findings Reference

| ID | Severity | Description | Status |
|----|----------|-------------|--------|
| F01-v1 | High | Missing health checks for Jellyfin and Transmission | Fixed |
| F02-v1 | High | DuckDNS token passed via curl cmdline args | Fixed (ba8880c) |
| F03-v1 | High | Secret files lacked chezmoi `private_` prefix | Fixed (ba8880c) |
| F04-v1 | High | npm `--prefix` missing; gopass fallback pattern absent | Fixed (8ad94a8) |
| F05-v1 | Medium | System services missing hardening directives | Fixed (cd91a38) |
| F06-v1 | Medium | Ollama/llama-embed without ProtectHome | Accepted |
| F07-v1 | Medium | Fancontrol/sing-box without PrivateDevices | Accepted |
| F08-v1 | Low | Unused Jinja imports | Fixed (24c7b35) |
| F09-v1 | Low | gopass_secret uses python_shell=True | Accepted |
| F10-v1 | High | Bare service.enabled without pacman_install | Fixed |
