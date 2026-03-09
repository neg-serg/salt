# Research: Gaming Performance Optimization

**Branch**: `010-gaming-performance` | **Date**: 2026-03-09

## Decision 1: GameMode Configuration Scope

**Decision**: Deploy a Salt-managed `gamemode.ini` to `/etc/gamemode.ini` (system-wide) with AMD-specific CPU, GPU, and I/O optimizations.

**Rationale**: GameMode is already installed via `steam.sls` but runs with defaults — no `gamemode.ini` exists anywhere in the repo or system config. The default GameMode config only changes CPU governor; it doesn't touch GPU power profiles, I/O priority, or process niceness. A custom config is needed to fulfill FR-001, FR-002, FR-004, and FR-006.

**Alternatives considered**:
- Per-user `~/.config/gamemode.ini` — unnecessary since there's only one gaming user; system-wide is simpler and owned by Salt
- No config (defaults only) — insufficient; defaults don't set GPU power profile or custom scripts
- Wrapper script instead of GameMode — rejected; the existing `game-run`/`game-affinity-exec` scripts already wrap GameMode, so configuring GameMode itself is the correct layer

## Decision 2: Environment Variable Placement (Hybrid Scope)

**Decision**: Create a new `environment.d/20-gaming.conf` for globally-safe variables (DXVK_*, WINE_*, mesa_glthread, shader cache). Game-scoped variables (RADV_PERFTEST) go in `gamemode.ini` start/end scripts.

**Rationale**: Per the clarification session, hybrid scope was chosen. `environment.d` files are the canonical source for session-wide variables in this project (existing `10-user.conf`). The `20-` prefix ensures gaming vars load after user vars. RADV_PERFTEST flags affect the Hyprland compositor's Vulkan rendering, so they must be scoped to game processes only via GameMode's `start` script mechanism.

**Alternatives considered**:
- All in environment.d — rejected; RADV_PERFTEST would affect compositor
- All in GameMode — rejected; DXVK_* vars need to be available for non-GameMode launches too (e.g., Wine apps)
- Shell profile — rejected; environment.d is the established pattern in this project

## Decision 3: MangoHud Configuration

**Decision**: Deploy `mangohud.conf` via chezmoi at `~/.config/MangoHud/MangoHud.conf` with toggle keybind and comprehensive metrics layout.

**Rationale**: MangoHud is installed but has no config. Per clarification, overlay should be hidden by default with keybind toggle. MangoHud reads `~/.config/MangoHud/MangoHud.conf` automatically — no environment variable needed. This is a pure user dotfile with no secrets or service triggers, so chezmoi ownership is correct per the file ownership convention.

**Alternatives considered**:
- Salt-managed config — unnecessary; no secrets, no service triggers, no conditional deployment
- GOverlay GUI configuration — rejected; not declarative, not reproducible
- No config (MANGOHUD_CONFIG env var) — rejected; less maintainable than a config file

## Decision 4: Kernel/Sysctl Tuning Delta

**Decision**: Minimal additions to existing sysctl config. Most gaming-relevant kernel params are already present.

**Rationale**: Research revealed the system already has:
- `split_lock_detect=off` (prevents game stuttering from split lock #AC exceptions)
- `nowatchdog` + `kernel.nmi_watchdog=0` (removes NMI overhead)
- `amdgpu.ppfeaturemask=0xffffffff` (all GPU power features unlocked)
- `pcie_aspm=performance` (no PCIe power saving latency)
- `idle=nomwait` (lower idle-to-active latency)
- `amd_pstate=active` (active CPU frequency management)
- `vm.max_map_count=16777216` (sufficient for all games)
- `vm.swappiness=10` (minimal swapping)
- NVMe scheduler=none, SATA=mq-deadline (via udev)

**Remaining additions** (not yet present):
- `vm.compaction_proactiveness=0` — disable proactive memory compaction (reduces latency spikes)
- `kernel.sched_cfs_bandwidth_slice_us=3000` — finer CFS bandwidth slicing for gaming threads (CachyOS default is higher)

**Alternatives considered**:
- Aggressive sysctl changes (disable ASLR, reduce security) — rejected; security kernel params should stay
- Custom kernel — rejected; CachyOS kernel is already optimized with BORE/EEVDF

## Decision 5: GPU Power Profile Management

**Decision**: GameMode handles GPU power profile switching via its built-in `gpu_optimise` feature plus custom start/end scripts for AMD-specific DPM settings.

**Rationale**: GameMode natively supports `igpu_desiredprofile` and `igpu_power_profile` settings for AMD GPUs. Combined with `amdgpu.ppfeaturemask=0xffffffff` (already in kernel params), GameMode can switch between power-save and performance DPM profiles dynamically. This fulfills FR-004 and FR-006 (automatic revert on game exit).

**Alternatives considered**:
- Static high-performance GPU profile — rejected; wastes power when not gaming
- Udev rule for GPU — rejected; udev can't detect "game is running"
- Custom systemd service — rejected; GameMode already provides this mechanism

## Decision 6: State File Organization

**Decision**: Extend existing `steam.sls` with GameMode and MangoHud configuration. Add gaming env vars as chezmoi dotfile. No new `.sls` file needed.

**Rationale**: Per constitution principle IV (Macro-First) and development workflow rule 4, new functionality goes into the appropriate domain file. `steam.sls` already owns the gaming domain — it installs GameMode, MangoHud, and gamescope. Adding their configuration here is natural. The environment.d file is a chezmoi dotfile (pure user config, no secrets/triggers).

**Alternatives considered**:
- New `gaming.sls` — rejected; would split the gaming domain across two files unnecessarily
- Everything in chezmoi — rejected; gamemode.ini at `/etc/gamemode.ini` requires root deployment (Salt)
