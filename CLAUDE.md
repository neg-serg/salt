# Salt Project — Fedora Atomic Workstation Config

## Overview

Salt states + chezmoi dotfiles for configuring a Fedora Silverblue/Atomic workstation.
Migrated from NixOS (nix-maid/mkHomeFiles). NixOS source: `~/src/nixos-config/`.

## Key Paths

| Path | Purpose |
|---|---|
| `system_description.sls` | Main Salt state: packages, services, installers |
| `build_rpms.sls` | Salt state: orchestrates RPM builds via podman |
| `install_rpms.sls` | Salt state: installs custom RPMs via rpm-ostree |
| `build/build-rpm.sh` | Build script run inside containers |
| `build/specs/*.spec` | RPM spec files |
| `build/iosevka-neg.toml` | Custom Iosevka font build config |
| `rpms/` | Built RPM output (gitignored) |
| `dotfiles/` | Chezmoi source dir (dot_ prefix = . in paths) |
| `docs/` | Documentation (migration tracking, secrets, setup guides) |
| `scripts/` | Utility scripts (rebase, debug, comparison) |
| `docs/nixos-config-ref/` | NixOS config reference (migration source) |

## Conventions

- **Chezmoi naming**: `dot_config/foo/bar` deploys to `~/.config/foo/bar`
- **RPM builds**: Each package has a section in `build/build-rpm.sh` + entry in `build_rpms.sls` + a `build/specs/*.spec` file
- **Build containers**: `registry.fedoraproject.org/fedora-toolbox:43`, ephemeral (`--rm`)
- **Salt creates guard**: `creates:` directive prevents re-running completed builds
- **Commit style**: `[scope] description` — scopes: `salt`, `dotfiles`, `docs`, `rpm`

## Platform Constraints

- **rpm-ostree**: Base image packages are pinned. Layered packages can't upgrade base libs.
  - Current issue: `qt6ct` uninstallable (needs Qt 6.10, base has 6.9.2). Using `qt5ct` + kvantum instead.
- **Fedora Atomic**: `/usr` is read-only. User-level installs go to `~/.local/` or are layered via rpm-ostree.
- **Podman (not Docker)**: All container operations use podman. Build containers mount `build/` and `rpms/` as volumes.

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
