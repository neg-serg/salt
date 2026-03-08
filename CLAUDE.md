# Salt Project — CachyOS Workstation Config

## Overview

Salt states + chezmoi dotfiles for configuring a CachyOS (Arch-based) workstation.
Migrated from NixOS (nix-maid/mkHomeFiles), then Fedora Atomic/Silverblue.
Packages installed via pacman/paru outside Salt; Salt handles configuration management.

## Workflow Requirements

- Before handing results back to the user, run `just` (default `system_description`) to confirm Salt renders successfully and capture any regressions in a fresh apply/log.
- When working under `dotfiles/dot_config/quickshell/`, load the Quickshell knowledge-base router described in `dotfiles/dot_config/quickshell/IMPROVEMENT_PROMPT.md`. It links to the memory files (`memory/quickshell.md`, `memory/generated/qml-components.md`, etc.) that must drive design decisions.

## Key Paths

| Path | Purpose |
|---|---|
| `states/` | Salt state files (`.sls`) and Jinja templates |
| `states/system_description.sls` | Top-level orchestrator: locale, timezone, hostname, include list |
| `states/_macros_*.jinja` | Reusable Jinja macros: common, github, install, pkg, service |
| `states/host_config.jinja` | Per-host config map keyed by `grains['host']` |
| `states/data/floorp.yaml` | Floorp browser extensions (consumed by floorp.sls) |
| `states/configs/` | External config files served via `salt://configs/` |
| `states/units/` | Systemd unit files served via `salt://units/` |
| `states/scripts/` | Shell scripts served via `salt://scripts/` |
| `build/iosevka-neg.toml` | Custom Iosevka font build config |
| `dotfiles/` | Chezmoi source dir (dot_ prefix = . in paths) |
| `docs/` | Documentation (migration tracking, secrets, setup guides) |
| `states/data/` | YAML data files (installers, services, fonts, models, etc.) loaded via `import_yaml` |
| `scripts/` | Utility scripts (linting, tool updates) |

## Salt State Modules (35 files)

| Module | Purpose |
|---|---|
| `system_description.sls` | Top-level orchestrator: locale, timezone, hostname, include list |
| `users.sls` | User accounts, groups, sudo configuration |
| `zsh.sls` | Zsh: system-wide config, ZDOTDIR, user dotfiles |
| `audio.sls` | PipeWire audio stack: pipewire-audio, wireplumber, pulse/alsa/jack |
| `mounts.sls` | Disk mounts (/mnt/zero, /mnt/one), btrfs compression |
| `desktop.sls` | Desktop: system services, SSH, dconf themes |
| `fonts.sls` | All fonts: pacman, Iosevka PKGBUILD, FiraCode, downloaded fonts |
| `installers.sls` | CLI tools: data-driven from `data/installers.yaml` + custom installs |
| `installers_desktop.sls` | Desktop apps: RoomEQ, Throne, Overskride, Nyxt, DroidCam |
| `installers_themes.sls` | Themes/icons: matugen, kora, Flight GTK |
| `kanata.sls` | Kanata keyboard remapper: uinput-based, udev rules, user service |
| `user_services.sls` | User systemd services: chezmoi, mail, vdirsyncer, GPG agent |
| `custom_pkgs.sls` | Data-driven PKGBUILD builds from `data/custom_pkgs.yaml` (raise, duf, richcolors, etc.) |
| `dns.sls` | Unbound, AdGuardHome, Avahi |
| `monitoring.sls` | Sysstat, vnstat, netdata, Loki/Promtail/Grafana stack |
| `services.sls` | Samba, Jellyfin, Bitcoind, DuckDNS |
| `snapshots.sls` | Btrfs snapshot management: snapper, snap-pac, limine-snapper-sync |
| `mpd.sls` | MPD + mpdris2 + mpdas + scrobbling |
| `amnezia.sls` | AmneziaVPN build and deploy |
| `greetd.sls` | greetd login manager (replaces SDDM) |
| `ollama.sls` | Ollama LLM service + model pulls |
| `llama_embed.sls` | llama.cpp embedding server (Qwen3-Embedding via Vulkan) |
| `opencode.sls` | OpenCode AI agent: TUI config + neg custom theme |
| `openclaw_agent.sls` | OpenClaw AI agent: gateway daemon, ProxyPilot routing, Telegram |
| `floorp.sls` | Floorp browser configs + extensions |
| `hardware.sls` | Fan control, GPU, hardware-specific setup |
| `network.sls` | VM bridge, xray, sing-box |
| `steam.sls` | Steam + gaming: multilib repo, Vulkan, gamescope, mangohud |
| `tidal.sls` | TidalCycles live coding: SuperCollider, SuperDirt, GHCi/Tidal |
| `kernel_modules.sls` | Kernel module loading |
| `kernel_params_limine.sls` | Kernel boot parameters via /boot/limine.conf |
| `bind_mounts.sls` | Bind mounts for /mnt paths |
| `sysctl.sls` | Sysctl tuning |
| `cachyos.sls` | Bootstrap verification: checks system state after initial install |
| `cachyos_all.sls` | Full setup entry point: includes cachyos + system_description |

## Macros

### `_macros_common.jinja` — Shared constants

Not a macro file — exports shared variables used by all macro files:
`user`, `home`, `retry_attempts` (3), `retry_interval` (10), `ver_dir`, `sys_ver_dir`.

### `_macros_github.jinja` — GitHub release macros

| Macro | Purpose |
|---|---|
| `github_tar(name, url)` | Download + extract tar.gz to `~/.local/bin/` |
| `github_release_system(name, repo, asset)` | GitHub release install to `/usr/local/bin/` (system-level) |
| `github_release_to(state_id, name, repo, asset, dest)` | GitHub release to arbitrary directory |

### `_macros_install.jinja` — Download/install macros

| Macro | Purpose |
|---|---|
| `curl_bin(name, url)` | Download binary to `~/.local/bin/` |
| `pip_pkg(name, pkg, bin)` | pip install to `~/.local/` |
| `cargo_pkg(name, pkg, bin, git)` | cargo install |
| `curl_extract_tar(name, url, binary_pattern)` | Download + extract tar/tar.gz to `~/.local/bin/` |
| `curl_extract_zip(name, url, binary_path)` | Download + extract zip to `~/.local/bin/` |
| `firefox_extension(ext, profile)` | Download Firefox/Floorp extension from AMO |
| `download_font_zip(name, url, subdir)` | Download + extract font ZIP to `~/.local/share/fonts/` |
| `git_clone_deploy(name, repo, dest)` | Git clone + deploy items to dest |

### `_macros_pkg.jinja` — Package manager macros

| Macro | Purpose |
|---|---|
| `pacman_install(name, pkgs, check, requires)` | pacman install with idempotency guard |
| `simple_service(name, pkgs, service, check, requires)` | Shorthand: pacman install + service.enabled |
| `paru_install(name, pkg, check, requires)` | AUR install via paru |
| `pkgbuild_install(name, source)` | Build + install from local PKGBUILD |
| `npm_pkg(name, pkg, bin)` | npm global install |

### `_macros_service.jinja` — Service/systemd macros

| Macro | Purpose |
|---|---|
| `ensure_dir(name, path, mode, require, user)` | Create directory with ownership and optional mode |
| `udev_rule(name, path, source, contents)` | Deploy udev rule + reload on change |
| `ensure_running(name, service, watch)` | Reset failed state + ensure service running |
| `service_stopped(name, svc, stop, requires)` | Stop and/or disable a service |
| `service_with_healthcheck(name, service, check_cmd, timeout, requires)` | Restart service + poll health check |
| `system_daemon_user(name, home_dir, shell, requires)` | Create system daemon user + data directory |
| `unit_override(name, service, source, filename, requires)` | Deploy systemd unit drop-in override + reload |
| `user_service_file(name, filename, source, user, home)` | Deploy systemd user unit file |
| `user_unit_override(name, service, source, contents, filename, requires, user, home)` | Deploy user unit drop-in override + reload |
| `user_service_enable(name, services, start_now, daemon_reload, check, onlyif, requires, user)` | Enable/start systemd user services |
| `service_with_unit(name, source, unit_type, running, enabled, requires, template, context, onlyif, companion, watch)` | Deploy unit file + manage service lifecycle |

## Network Resilience

All states that access the network (download, install, git clone) must follow these rules:

- **Retry**: `retry: {attempts: retry_attempts, interval: retry_interval}` — import from `_imports.jinja`. Applies to: curl, cargo, pip, npm, paru, pacman, git clone. Does NOT apply to local operations (file.managed, service.enabled, kmod, btrfs).
- **Parallel**: `parallel: True` on independent download/install states. Do NOT use on states with `require` chains to other installs (e.g. vulkan → steam).
- **Idempotency guard**: every download/install state must have `creates:` (file marker) or `unless:` (state check) to avoid re-running on every apply.
- **Curl flags**: always `curl -fsSL` — `-f` fail on HTTP errors, `-sS` silent with errors, `-L` follow redirects.

Macros (`_macros_install.jinja`, `_macros_github.jinja`, `_macros_pkg.jinja`) enforce all four rules automatically. Inline `cmd.run` states that touch the network must apply them manually.

## Idempotency Guards

Every `cmd.run`/`cmd.script` state must have a guard to prevent re-running:

| Guard | When to use | Example |
|---|---|---|
| `creates:` | State produces a known file | `creates: /etc/udev/rules.d/50-qmk.rules` |
| `unless:` | Check command returns 0 when already done | `unless: rg -qx 'steam' {{ pkg_list }}` |
| `onlyif:` | State should only run when condition is true (inverse guard) | `onlyif: command -v firewall-cmd` |

**Guidelines:**
- Prefer `creates:` when the state produces a single file — simplest and most readable.
- Use `unless:` when the result is a system state change (package installed, group membership, kernel module loaded) rather than a single file.
- Use `onlyif:` to conditionally skip states that depend on optional software or hardware (e.g. firewall-cmd may not be installed).
- `onlyif:` and `unless:` can be combined — state runs only when `onlyif` succeeds AND `unless` fails.
- For package checks: `unless: rg -qx 'pkg' {{ pkg_list }}` (uses pacman cache file).
- For module/service checks: `unless: lsmod | rg -q '^mod\b'` or `unless: systemctl is-active svc`.

## `cmd.run` vs `cmd.script`

| | `cmd.run` | `cmd.script` |
|---|---|---|
| **Use when** | Inline command, ≤3 lines | Complex multi-step logic, shared scripts |
| **Source** | `name:` parameter (inline shell) | `source: salt://scripts/foo.sh` (file in `states/scripts/`) |
| **Shell** | Defaults to `/bin/sh`; set `shell: /bin/bash` for bash features | Always set `shell: /bin/bash` explicitly |
| **Timeout** | Default 60s | Set `timeout:` for long builds (e.g. `timeout: 3600`) |
| **Parallel** | Add `parallel: True` if independent | Generally sequential — long-running builds shouldn't compete for CPU |

**When to choose `cmd.script`:**
- The command is reusable or complex enough to warrant a standalone file (≥10 lines).
- The script needs `set -euo pipefail`, functions, or loops.
- Examples: `amnezia-build.sh` (container build, ~3600s), `dxvk-resolution-fix.sh` (multi-step display fix).

**When to keep `cmd.run`:**
- Short one-liners or simple pipes (firewall rules, group membership, config checks).
- Inline content that is clearer in context than as a separate file.

**Examples from this codebase:**

```yaml
# cmd.run ✓ — one-liner, guard via onchanges (sysctl.sls)
sysctl_apply:
  cmd.run:
    - name: sysctl --system
    - onchanges:
      - file: sysctl_config

# cmd.run ✓ — single command, unless guard (users.sls)
neg_groups:
  cmd.run:
    - name: usermod -aG wheel,libvirt,plugdev {{ user }}
    - unless: id -nG {{ user }} | tr ' ' '\n' | rg -qx plugdev

# cmd.script ✓ — 83-line parallel podman build (amnezia.sls → scripts/amnezia-build.sh)
amnezia_build:
  cmd.script:
    - source: salt://scripts/amnezia-build.sh
    - shell: /bin/bash
    - timeout: 3600
    - unless: test -f {{ cache }}/amneziawg-go-bin && ...
    - retry: {attempts: 3, interval: 10}

# cmd.script ✓ — 72-line awk/sed config parsing (kernel_params_limine.sls → scripts/limine-restructure.sh)
limine_flat_boot_entries:
  cmd.script:
    - source: salt://scripts/limine-restructure.sh
    - shell: /bin/bash
    - unless: rg -q '^/CachyOS LTS' /boot/limine.conf
```

## Conventions

- **Chezmoi naming**: `dot_config/foo/bar` deploys to `~/.config/foo/bar`
- **Build containers**: `archlinux:latest`, ephemeral (`--rm`)
- **Inline content**: Configs ≥10 lines go to `configs/`, systemd units go to `units/`, scripts go to `scripts/`
- **Commit style**: `[scope] description` — scope should be specific to what changed (e.g. `[nvim]`, `[zsh]`, `[mpd]`, `[dns]`, `[macros]`, `[fonts]`, `[hyprland]`). Use generic `[salt]` or `[dotfiles]` only for broad refactors that don't fit a specific scope. `[docs]` for documentation.
- **Service enable**: Use `service.enabled` for packages installed via pacman
- **State ID naming**: Use `target_descriptor` pattern (e.g. `loki_config`, `greetd_enabled`, `rfkill_service_masked`). Exception: `install_*` and `build_*` prefixes are reserved for macro-generated IDs. Never use file paths as state IDs — use a descriptive name with explicit `name:` parameter instead.
- **Documentation i18n**: English is the primary language. Each doc in `docs/` and `README.md` must have a `.ru.md` Russian translation (e.g. `gopass-setup.md` → `gopass-setup.ru.md`). Excluded from translation: `CLAUDE.md`, `dotfiles/`, `build/`. English docs must not contain Cyrillic text. Enforced by `scripts/lint-docs.py`.
- **Shell scripts shebang**: All shell scripts in `dotfiles/dot_local/bin/` must use `#!/usr/bin/env zsh`. This ensures `.zshenv` is sourced and XDG user directories (`XDG_MUSIC_DIR`, `XDG_PICTURES_DIR`, etc.) are always available, regardless of how the script is invoked (Hyprland keybind, rofi, systemd). Use `${=var}` for explicit word splitting where needed (zsh does not split `$var` by default unlike sh/bash). Python and nushell scripts keep their own shebangs.
- **XDG user directories**: Canonical source is `environment.d/10-user.conf`. Custom short paths: `~/music`, `~/pic`, `~/vid`, `~/doc`, `~/dw`. Never use canonical XDG defaults (`~/Music`, `~/Pictures`, `~/Documents`, etc.) in code or fallback values.
- **URL/file opening**: Always use `handlr open`, never `xdg-open`. Stock `xdg-open` (xdg-utils) does not recognize Hyprland as a DE — it falls to the `generic` code path where Floorp silently ignores remote IPC and nothing opens. A shim at `~/.local/bin/xdg-open` redirects to `handlr open` for third-party tools, but our own code (dotfiles, scripts) should call `handlr open` directly.

## Platform

- **CachyOS (Arch-based)**: Packages managed via pacman/paru outside Salt
- **Podman (not Docker)**: All container operations use podman
- **Standard paths**: `/home/neg` for user home, `/mnt/one` and `/mnt/zero` for external storage
- **Kernel params**: Managed via `/boot/limine.conf` (Limine bootloader)

## ProxyPilot — AI API Proxy

Local proxy for AI coding tools (Claude Code, OpenCode). Routes requests to providers via OAuth tokens.

| Component | Path / Detail |
|---|---|
| Binary | `~/.local/bin/proxypilot` (downloaded via `curl_bin` macro) |
| Config (chezmoi) | `dotfiles/dot_config/proxypilot/config.yaml.tmpl` |
| Service | `states/units/user/proxypilot.service` (systemd user, always enabled) |
| Listen | `127.0.0.1:8317` |
| Auth tokens | `~/.cli-proxy-api/` (OAuth tokens for Gemini, Antigravity) |
| Version | Pinned in `states/data/versions.yaml` |

**How AI tools connect:**
- Official Claude CLI talks to Anthropic directly. Use the `claude-proxy` wrapper to export `ANTHROPIC_BASE_URL=http://127.0.0.1:8317` + `ANTHROPIC_API_KEY` (from gopass `api/proxypilot-local`) when you explicitly want ProxyPilot.
- Claude Code: configured via `~/.claude/settings.json` `env` block + shell env
- OpenCode: configured via `dotfiles/dot_config/opencode/opencode.json` provider baseURL + shell env
- Management API: `api/proxypilot-management` key in gopass, localhost-only

**Secrets used:**
- `api/proxypilot-local` — client API key for auth to the proxy
- `api/proxypilot-management` — management API key for dashboard/stats

## Secrets

Secrets use **gopass** (GPG + Yubikey). See `docs/secrets-scheme.md` for full design.
- Chezmoi templates: `{{ gopass "key/path" }}` in `.tmpl` files
- Salt states: `gopass show -o key/path` in `cmd.run`
- No plaintext secrets in this repo

## Active Technologies
- Python 3.12+ (code-rag), Jinja2/YAML (Salt states) + tree-sitter-language-pack, lancedb, mcp[cli], httpx (all Python, managed by pipx) (001-code-rag-integration)
- LanceDB (embedded Arrow-based vector DB, local `.lancedb/` directory) (001-code-rag-integration)
- Jinja2/YAML (Salt states), Bash (bootstrap script) + Salt, ProxyPilot v0.3.0-dev-0.40, gopass (GPG + Yubikey) (004-expand-free-providers)
- N/A (config files only) (004-expand-free-providers)
- Jinja2/YAML (Salt states), JSON (OpenClaw config), INI (systemd unit) + Salt, OpenClaw 2026.3.2 (npm), ProxyPilot 0.3.0-dev-0.40, gopass (005-activate-openclaw-bot)
- JSON config file (`~/.openclaw/openclaw.json`) (005-activate-openclaw-bot)

## Recent Changes
- 001-code-rag-integration: Added Python 3.12+ (code-rag), Jinja2/YAML (Salt states) + tree-sitter-language-pack, lancedb, mcp[cli], httpx (all Python, managed by pipx)
