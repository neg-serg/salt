# Salt Project — CachyOS Workstation Config

## Overview

Salt states + chezmoi dotfiles for configuring a CachyOS (Arch-based) workstation.
Migrated from NixOS (nix-maid/mkHomeFiles), then Fedora Atomic/Silverblue.
Packages installed via pacman/paru outside Salt; Salt handles configuration management.

## Key Paths

| Path | Purpose |
|---|---|
| `states/` | Salt state files (`.sls`) and Jinja templates |
| `states/system_description.sls` | Top-level orchestrator: locale, timezone, hostname, include list |
| `states/_macros.jinja` | Reusable Jinja macros (see below) |
| `states/host_config.jinja` | Per-host config map keyed by `grains['host']` |
| `states/data/packages.yaml` | Package reference lists (not consumed by states) |
| `states/data/floorp.yaml` | Floorp browser extensions (consumed by floorp.sls) |
| `states/configs/` | External config files served via `salt://configs/` |
| `states/units/` | Systemd unit files served via `salt://units/` |
| `states/scripts/` | Shell scripts served via `salt://scripts/` |
| `build/iosevka-neg.toml` | Custom Iosevka font build config |
| `dotfiles/` | Chezmoi source dir (dot_ prefix = . in paths) |
| `docs/` | Documentation (migration tracking, secrets, setup guides) |
| `states/data/` | YAML data files (installer definitions) loaded via `import_yaml` |
| `scripts/` | Utility scripts (linting, tool updates) |

## Salt State Modules (30 files)

| Module | Purpose |
|---|---|
| `system_description.sls` | Top-level orchestrator: locale, timezone, hostname, include list |
| `users.sls` | User accounts, groups, sudo configuration |
| `zsh.sls` | Zsh: system-wide config, ZDOTDIR, user dotfiles |
| `audio.sls` | PipeWire audio stack: pipewire-audio, wireplumber, pulse/alsa/jack |
| `mounts.sls` | Disk mounts (/mnt/zero, /mnt/one), btrfs compression |
| `desktop.sls` | Desktop: system services, SSH, wallust defaults, dconf themes |
| `fonts.sls` | All fonts: pacman, Iosevka PKGBUILD, FiraCode, downloaded fonts |
| `installers.sls` | CLI tools: data-driven from `data/installers.yaml` + custom installs |
| `installers_desktop.sls` | Desktop apps: RoomEQ, Throne, Overskride, Nyxt, DroidCam |
| `installers_themes.sls` | Themes/icons: matugen, kora, Flight GTK |
| `user_services.sls` | User systemd services: chezmoi, mail, vdirsyncer, GPG agent |
| `custom_pkgs.sls` | Build raise, neg-pretty-printer, richcolors, albumdetails from PKGBUILDs |
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
| `steam.sls` | Steam + gaming: multilib repo, Vulkan, gamescope, mangohud |
| `kernel_modules.sls` | Kernel module loading |
| `kernel_params_limine.sls` | Kernel boot parameters via /boot/limine.conf |
| `bind_mounts.sls` | Bind mounts for /mnt paths |
| `sysctl.sls` | Sysctl tuning |
| `hy3.sls` | Hyprland hy3 plugin |
| `cachyos.sls` | Bootstrap verification: checks system state after initial install |
| `cachyos_all.sls` | Full setup entry point: includes cachyos + system_description |

## Macros (`_macros.jinja`)

| Macro | Purpose |
|---|---|
| `daemon_reload(name, onchanges)` | systemd daemon-reload on unit file changes |
| `curl_bin(name, url)` | Download binary to `~/.local/bin/` |
| `github_tar(name, url)` | Download + extract tar.gz to `~/.local/bin/` |
| `github_release(name, repo, asset, ...)` | GitHub release install (bin/tar.gz, with tag fetch) |
| `pip_pkg(name, pkg, bin)` | pip install to `~/.local/` |
| `cargo_pkg(name, pkg, bin, git)` | cargo install |
| `github_release_system(name, repo, asset)` | GitHub release install to `/usr/local/bin/` (system-level) |
| `pacman_install(name, pkgs, check, requires)` | pacman install with idempotency guard |
| `pkgbuild_install(name, source)` | Build + install from local PKGBUILD |
| `system_daemon_user(name, home_dir)` | Create system daemon user + data directory |
| `service_with_unit(name, source, enabled)` | Deploy systemd unit + daemon-reload + enable/disable service |
| `user_service(name, filename)` | Deploy inline systemd user unit file (callable macro) |
| `download_font_zip(name, url, subdir)` | Download + extract font ZIP to `~/.local/share/fonts/` |
| `curl_extract_tar(name, url, binary_pattern)` | Download + extract tar/tar.gz to `~/.local/bin/` |
| `curl_extract_zip(name, url, binary_path)` | Download + extract zip to `~/.local/bin/` |
| `run_with_error_context(state_id)` | cmd.run with error handling helpers |

## Conventions

- **Chezmoi naming**: `dot_config/foo/bar` deploys to `~/.config/foo/bar`
- **Build containers**: `archlinux:latest`, ephemeral (`--rm`)
- **Salt creates guard**: `creates:` directive prevents re-running completed builds
- **Inline content**: Configs ≥10 lines go to `configs/`, systemd units go to `units/`, scripts go to `scripts/`
- **Commit style**: `[scope] description` — scope should be specific to what changed (e.g. `[nvim]`, `[zsh]`, `[mpd]`, `[dns]`, `[macros]`, `[fonts]`, `[hyprland]`). Use generic `[salt]` or `[dotfiles]` only for broad refactors that don't fit a specific scope. `[docs]` for documentation.
- **Service enable**: Use `service.enabled` for packages installed via pacman

## Platform

- **CachyOS (Arch-based)**: Packages managed via pacman/paru outside Salt
- **Podman (not Docker)**: All container operations use podman
- **Standard paths**: `/home/neg` for user home, `/mnt/one` and `/mnt/zero` for external storage
- **Kernel params**: Managed via `/boot/limine.conf` (Limine bootloader)

## Secrets

Secrets use **gopass** (GPG + Yubikey). See `docs/secrets-scheme.md` for full design.
- Chezmoi templates: `{{ gopass "key/path" }}` in `.tmpl` files
- Salt states: `gopass show -o key/path` in `cmd.run`
- No plaintext secrets in this repo
