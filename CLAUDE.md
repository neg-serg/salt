# Salt Project — CachyOS Workstation Config

## Overview

Salt states + chezmoi dotfiles for configuring a CachyOS (Arch-based) workstation.
Migrated from NixOS (nix-maid/mkHomeFiles), then Fedora Atomic/Silverblue.
Packages installed via pacman/paru outside Salt; Salt handles configuration management.

## Key Paths

| Path | Purpose |
|---|---|
| `states/` | Salt state files (`.sls`) and Jinja templates |
| `states/system_description.sls` | Core system setup: flatpak, mounts, users, zsh |
| `states/_macros.jinja` | Reusable Jinja macros (see below) |
| `states/host_config.jinja` | Per-host config map keyed by `grains['host']` |
| `states/packages.jinja` | Package reference lists, flatpak apps |
| `states/configs/` | External config files served via `salt://configs/` |
| `states/units/` | Systemd unit files served via `salt://units/` |
| `states/scripts/` | Shell scripts served via `salt://scripts/` |
| `build/iosevka-neg.toml` | Custom Iosevka font build config |
| `dotfiles/` | Chezmoi source dir (dot_ prefix = . in paths) |
| `docs/` | Documentation (migration tracking, secrets, setup guides) |
| `scripts/` | Utility scripts (linting, comparison) |

## Salt State Modules (21 files)

| Module | Purpose |
|---|---|
| `system_description.sls` | Core: timezone, locale, users, flatpak, mounts, zsh |
| `installers.sls` | CLI tools: GitHub releases, pip/cargo installs, scripts, themes |
| `user_services.sls` | User systemd services: chezmoi, mail, vdirsyncer, GPG agent |
| `dns.sls` | Unbound, AdGuardHome, Avahi |
| `monitoring.sls` | Sysstat, vnstat, netdata, Loki/Promtail/Grafana stack |
| `services.sls` | Samba, Jellyfin, Bitcoind, DuckDNS |
| `mpd.sls` | MPD + mpdris2 + mpdas + scrobbling |
| `amnezia.sls` | AmneziaVPN build and deploy |
| `greetd.sls` | greetd login manager (replaces SDDM) |
| `ollama.sls` | Ollama LLM service + model pulls |
| `floorp.sls` | Floorp browser configs + extensions |
| `hardware.sls` | Fan control, GPU, hardware-specific setup |
| `network.sls` | VM bridge, xray, sing-box |
| `kernel_modules.sls` | Kernel module loading |
| `kernel_params_limine.sls` | Kernel boot parameters via /boot/limine.conf |
| `bind_mounts.sls` | Bind mounts for /mnt paths |
| `distrobox.sls` | Distrobox containers (Steam gaming) |
| `sysctl.sls` | Sysctl tuning |
| `fira-code-nerd.sls` | FiraCode Nerd Font install |
| `iosevka.sls` | Custom Iosevka Nerd Font build from PKGBUILD |
| `custom_pkgs.sls` | Build raise, neg-pretty-printer, richcolors, albumdetails from PKGBUILDs |
| `hy3.sls` | Hyprland hy3 plugin |

## Macros (`_macros.jinja`)

| Macro | Purpose |
|---|---|
| `daemon_reload(name, onchanges)` | systemd daemon-reload on unit file changes |
| `curl_bin(name, url)` | Download binary to `~/.local/bin/` |
| `github_tar(name, url)` | Download + extract tar.gz to `~/.local/bin/` |
| `github_release(name, repo, asset, ...)` | GitHub release install (bin/tar.gz, with tag fetch) |
| `pip_pkg(name, pkg, bin)` | pip install to `~/.local/` |
| `cargo_pkg(name, pkg, bin, git)` | cargo install |
| `pacman_install(name, pkgs, check, requires)` | pacman install with idempotency guard |
| `system_daemon_user(name, home_dir)` | Create system daemon user + data directory |
| `service_with_unit(name, source)` | Deploy systemd unit + enable service |
| `curl_extract_tar(name, url, binary_pattern)` | Download + extract tar/tar.gz to `~/.local/bin/` |
| `curl_extract_zip(name, url, binary_path)` | Download + extract zip to `~/.local/bin/` |
| `run_with_error_context(state_id)` | cmd.run with error handling helpers |

## Conventions

- **Chezmoi naming**: `dot_config/foo/bar` deploys to `~/.config/foo/bar`
- **Build containers**: `archlinux:latest`, ephemeral (`--rm`)
- **Salt creates guard**: `creates:` directive prevents re-running completed builds
- **Inline content**: Configs ≥10 lines go to `configs/`, systemd units go to `units/`, scripts go to `scripts/`
- **Commit style**: `[scope] description` — scopes: `salt`, `dotfiles`, `docs`
- **Service enable**: Use `service.enabled` for packages installed via pacman

## Platform

- **CachyOS (Arch-based)**: Packages managed via pacman/paru outside Salt
- **Podman (not Docker)**: All container operations use podman
- **Standard paths**: `/home/neg` for user home, `/mnt/one` and `/mnt/zero` for external storage
- **Kernel params**: Managed via `/etc/kernel/cmdline` + `reinstall-kernels`

## Secrets

Secrets use **gopass** (GPG + Yubikey). See `docs/secrets-scheme.md` for full design.
- Chezmoi templates: `{{ gopass "key/path" }}` in `.tmpl` files
- Salt states: `gopass show -o key/path` in `cmd.run`
- No plaintext secrets in this repo
