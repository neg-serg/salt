# Feature Specification: Gaming Performance Optimization

**Feature Branch**: `010-gaming-performance`
**Created**: 2026-03-09
**Status**: Draft
**Input**: User description: "хочу улучшить игровую производительность"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Automatic Performance Mode During Gaming (Priority: P1)

When the user launches a game through Steam or directly, the system automatically switches to a high-performance profile — CPU governor, GPU power state, and process scheduling all optimized for gaming without manual intervention.

**Why this priority**: This delivers the largest framerate and latency improvement with zero ongoing user effort. GameMode already exists in the package list but needs proper integration with system-level tuning.

**Independent Test**: Launch a Steam game, verify CPU governor switches to `performance`, GPU power profile changes to high-performance 3D mode, and the game process receives elevated scheduling priority. Confirm settings revert after game exit.

**Acceptance Scenarios**:

1. **Given** a game is not running, **When** a Steam game is launched, **Then** the system applies gaming performance profile (CPU governor, GPU power, I/O priority) within 2 seconds of game start
2. **Given** a game is running with performance profile active, **When** the game exits, **Then** the system reverts to default power-saving profile within 5 seconds
3. **Given** GameMode is configured, **When** the user checks GameMode status, **Then** all registered optimizations show as active during gameplay

---

### User Story 2 - Proton/DXVK Environment Optimization (Priority: P2)

Games running through Proton/Wine benefit from pre-configured environment variables that enable asynchronous shader compilation, AMD FidelityFX Super Resolution (FSR), and optimal DXVK settings for the user's display resolution and hardware.

**Why this priority**: Many Proton games suffer from shader stutter and suboptimal rendering defaults. Proper environment variables eliminate the most common Proton performance complaints.

**Independent Test**: Launch a Proton game, verify environment variables for async shader compilation, FSR, and AMD-specific flags are present in the game process environment. Measure shader compilation stutter before and after.

**Acceptance Scenarios**:

1. **Given** the system is configured, **When** a Proton game launches, **Then** DXVK async shader compilation is enabled, reducing shader stutter
2. **Given** the user's display is 3840x2160, **When** FSR is enabled, **Then** games can render at lower internal resolution and upscale to native, improving frame rates
3. **Given** AMD RADV Vulkan driver is in use, **When** a game launches, **Then** AMD-specific performance flags are active

---

### User Story 3 - Kernel and System-Level Latency Reduction (Priority: P3)

System-wide kernel parameters and scheduler settings are tuned to reduce input latency and frame timing variance, providing smoother gameplay especially in competitive or fast-paced games.

**Why this priority**: CachyOS already ships with an optimized scheduler and high timer frequency, but additional kernel parameters and sysctl tuning can further reduce latency for the specific hardware profile.

**Independent Test**: Measure frame time consistency and input latency (via mangohud overlay) in a demanding game before and after applying kernel tuning. Frame time variance should decrease.

**Acceptance Scenarios**:

1. **Given** kernel parameters are applied, **When** playing a game, **Then** frame time variance is reduced compared to default configuration
2. **Given** the system is freshly booted, **When** kernel parameters are checked, **Then** all gaming-related tunables are at their optimized values
3. **Given** gaming optimizations are applied, **When** the system is used for non-gaming tasks, **Then** there is no noticeable negative impact on desktop responsiveness

---

### User Story 4 - GPU Power and Display Optimization (Priority: P3)

The AMD GPU operates at optimal power and clock states during gaming, with display-specific settings (variable refresh rate, tearfree compositing bypass) properly configured for the user's monitor.

**Why this priority**: GPU power management defaults to balanced mode which throttles clocks unnecessarily. Proper power profile and display settings maximize GPU utilization during gaming.

**Independent Test**: During gameplay, verify GPU power profile is set to high-performance, clock speeds reach expected maximums, and display VRR is active.

**Acceptance Scenarios**:

1. **Given** a game is running, **When** the GPU power profile is checked, **Then** it shows high-performance mode
2. **Given** VRR-capable display is connected, **When** a fullscreen game is running, **Then** variable refresh rate is active

---

### Edge Cases

- What happens when multiple games are launched simultaneously? Performance profile should remain active until the last game exits.
- How does the system handle games launched outside Steam (e.g., native Linux games, emulators)? Users launch them via `gamemoderun ./game` to activate all gaming optimizations including game-scoped environment variables.
- What if the GPU doesn't support the configured power profile? Graceful fallback with no errors in journal.
- What happens during a game crash? Performance profile must still revert to defaults (timeout-based fallback).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST automatically apply high-performance CPU governor when a game is detected as running
- **FR-002**: System MUST configure GameMode with CPU, GPU, and I/O optimizations specific to the user's AMD hardware
- **FR-003**: System MUST set Proton/DXVK environment variables using a hybrid scope: variables only consumed by game-specific software (DXVK_*, WINE_*, mesa_glthread, shader cache paths) are set globally; variables that affect all Vulkan applications (RADV_PERFTEST, GPU-specific Mesa flags) are scoped to game processes only via GameMode
- **FR-004**: System MUST configure AMD GPU power management profiles that activate during gaming
- **FR-005**: System MUST apply kernel parameters that reduce input latency and frame timing variance
- **FR-006**: System MUST revert all dynamic performance changes when gaming session ends
- **FR-007**: System MUST not degrade desktop/non-gaming workload performance when gaming optimizations are installed
- **FR-008**: System MUST configure mangohud with overlay hidden by default, toggled via keybind, showing FPS, frame times, CPU/GPU utilization, and temperatures when activated

### Key Entities

- **GameMode Configuration**: Defines what optimizations apply when a game is detected — CPU governor, GPU power profile, I/O priority, process niceness, scheduler policy
- **Environment Profile**: Set of environment variables (DXVK, Wine, Mesa, RADV) applied to game processes for optimal rendering
- **Kernel Tunables**: Boot parameters and runtime sysctl values affecting scheduler behavior, timer resolution, and memory management for gaming workloads

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Games achieve at least 10% higher average FPS compared to default system configuration on the same hardware
- **SC-002**: Frame time variance (1% lows) improves by at least 15% compared to default configuration
- **SC-003**: Shader compilation stutter in Proton games is eliminated or reduced to imperceptible levels (< 1 frame drop per shader compile)
- **SC-004**: System returns to power-saving defaults within 10 seconds of last game exit
- **SC-005**: All gaming optimizations are applied declaratively — a single Salt apply configures everything with no manual steps
- **SC-006**: Desktop responsiveness (application launch time, compositor latency) is not measurably degraded by gaming optimizations when no game is running

## Clarifications

### Session 2026-03-09

- Q: Should Proton/DXVK environment variables be set globally or scoped to game processes? → A: Hybrid — variables only read by target software (DXVK_*, WINE_*, mesa_glthread, shader cache) set globally via environment.d; variables that affect all Vulkan applications (RADV_PERFTEST, GPU-specific Mesa flags) scoped to game processes via GameMode config.
- Q: Should mangohud overlay be always visible or toggled by keybind? → A: Toggle — overlay hidden by default, activated/deactivated via keybind. Full metrics (FPS, frame times, CPU/GPU utilization, temperatures) shown when toggled on.
- Q: How should non-Steam games activate gaming optimizations? → A: gamemoderun only — users launch non-Steam games via `gamemoderun ./game`. No custom wrapper scripts or auto-detection. GameMode config handles all game-scoped optimizations (including RADV_PERFTEST from hybrid env var approach).

## Assumptions

- The target hardware is AMD CPU + AMD GPU (RADV Vulkan driver), as reflected in the current host configuration
- CachyOS already provides an optimized kernel (BORE/EEVDF scheduler, 1000Hz timer) — this spec builds on top of that baseline
- GameMode (already installed via steam.sls) is the primary mechanism for dynamic performance switching
- The user plays games primarily through Steam/Proton, with occasional native Linux games
- The display supports VRR (FreeSync/Adaptive Sync) at 3840x2160@240Hz
- Existing sysctl tuning (vm.max_map_count, swappiness, writeback) is already gaming-friendly and should be preserved
