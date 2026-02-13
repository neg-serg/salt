# Salt Project — Fedora Atomic Workstation Config

## Overview

Salt states + chezmoi dotfiles for configuring a Fedora Silverblue/Atomic workstation.
Migrated from NixOS (nix-maid/mkHomeFiles). NixOS source: `~/src/nixos-config/`.

## Key Paths

| Path | Purpose |
|---|---|
| `states/` | Salt state files (`.sls`) and Jinja templates |
| `states/system_description.sls` | Core system setup: packages, repos, flatpak, mounts, users |
| `states/_macros.jinja` | Reusable Jinja macros (9 macros, see below) |
| `states/host_config.jinja` | Per-host config map keyed by `grains['host']` |
| `states/packages.jinja` | Package lists by category, COPR repos, flatpak apps |
| `states/configs/` | External config files served via `salt://configs/` |
| `states/units/` | Systemd unit files served via `salt://units/` |
| `states/scripts/` | Shell scripts served via `salt://scripts/` |
| `states/build_rpms.sls` | Orchestrates RPM builds via podman |
| `states/install_rpms.sls` | Installs custom RPMs via rpm-ostree |
| `build/build-rpm.sh` | Build script run inside containers |
| `build/specs/*.spec` | RPM spec files |
| `build/iosevka-neg.toml` | Custom Iosevka font build config |
| `rpms/` | Built RPM output (gitignored) |
| `dotfiles/` | Chezmoi source dir (dot_ prefix = . in paths) |
| `docs/` | Documentation (migration tracking, secrets, setup guides) |
| `scripts/` | Utility scripts (rebase, debug, comparison, linting) |

## Salt State Modules (23 files)

| Module | Purpose |
|---|---|
| `system_description.sls` | Core: containers, timezone, locale, users, packages, flatpak, mounts, zsh |
| `installers.sls` | CLI tools: GitHub releases, pip/cargo installs, scripts, themes |
| `user_services.sls` | User systemd services: chezmoi, mail, vdirsyncer, GPG agent |
| `dns.sls` | Unbound, AdGuardHome, Avahi |
| `monitoring.sls` | Sysstat, vnstat, netdata, Loki/Promtail/Grafana stack |
| `services.sls` | Samba, Jellyfin, Bitcoind, DuckDNS |
| `build_rpms.sls` | RPM builds via podman containers |
| `install_rpms.sls` | rpm-ostree install of custom RPMs |
| `mpd.sls` | MPD + mpdris2 + mpdas + scrobbling |
| `amnezia.sls` | AmneziaVPN build and deploy |
| `greetd.sls` | greetd login manager (replaces SDDM) |
| `ollama.sls` | Ollama LLM service + SELinux + model pulls |
| `floorp.sls` | Floorp browser configs + extensions |
| `hardware.sls` | Fan control, GPU, hardware-specific setup |
| `network.sls` | VM bridge, xray, sing-box |
| `kernel_modules.sls` | Kernel module loading |
| `kernel_params.sls` | Kernel boot parameters |
| `bind_mounts.sls` | Bind mounts for /var/mnt paths |
| `distrobox.sls` | Distrobox containers + Steam SELinux |
| `sysctl.sls` | Sysctl tuning |
| `pkg_cache.sls` | RPM package cache on /mnt/one |
| `fira-code-nerd.sls` | FiraCode Nerd Font install |
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
| `selinux_policy(state_id, module)` | Compile + load SELinux policy module |
| `selinux_fcontext(name, selinux_path, real_path, ...)` | SELinux file context labeling |
| `ostree_install(name, pkgs, check, requires)` | rpm-ostree install with idempotency guard |

## Conventions

- **Chezmoi naming**: `dot_config/foo/bar` deploys to `~/.config/foo/bar`
- **RPM builds**: Each package has a section in `build/build-rpm.sh` + entry in `states/build_rpms.sls` + a `build/specs/*.spec` file
- **Build containers**: `registry.fedoraproject.org/fedora-toolbox:43`, ephemeral (`--rm`)
- **Salt creates guard**: `creates:` directive prevents re-running completed builds
- **Inline content**: Configs ≥10 lines go to `configs/`, systemd units go to `units/`, scripts go to `scripts/`
- **Commit style**: `[scope] description` — scopes: `salt`, `dotfiles`, `docs`, `rpm`
- **SELinux fcontext**: Use `selinux_fcontext` macro. Guard with `ls -Zd | grep -q TYPE`, not `matchpathcon -V`
- **Service enable**: Use `service.enabled` for base packages; use `cmd.run: systemctl enable` for rpm-ostree layered packages

## Platform Constraints

- **rpm-ostree**: Base image packages are pinned. Layered packages can't upgrade base libs.
  - Current issue: `qt6ct` uninstallable (needs Qt 6.10, base has 6.9.2). Using `qt5ct` + kvantum instead.
- **Fedora Atomic**: `/usr` is read-only. User-level installs go to `~/.local/` or are layered via rpm-ostree.
- **Podman (not Docker)**: All container operations use podman. Build containers mount `build/` and `rpms/` as volumes.
- **SELinux path equivalency**: `/var/mnt` → use `/mnt` in `semanage fcontext`, `/home` → use `/var/home`

## Secrets

Secrets use **gopass** (GPG + Yubikey). See `docs/secrets-scheme.md` for full design.
- Chezmoi templates: `{{ gopass "key/path" }}` in `.tmpl` files
- Salt states: `gopass show -o key/path` in `cmd.run`
- No plaintext secrets in this repo

## Custom RPMs (35 packages)

Rust: bandwhich, choose, erdtree, fclones, grex, htmlq, jujutsu, kmon, lutgen, ouch, raise, taplo, viu, wallust, xh
Go: carapace, ctop, curlie, dive, doggo, duf, massren, nerdctl, pup, scc, zfxtop, zk
C/meson: pipemixer, xdg-desktop-portal-termfilechooser
Python: epr, git-filter-repo, neg-pretty-printer, rapidgzip, richcolors, scour, xxh
Ruby: gist
Font: iosevka-neg-fonts
Qt6/C++: quickshell
