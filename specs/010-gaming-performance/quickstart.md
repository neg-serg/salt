# Quickstart: Gaming Performance Optimization

**Branch**: `010-gaming-performance` | **Date**: 2026-03-09

## What This Feature Does

Configures GameMode, MangoHud, and gaming environment variables so that launching a game automatically optimizes CPU governor, GPU power profile, I/O priority, and rendering settings. All changes revert when the game exits.

## Files to Create/Modify

### New Files

| File | Location | Owner |
|------|----------|-------|
| `gamemode.ini` | `states/configs/gamemode.ini` → `/etc/gamemode.ini` | Salt |
| `gamemode-start.sh` | `states/scripts/gamemode-start.sh` → `/usr/local/bin/gamemode-start.sh` | Salt |
| `gamemode-end.sh` | `states/scripts/gamemode-end.sh` → `/usr/local/bin/gamemode-end.sh` | Salt |
| `MangoHud.conf` | `dotfiles/dot_config/MangoHud/MangoHud.conf` | Chezmoi |
| `20-gaming.conf` | `dotfiles/dot_config/environment.d/20-gaming.conf` | Chezmoi |

### Modified Files

| File | Change |
|------|--------|
| `states/steam.sls` | Add gamemode.ini and start/end script deployment |
| `states/configs/sysctl-custom.conf` | Append 2 gaming sysctl parameters |

## Implementation Order

1. **Sysctl additions** — append `vm.compaction_proactiveness=0` and `kernel.sched_cfs_bandwidth_slice_us=3000` to existing sysctl config
2. **GameMode config + scripts** — create `gamemode.ini`, `gamemode-start.sh`, `gamemode-end.sh` in `states/configs/` and `states/scripts/`
3. **Salt states** — add `file.managed` states to `steam.sls` for deploying gamemode config and scripts
4. **Environment variables** — create `20-gaming.conf` in chezmoi dotfiles
5. **MangoHud config** — create `MangoHud.conf` in chezmoi dotfiles
6. **Verify** — run `just` to confirm Salt renders cleanly

## Verification

```bash
# After salt apply:
gamemoded -t              # Test GameMode config validity
cat /etc/gamemode.ini     # Verify config deployed
cat /etc/sysctl.d/99-custom.conf | grep compaction  # Verify sysctl additions

# After chezmoi apply:
cat ~/.config/MangoHud/MangoHud.conf     # Verify MangoHud config
cat ~/.config/environment.d/20-gaming.conf  # Verify gaming env vars

# Runtime test:
gamemoderun glxgears &    # Start a "game"
gamemoded -s              # Check GameMode status (should show active)
kill %1                   # Stop "game"
gamemoded -s              # Should show inactive
```

## Key Decisions

- **GameMode owns GPU switching**: uses built-in `apply_gpu_optimisations` + custom start/end scripts for RADV_PERFTEST
- **Hybrid env var scope**: DXVK_*/WINE_*/mesa_* global in environment.d; RADV_PERFTEST scoped via GameMode scripts
- **MangoHud hidden by default**: toggled via Shift_R+F12
- **Minimal kernel changes**: most gaming params already present; only 2 sysctl additions needed
