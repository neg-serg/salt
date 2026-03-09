# Data Model: Gaming Performance Optimization

**Branch**: `010-gaming-performance` | **Date**: 2026-03-09

## Entities

### GameMode Configuration (`/etc/gamemode.ini`)

System-wide INI file controlling GameMode behavior when a game is detected.

| Section | Key | Value | Purpose |
|---------|-----|-------|---------|
| `general` | `reaper_freq` | `5` | How often (seconds) to check if games are still running |
| `general` | `defaultgov` | `powersave` | Governor to restore after gaming |
| `general` | `desiredgov` | `performance` | Governor to set during gaming |
| `general` | `inhibit_screensaver` | `1` | Prevent screensaver during gaming |
| `general` | `softrealtime` | `auto` | Enable soft realtime scheduling for game processes |
| `general` | `renice` | `10` | Renice game processes (lower value = higher priority) |
| `general` | `ioprio` | `0` | I/O priority class (0 = realtime) |
| `gpu` | `apply_gpu_optimisations` | `accept-responsibility` | Enable GPU power profile switching |
| `gpu` | `gpu_device` | `0` | GPU device index |
| `gpu` | `amd_performance_level` | `high` | AMD DPM performance level during gaming |
| `custom` | `start` | Script path | Script to run when gaming starts (sets RADV_PERFTEST, etc.) |
| `custom` | `end` | Script path | Script to run when gaming ends (reverts settings) |

**Lifecycle**: Deployed once by Salt → read by GameMode daemon on each game start/stop event.

### Environment Profile (`environment.d/20-gaming.conf`)

Session-wide environment variables for game-specific software.

| Variable | Value | Scope | Purpose |
|----------|-------|-------|---------|
| `DXVK_ASYNC` | `1` | Global (DXVK-only) | Async shader compilation |
| `DXVK_STATE_CACHE` | `1` | Global (DXVK-only) | Enable state cache |
| `WINE_FULLSCREEN_FSR` | `1` | Global (Wine-only) | Enable AMD FSR upscaling |
| `WINE_FULLSCREEN_FSR_STRENGTH` | `2` | Global (Wine-only) | FSR sharpening (0=max, 5=min) |
| `mesa_glthread` | `true` | Global (Mesa) | Threaded OpenGL dispatch |
| `MESA_SHADER_CACHE_MAX_SIZE` | `10G` | Global (Mesa) | Shader cache size limit |
| `MANGOHUD` | `0` | Global (MangoHud) | Disabled by default (toggled in-game) |

### MangoHud Configuration (`~/.config/MangoHud/MangoHud.conf`)

User dotfile controlling HUD overlay appearance and metrics.

| Key | Value | Purpose |
|-----|-------|---------|
| `no_display` | `1` | Hidden by default |
| `toggle_hud` | `Shift_R+F12` | Keybind to show/hide overlay |
| `toggle_fps_limit` | `Shift_R+F11` | Keybind to cycle FPS limits |
| `fps` | (enabled) | Show FPS counter |
| `frametime` | (enabled) | Show frame time graph |
| `cpu_stats` | (enabled) | Show CPU utilization |
| `gpu_stats` | (enabled) | Show GPU utilization |
| `cpu_temp` | (enabled) | Show CPU temperature |
| `gpu_temp` | (enabled) | Show GPU temperature |
| `gpu_power` | (enabled) | Show GPU power draw |
| `ram` | (enabled) | Show RAM usage |
| `vram` | (enabled) | Show VRAM usage |
| `vulkan_driver` | (enabled) | Show Vulkan driver info |
| `wine` | (enabled) | Show Wine/Proton version |
| `gamemode` | (enabled) | Show GameMode status |

**Lifecycle**: Deployed by chezmoi → read by MangoHud when injected into a game process.

### Sysctl Additions (`sysctl-custom.conf` — append)

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `vm.compaction_proactiveness` | `0` | Disable proactive compaction (reduces latency spikes) |
| `kernel.sched_cfs_bandwidth_slice_us` | `3000` | Finer CFS bandwidth slicing |

**Lifecycle**: Appended to existing `/etc/sysctl.d/99-custom.conf` → applied via `sysctl --system` on change.

## Relationships

```
steam.sls
├── installs: gamemode, mangohud, gamescope, steam, ...
├── deploys: /etc/gamemode.ini (NEW)
│   ├── references: /usr/local/bin/gamemode-start.sh (NEW, custom start script)
│   └── references: /usr/local/bin/gamemode-end.sh (NEW, custom end script)
└── existing: dxvk-resolution-fix, modern-steam-skin, steam-library-dir

chezmoi (dotfiles/)
├── deploys: ~/.config/MangoHud/MangoHud.conf (NEW)
└── deploys: ~/.config/environment.d/20-gaming.conf (NEW)

sysctl.sls
└── extends: /etc/sysctl.d/99-custom.conf (APPEND 2 parameters)
```

## File Ownership Determination

| File | Owner | Reason |
|------|-------|--------|
| `/etc/gamemode.ini` | Salt | System path, requires root |
| `/usr/local/bin/gamemode-start.sh` | Salt | System path, requires root |
| `/usr/local/bin/gamemode-end.sh` | Salt | System path, requires root |
| `~/.config/MangoHud/MangoHud.conf` | Chezmoi | Pure user dotfile, no secrets/triggers |
| `~/.config/environment.d/20-gaming.conf` | Chezmoi | Pure user dotfile, extends existing pattern |
| `/etc/sysctl.d/99-custom.conf` | Salt | Already Salt-managed, system path |
