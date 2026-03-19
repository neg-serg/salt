# Quickstart: Domain Package Separation

**Feature**: 055-domain-pkg-separation
**Date**: 2026-03-20

## Implementation Order

The migration has a natural dependency chain. Follow this order:

### Step 1: Remove Domain Categories from `packages.yaml`

Delete the `audio:`, `fonts:`, `gaming:`, and `desktop:` top-level keys from `states/data/packages.yaml`. Move `eza`, `television`, `yazi` from the deleted `desktop:` category to `other:` (they're CLI tools, not desktop-specific).

**Verify**: `just validate` — Salt should still render. The packages loop in `packages.sls` skips empty/missing categories via `{% if pkg_list %}`.

### Step 2: Update `packages.sls` Category Loop

Remove `'audio'`, `'fonts'`, `'gaming'`, `'desktop'` from the category list on line 13 of `states/packages.sls`.

**Verify**: `just validate` — no change in behavior since those categories are now absent from the YAML.

### Step 3: Add Packages to Domain States

1. **audio.sls**: Add `pipewire` to the inline package loop (currently has `pipewire-audio`, `wireplumber`, etc.)
2. **fonts.yaml**: Add `noto-fonts-cjk` to the `pacman:` list in `states/data/fonts.yaml`
3. **desktop.yaml**: Add new `packages:` key with the 16 relocated desktop packages
4. **desktop.sls**: Add a `pacman_install` call that consumes `desktop.packages` from the data file

**Verify**: `just validate` — all states render. `just apply` — all packages still installed.

### Step 4: Update `pkg-snapshot.zsh`

Add `desktop.yaml` to the list of domain data files parsed in `scripts/pkg-snapshot.zsh` (line ~147).

### Step 5: Add Lint Script

Create `scripts/lint-pkg-overlap.py` that:
1. Parses all packages from `packages.yaml` (all categories)
2. Parses domain packages from `fonts.yaml`, `desktop.yaml`
3. Extracts inline packages from `audio.sls`, `steam.sls`
4. Reports any package appearing in both sets

Add to `just lint` recipe.

### Step 6: Verify `iosevka-neg-fonts` Overlap

Check if `iosevka-neg-fonts` appears in both `packages.yaml:aur` and `fonts.sls` PKGBUILD. If so, remove from `packages.yaml:aur`.

### Step 7: Final Verification

```bash
just validate     # All states render cleanly
just lint         # New overlap lint passes
just apply        # Full apply with no regressions
```

## Key Files to Modify

| File | Action |
|------|--------|
| `states/data/packages.yaml` | Remove 4 categories, move 3 CLI tools to `other` |
| `states/packages.sls` | Update category loop (remove 4 entries) |
| `states/audio.sls` | Add `pipewire` to inline list |
| `states/data/fonts.yaml` | Add `noto-fonts-cjk` to `pacman:` |
| `states/data/desktop.yaml` | Add `packages:` key with 16 packages |
| `states/desktop.sls` | Add `pacman_install` for `desktop.packages` |
| `scripts/lint-pkg-overlap.py` | New lint script |
| `scripts/pkg-snapshot.zsh` | Add `desktop.yaml` to parsed files |
| `Justfile` | Add lint-pkg-overlap to `lint` recipe |

## Risk Mitigations

- **Package regression**: `just apply` will fail if any previously-installed package is missing. Run on test host first.
- **State ID conflicts**: Verify no `pkg_desktop` / `pkg_audio` state ID is referenced by `require` in other states before removing from `packages.sls`.
- **Rollback**: `just rollback` reverts the last snapper snapshot pair if apply breaks.
