# Research: Domain Package Separation

**Feature**: 055-domain-pkg-separation
**Date**: 2026-03-20

## Migration Inventory

### Packages to Relocate by Category

#### `audio` → `audio.sls` (1 package)

| Package | Description | Destination | Notes |
|---------|-------------|-------------|-------|
| `pipewire` | low-latency audio/video router | `audio.sls` inline list | `audio.sls` already installs 7 pipewire modules; `pipewire` base is the missing root |

**Decision**: Add `pipewire` to the existing inline `{% for pkg in [...] %}` loop in `audio.sls`.
**Rationale**: Keeps all PipeWire stack packages together. `audio.sls` already manages wireplumber, pipewire-pulse, etc.
**Alternative rejected**: Creating `data/audio.yaml` — overkill for 8 packages with no complex metadata.

#### `fonts` → `fonts.sls` (1 package)

| Package | Description | Destination | Notes |
|---------|-------------|-------------|-------|
| `noto-fonts-cjk` | Google Noto CJK fonts | `data/fonts.yaml` → `pacman` list | `fonts.yaml` already has a `pacman:` list with 10 font packages |

**Decision**: Add `noto-fonts-cjk` to the `pacman:` list in `data/fonts.yaml`.
**Rationale**: `fonts.sls` is data-driven; all pacman fonts belong in the data file.
**Alternative rejected**: Inline in `fonts.sls` — breaks the established data-driven pattern.

#### `gaming` → no change (0 packages)

Category is already empty. Only the key itself needs removal from `packages.yaml` and the category loop.

**Decision**: Delete the empty `gaming:` key from `packages.yaml` and remove `'gaming'` from the `packages.sls` loop.
**Rationale**: Dead code removal.

#### `desktop` → `desktop.sls` / `data/desktop.yaml` (19 packages)

| Package | Description | Destination | Notes |
|---------|-------------|-------------|-------|
| `broot` | tree-based file manager | `data/desktop.yaml` | General desktop tool |
| `dunst` | lightweight notification daemon | `data/desktop.yaml` | Hyprland notification stack |
| `eza` | modern ls replacement | Keep in `packages.yaml:other` | CLI tool, not desktop-specific |
| `hypridle` | Hyprland idle daemon | `data/desktop.yaml` | Already has `hyprland_packages` list |
| `hyprland` | dynamic tiling Wayland compositor | `data/desktop.yaml` | Core of desktop stack |
| `hyprlock` | GPU-accelerated screen locker | `data/desktop.yaml` | Hyprland component |
| `hyprpolkitagent` | polkit agent for Hyprland | `data/desktop.yaml` | Hyprland component |
| `loupe` | GNOME image viewer | `data/desktop.yaml` | Desktop app |
| `matugen` | Material You color generation | `data/desktop.yaml` | Theme tool |
| `nyxt` | keyboard-driven web browser | `data/desktop.yaml` | Desktop app |
| `rmpc` | Rusty MPD Player Client | Move to `other` or keep in desktop | MPD client, but desktop UI app |
| `rofi` | app launcher | `data/desktop.yaml` | Core desktop launcher |
| `swayimg` | Wayland image viewer | `data/desktop.yaml` | Desktop app |
| `swayosd` | on-screen display | `data/desktop.yaml` | Desktop UI component |
| `television` | terminal fuzzy finder | Keep in `packages.yaml:other` | CLI tool, not desktop-specific |
| `wl-clip-persist` | clipboard manager | `data/desktop.yaml` | Wayland desktop tool |
| `xdg-desktop-portal-gtk` | portal backend | `data/desktop.yaml` | Desktop infrastructure |
| `xdg-desktop-portal-hyprland` | portal backend | `data/desktop.yaml` | Hyprland component |
| `yazi` | terminal file manager | Keep in `packages.yaml:other` | CLI tool, not desktop-specific |

**Decision**: Move 16 packages to `data/desktop.yaml` (new `packages:` list). Keep `eza`, `television`, `yazi` in `packages.yaml:other` (they're CLI tools usable without a desktop).
**Rationale**: `desktop.yaml` already exists with `hyprland_packages` and `screenshot_packages`. Adding a general `packages` list keeps all desktop-managed packages in one data file.
**Alternative rejected**: Adding all 19 to `desktop.yaml` — `eza`/`television`/`yazi` are terminal tools that work headless.

### `other`/`aur` Audit: Domain-Specific Packages

#### Audio-related in `other`/`aur`

| Package | Category | Description | Recommendation |
|---------|----------|-------------|----------------|
| `carla` | other | audio plugin host | Keep in `other` — optional pro-audio tool, not part of core audio stack |
| `cava` | other | console audio visualizer | Keep in `other` — terminal visualization tool |
| `lsp-plugins` | other | audio DSP plugin collection | Keep in `other` — optional pro-audio |
| `sonic-visualiser` | other | music audio analyzer | Keep in `other` — specialized analysis tool |
| `sox` | other | sound processing Swiss Army knife | Keep in `other` — general CLI utility |
| `brutefir` | aur | multi-channel FIR convolution engine | Keep in `aur` — specialized DSP tool |
| `pipemixer` | aur | TUI PipeWire volume control | Keep in `aur` — optional convenience tool |
| `raysession` | aur | NSM session manager for audio apps | Keep in `aur` — optional pro-audio |

**Decision**: Keep all audio-related packages in `other`/`aur`. They are optional pro-audio tools not gated by any feature flag.
**Rationale**: Moving these to `audio.sls` would require adding them to the audio feature scope. The core audio stack (pipewire + modules) is well-defined; these are extras.

#### Font-related in `aur`

| Package | Category | Description | Recommendation |
|---------|----------|-------------|----------------|
| `iosevka-neg-fonts` | aur | custom Iosevka build | Already managed by `fonts.sls` PKGBUILD — remove from `aur` if duplicate |
| `ttfautohint` | aur | font hinting tool | Keep in `aur` — build dependency, not a font itself |

**Decision**: Verify `iosevka-neg-fonts` isn't double-declared. Keep `ttfautohint` in `aur`.
**Rationale**: `fonts.sls` builds iosevka-neg-fonts via custom PKGBUILD. If it also appears in `packages.yaml:aur`, that's an overlap violation to fix.

## Key Design Decisions

### D1: How `desktop.sls` Consumes Relocated Packages

**Decision**: Add a `packages:` top-level key to `data/desktop.yaml` with the 16 relocated packages. `desktop.sls` will iterate this list with `pacman_install`.

**Rationale**: Follows the data-driven pattern already established by `hyprland_packages` and `screenshot_packages` in the same file. The existing `desktop.sls` already imports `desktop.yaml`.

### D2: No New Data Files

**Decision**: No `data/audio.yaml` or `data/gaming.yaml` created. Audio packages stay inline in `audio.sls`. Gaming category is empty (removed).

**Rationale**: Constitution V (Minimal Change) — don't create abstractions for 8 packages with no complex metadata. `fonts.yaml` exists because fonts have structured metadata (URLs, subdirs, build configs).

### D3: Lint Script Design

**Decision**: New `scripts/lint-pkg-overlap.py` that parses `packages.yaml` and all domain data files (`fonts.yaml`, `desktop.yaml`) plus inline package lists in `.sls` files to detect overlaps.

**Rationale**: Constitution VI (Convention Adherence) — follows the established `scripts/lint-*.py` pattern. FR-009 requires automated overlap detection.

### D4: `pkg-snapshot.zsh` Update

**Decision**: Update `scripts/pkg-snapshot.zsh` to parse `data/desktop.yaml` for domain-managed packages (it already parses `data/fonts.yaml`).

**Rationale**: Without this, `pkg-snapshot` would incorrectly categorize desktop packages as "unmanaged" after migration.
