# Research: Salt Package Management

## Decision 1: Analysis tool approach — `pacman -Qqe` baseline + reduction pass

**Decision**: Two-phase approach. Phase 1 captures `pacman -Qqe` verbatim, categorizes packages, and excludes those already managed by Salt states. Phase 2 (optional) runs `pactree -r` on each explicit package to find those that are transitive dependencies of other explicit packages, presenting them as reduction candidates.

**Rationale**: `pacman -Qqe` is the authoritative source of explicitly-installed packages. It's fast, reliable, and well-understood. The reduction pass uses `pactree` (from pacman-contrib) which correctly resolves the dependency DAG. Human review before reduction prevents accidental removal of packages the user intentionally installed (e.g., both `firefox` and `gtk4` might be explicit because the user wants `gtk4` even if `firefox` is removed later).

**Alternatives considered**:
- `pacman -Qqet` (explicitly installed, unrequired) — shows only "leaf" packages, which is the inverse of what we need. It misses packages like `base` that are required by nothing but essential.
- Pure dependency graph computation — too complex for marginal benefit. `pactree` already does the heavy lifting.
- `pkgutil`/custom dependency solver — reinventing the wheel; pacman's own tools are canonical.

## Decision 2: Categorization strategy

**Decision**: The analysis script auto-categorizes packages by cross-referencing pacman package groups (`pacman -Qg`) and repository origin (`pacman -Si <pkg> | grep Repository`). Categories map to functional domains: `base` (base, base-devel), `desktop` (hyprland ecosystem, wayland), `audio` (pipewire, alsa), `dev` (compilers, debuggers, languages), `network` (VPN, DNS, firewall), `fonts`, `gaming` (steam, vulkan, wine), `media` (codecs, players), `system` (filesystem, boot, monitoring), `aur` (all AUR packages in one section). Uncategorized packages go to `other`.

**Rationale**: Automatic categorization from pacman metadata avoids manual effort for the initial ~500+ packages. The categories align with existing Salt state module domains (audio.sls, desktop.sls, steam.sls, fonts.sls, etc.), making it natural to reason about ownership.

**Alternatives considered**:
- Manual categorization — impractical for 500+ packages on first run.
- Per-state-file categorization — too granular; many packages don't belong to any specific state.
- Flat list (no categories) — works but hurts maintainability and readability.

## Decision 3: Cross-referencing existing Salt states

**Decision**: The analysis script parses existing `.sls` files to extract package names from `pacman_install` and `paru_install` macro calls using simple regex/grep patterns. Matched packages are excluded from `packages.yaml` and listed in a separate report section for verification.

**Rationale**: Regex parsing of Jinja macro calls (`pacman_install('name', 'pkg1 pkg2 pkg3')`) is sufficient — the macro invocations follow a consistent pattern. Full Jinja rendering is unnecessary and would require a Salt execution context.

**Alternatives considered**:
- Full Jinja rendering via `salt-call` — too heavy, requires running Salt just for analysis.
- Manual exclusion list — error-prone, would drift as states evolve.
- Moving all packages to the central file — rejected in clarification (coexistence model chosen).

## Decision 4: Salt state design — bulk vs per-package

**Decision**: Use one `pacman_install` call per category (bulk pattern) for official packages, and one `paru_install` call per package for AUR packages (the macro only supports single packages). The `check` parameter for bulk `pacman_install` calls will use the last package in the list as the sentinel.

**Rationale**: Bulk `pacman_install` is more efficient — one `pacman -S` invocation per category vs hundreds of individual calls. The sentinel-based idempotency guard is sufficient because `pacman --needed` is inherently idempotent. AUR packages must be individual because `paru_install` wraps `paru -S` for one package at a time.

**Alternatives considered**:
- Per-package `pacman_install` loop — generates hundreds of Salt states, slower to render and apply.
- New macro for bulk AUR — `paru` can technically install multiple packages, but the existing macro doesn't support it and Principle V (Minimal Change) advises against modifying macros for this.
- Single monolithic `pacman_install` for all official packages — loses category granularity.

## Decision 5: Drift detection approach

**Decision**: A standalone zsh script (`scripts/pkg-drift.zsh`) that compares `pacman -Qqe` output against the union of: (a) packages in `states/data/packages.yaml`, and (b) packages extracted from domain-specific `.sls` files. Reports three categories: `unmanaged` (installed but not declared), `missing` (declared but not installed), `orphans` (dependency-only packages with no dependents, via `pacman -Qdtq`).

**Rationale**: A script (not a Salt state) because drift detection is a read-only diagnostic — it should never modify system state. Running it via `just pkg-drift` or manually keeps it separate from the apply lifecycle.

**Alternatives considered**:
- Salt custom execution module — over-engineered for a read-only comparison.
- Integration into `salt-call state.apply` — would slow every apply with unnecessary comparison logic.
- systemd timer for periodic checks — deferred to P3 (drift detection is Priority P3 in the spec).
