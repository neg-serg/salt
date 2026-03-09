# Data Model: Salt Package Management

## Entity: Package Declaration (in `states/data/packages.yaml`)

### YAML Structure

```yaml
# states/data/packages.yaml
# Categorized package declarations for Salt-managed installation.
# Official repo packages are installed via pacman; AUR packages via paru.
# Packages managed by domain-specific states (audio.sls, steam.sls, etc.)
# are NOT listed here — see pkg-snapshot.zsh --report for the full map.

base:
  - base
  - base-devel
  - linux-cachyos-lts
  - linux-cachyos-lts-headers
  - linux-firmware

desktop:
  - hyprland
  - waybar
  - rofi-wayland
  - foot
  - wl-clipboard
  - xdg-utils

dev:
  - git
  - neovim
  - python
  - rustup
  - go

network:
  - networkmanager
  - openssh
  - curl
  - wget

audio:
  # NOTE: pipewire packages managed by audio.sls — not listed here

media:
  - ffmpeg
  - mpv
  - imagemagick

fonts:
  # NOTE: font packages managed by fonts.sls — not listed here

gaming:
  # NOTE: steam/vulkan packages managed by steam.sls — not listed here

system:
  - btrfs-progs
  - snapper
  - htop
  - rsync

aur:
  - paru-bin
  - hyprpicker-git
  - wl-screenrec-git

other:
  - unzip
  - p7zip
  - tree
```

### Field Semantics

| Field | Type | Description |
|-------|------|-------------|
| Category key | `string` | YAML top-level key. Maps to a functional domain. |
| Package name | `string` | Exact pacman/AUR package name. Must match `pacman -Si` or `paru -Si` output. |
| Source type | implicit | Packages under `aur:` key are AUR; all other keys are official repo. |

### Validation Rules

- Package names must be valid pacman package identifiers (lowercase, digits, hyphens, dots, underscores).
- No duplicate package names across categories (enforced by the analysis script and drift check).
- Empty categories are allowed (used for documentation comments, e.g., "managed by audio.sls").
- Comments (lines starting with `#`) explain why a category is empty or reference the owning state.

### Relationships

- **Package → Category**: Many-to-one. Each package belongs to exactly one category.
- **Category → Salt state**: Informational. Categories align with existing `.sls` files but the central `packages.sls` installs all categories.
- **Package ↔ Domain state**: Exclusive. A package is either in `packages.yaml` OR in a domain-specific `.sls` file, never both.

## Entity: Drift Report (output of `scripts/pkg-drift.zsh`)

### Structure (stdout, human-readable)

```text
=== Package Drift Report (2026-03-09) ===

UNMANAGED (installed but not declared):
  - some-random-tool
  - another-pkg

MISSING (declared but not installed):
  - declared-pkg-that-was-removed

ORPHANS (dependency-only, no dependents):
  - lib-nobody-needs
  - old-dep-from-removed-pkg

Summary: 2 unmanaged, 1 missing, 2 orphans
```

### Field Semantics

| Field | Type | Description |
|-------|------|-------------|
| Unmanaged | `list[string]` | Packages in `pacman -Qqe` but not in `packages.yaml` and not in any `.sls` file. |
| Missing | `list[string]` | Packages in `packages.yaml` or `.sls` files but not in `pacman -Qq`. |
| Orphans | `list[string]` | Output of `pacman -Qdtq` — dependency-only packages with no remaining dependents. |

## Entity: Reduction Candidates (output of `scripts/pkg-snapshot.zsh --reduce`)

### Structure (stdout, human-readable)

```text
=== Reduction Candidates ===
The following explicitly-installed packages are already transitive
dependencies of other explicit packages and could be removed from
the explicit list (they would still be installed as dependencies):

  gtk4          (dependency of: firefox, nautilus)
  glib2         (dependency of: gtk4, systemd)
  libx11        (dependency of: xorg-server)

Review each candidate before removing. Some packages may be
intentionally explicit (e.g., you want gtk4 even if firefox is removed).

Total: 3 candidates out of 547 explicit packages
```
