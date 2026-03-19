# Data Model: Domain Package Separation

**Feature**: 055-domain-pkg-separation
**Date**: 2026-03-20

## Package Ownership Model

### Entity: Package Declaration

A package declaration is a single entry that assigns a package to exactly one owner.

**Attributes**:
- `name`: Package name (e.g., `pipewire`, `hyprland`)
- `description`: Inline YAML comment describing the package
- `owner`: Either `packages.yaml` (infrastructure) or a domain state (e.g., `audio.sls`, `desktop.sls`)
- `install_method`: `pacman` (via `pacman_install` macro) or `paru` (via `paru_install` macro)

**Constraint**: A package name MUST appear in exactly one owner. Zero appearances = orphan. Two+ appearances = overlap violation.

### Entity: Package Category

A grouping of packages within `packages.yaml`.

**Before migration** (11 categories):
```
base, desktop, dev, network, audio, media, fonts, gaming, system, other, aur
```

**After migration** (7 categories):
```
base, dev, network, media, system, other, aur
```

**Removed categories**: `audio`, `fonts`, `gaming`, `desktop`

### Entity: Domain State

A Salt state file that owns a feature domain end-to-end.

| Domain State | Data File | Package Source |
|-------------|-----------|----------------|
| `audio.sls` | (inline) | Inline Jinja list in `.sls` |
| `fonts.sls` | `data/fonts.yaml` | `pacman:` and `paru:` lists in YAML |
| `desktop.sls` | `data/desktop.yaml` | `packages:` list in YAML (new) |
| `steam.sls` | (inline) | Inline `cmd.run` in `.sls` |

## State Transitions

### Migration Flow per Package

```
packages.yaml:category → (removed from YAML) → domain_state or domain_data_file
```

### Validation Flow

```
lint-pkg-overlap.py runs →
  parse packages.yaml (all categories) →
  parse domain data files (fonts.yaml, desktop.yaml) →
  parse domain .sls files (audio.sls, steam.sls) for inline packages →
  compute intersection →
  if intersection is non-empty: EXIT 1 (overlap violation)
  if all clear: EXIT 0
```

## Data File Changes

### `states/data/packages.yaml`

**Remove**: `audio:`, `fonts:`, `gaming:`, `desktop:` top-level keys.
**Add to `other:`**: `eza`, `television`, `yazi` (CLI tools relocated from `desktop`).

### `states/data/desktop.yaml`

**Add** new `packages:` key:
```yaml
packages:
  - broot           # tree-based file manager
  - dunst           # lightweight notification daemon
  - hypridle        # Hyprland idle daemon
  - hyprland        # dynamic tiling Wayland compositor
  - hyprlock        # GPU-accelerated screen locker
  - hyprpolkitagent # polkit agent for Hyprland
  - loupe           # GNOME image viewer
  - matugen         # Material You color generation
  - nyxt            # keyboard-driven web browser
  - rmpc            # Rusty MPD Player Client
  - rofi            # app launcher
  - swayimg         # Wayland image viewer
  - swayosd         # on-screen display
  - wl-clip-persist # clipboard manager
  - xdg-desktop-portal-gtk      # portal backend
  - xdg-desktop-portal-hyprland # portal backend
```

### `states/data/fonts.yaml`

**Add** to `pacman:` list:
```yaml
  - noto-fonts-cjk  # Google Noto CJK fonts
```

### `states/audio.sls`

**Add** `pipewire` to the existing inline package loop.
