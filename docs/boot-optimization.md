# Boot Optimization Guide

Actionable guide for reducing boot time on a CachyOS workstation managed by Salt.

---

## 1. Boot Time Overview

Baseline measured with `systemd-analyze` and `systemd-analyze blame` on a typical cold boot.

| Phase | Duration | Notes |
|---|---|---|
| Firmware (UEFI POST) | 20.0s | Largest contributor; hardware-dependent |
| Loader (Limine) | 1.3s | Timeout already set to 1s |
| Kernel | 2.6s | Includes decompression + early init |
| initrd | 3.1s | mkinitcpio with zstd compression |
| Userspace | 3.4s | systemd services up to graphical.target |
| **Total** | **30.5s** | Cold boot, firmware dominates |

Firmware accounts for ~65% of total boot time. The sections below target each phase.

---

## 2. UEFI Settings (ROG CROSSHAIR X870E EXTREME)

These changes are made in the motherboard BIOS/UEFI setup (Del at POST). Settings are listed with exact menu paths for BIOS 1715+ (AGESA ComboAM5 PI 1.2.0.3g+).

### Group A: Memory (5-15s savings)

Memory training is the single largest contributor to AM5 POST time. DDR5 at 6000 MT/s with 2x32GB DIMMs requires extensive UMC calibration on every cold boot. Memory Context Restore (MCR) caches validated training results in non-volatile storage and restores them on subsequent boots.

| # | Setting | UEFI Path | Value | Savings |
|---|---|---|---|---|
| 1 | Memory Context Restore | `Advanced > AMD CBS > UMC Common Options > DDR Options > DDR Memory Features > Memory Context Restore` | **Enabled** | 5-15s |
| 2 | Power Down Enable | `Advanced > AMD CBS > UMC Common Options > DDR Options > DDR Controller Configuration > DDR Power Options > Power Down Enable` | **Enabled** | (companion to MCR) |
| 3 | DDR Training Runtime Reduction | `Advanced > AMD CBS > UMC Common Options > DDR Options > DDR Training Options > DDR Training Runtime Reduction` | **Enabled** | 0-2s |

**Important**: MCR MUST be paired with Power Down Enable — AMD documentation confirms instability (BSOD, memory corruption) without it. Disable MCR temporarily when changing RAM kits or memory timings to force a full retrain. CMOS clear recovers from any MCR-related boot failure.

### Group B: Unused Hardware (2-4s savings)

Each disabled subsystem removes initialization time from POST. These settings disable hardware that is not in use.

| # | Setting | UEFI Path | Value | Savings |
|---|---|---|---|---|
| 4 | SATA Controller(s) | `Advanced > SATA Configuration > SATA Controller(s)` | **Disabled** | 0.5-1s |
| 5 | Network Stack | `Advanced > Network Stack Configuration > Network Stack` | **Disabled** | 1-3s |
| 6 | Legacy USB Support | `Advanced > USB Configuration > Legacy USB Support` | **Auto** | 1-2s |

**Notes**: SATA can be disabled because all storage is NVMe (verified via `lsblk`). Network Stack controls PXE boot only — NICs remain functional in the OS. Legacy USB set to Auto (not Disabled) preserves keyboard access in BIOS.

### Group C: Boot Configuration (1-3s savings)

Low-risk quick wins that eliminate delays, legacy scanning, and unnecessary boot visuals.

| # | Setting | UEFI Path | Value | Savings |
|---|---|---|---|---|
| 7 | Fast Boot | `Boot > Boot Configuration > Fast Boot` | **Enabled** | 2-5s |
| 8 | Post Delay Time | `Boot > Boot Configuration > Post Delay Time` | **0 sec** | 0-5s |
| 9 | Boot Logo Display | `Boot > Boot Configuration > Boot Logo Display` | **Disabled** | 0-1s |
| 10 | Wait For F1 If Error | `Boot > Boot Configuration > Wait For F1 If Error` | **Disabled** | 0s (avoids hangs) |
| 11 | Launch CSM | `Boot > CSM > Launch CSM` | **Disabled** | 0-2s |
| 12 | Core Watchdog Timer | `Advanced > AMD CBS > CPU Common Options > Core Watchdog > Core Watchdog Timer Enable` | **Disabled** | negligible |

### Rollback

Before making changes, save a BIOS profile via `Tool > ASUS User Profile > Save to Profile`.

- **Keyboard works**: Enter BIOS → `Tool > ASUS User Profile > Load from Profile` → restore saved slot
- **Keyboard dead in BIOS**: Press CMOS Clear button on rear I/O (resets all settings to defaults)
- **Won't POST**: Use USB BIOS FlashBack button on rear I/O (no CPU/RAM needed)

---

## 3. Automated Optimizations

These optimizations are managed by Salt states and applied automatically during `just apply`.

### mkinitcpio compression: zstd -19 to -1

**State**: `states/mkinitcpio.sls`

The default CachyOS mkinitcpio uses `zstd -19` compression, which produces a smaller initramfs but decompresses slower. Switching to `zstd -1` trades ~2-3 MB of disk space for faster decompression at boot.

- **Savings**: ~1-1.5s from initrd phase
- **Trade-off**: initramfs grows from ~25 MB to ~28 MB (negligible on NVMe)

### libvirtd socket-only activation

**State**: `states/desktop.sls`

libvirtd is configured for socket activation instead of starting at boot. The daemon only launches when a VM management tool (virt-manager, virsh) connects to the socket.

- **Savings**: 1.2s removed from critical boot path
- **Trade-off**: first `virsh` command after boot has ~1s delay while daemon starts

### Loki deferred after graphical.target

**State**: `states/monitoring_loki.sls`

Loki (log aggregation) is configured with `After=graphical.target` so it starts only after the desktop is ready. This reduces I/O contention during the critical boot path where NVMe bandwidth matters most (initrd, systemd generators, display manager).

- **Savings**: reduces boot I/O contention (not directly measurable in wall time)
- **Trade-off**: logs from very early userspace may arrive at Loki with a short delay

### Limine timeout

**State**: `states/kernel_params_limine.sls`

Limine bootloader timeout is set to 1s. This is already optimal — long enough to catch a keypress for menu access, short enough to not waste time.

---

## 4. Kernel Parameter Analysis

The system uses several security-hardening kernel parameters. Each was evaluated for boot time impact to determine whether removal is justified.

### Parameters with negligible cost (keep)

| Parameter | Boot Cost | Purpose |
|---|---|---|
| `init_on_alloc=1` | <100ms | Zeros freed memory pages; prevents kernel memory disclosure |
| `page_alloc.shuffle=1` | negligible | Randomizes page allocator freelists; enhances ASLR |
| `slab_nomerge` | negligible | Prevents slab cache merging; blocks heap exploitation techniques |
| `randomize_kstack_offset=on` | zero | Randomizes kernel stack offset per syscall |
| `vsyscall=none` | zero (removes code) | Disables legacy vsyscall page; eliminates an attack surface |
| `debugfs=off` | negligible | Disables debugfs mount; removes kernel debug info exposure |

**Total estimated cost of all security parameters: <200ms.**

Removing these would save less than 200ms while degrading security posture. Not recommended.

### Parameters already optimized for speed

| Parameter | Effect |
|---|---|
| `nowatchdog` | Disables watchdog timers — removes periodic interrupts |
| `tsc=reliable` | Skips TSC calibration against HPET/ACPI PM timer |
| `split_lock_detect=off` | Disables split-lock detection — removes alignment check overhead |
| `rcupdate.rcu_expedited=1` | Uses expedited RCU grace periods — faster boot-time state transitions |

These are already present and contributing to the current boot times.

---

## 5. Benchmark Results

To be filled after applying changes and measuring with `systemd-analyze`.

| Phase | Before | After | Delta |
|---|---|---|---|
| Firmware | 20.0s | | |
| Loader | 1.3s | | |
| Kernel | 2.6s | | |
| initrd | 3.1s | | |
| Userspace | 3.4s | | |
| **Total** | **30.5s** | | |

**How to measure**:

```bash
# Overall boot time breakdown
systemd-analyze

# Slowest services
systemd-analyze blame | head -20

# Critical path visualization (opens SVG)
systemd-analyze plot > /tmp/boot-plot.svg && handlr open /tmp/boot-plot.svg

# Firmware time (if supported by hardware)
systemd-analyze --firmware-setup  # schedules reboot into UEFI
```

---

## 6. Troubleshooting

### Fallback initramfs

The Limine boot menu always includes a fallback entry using `initramfs-linux-cachyos-lts-fallback.img`. This initramfs includes all modules and does not depend on autodetection. If a mkinitcpio configuration change breaks boot, select the fallback entry in the Limine menu.

### Snapper rollback

Every `just apply` creates a btrfs snapshot pair. To revert:

```bash
just rollback
```

This runs `snapper undochange` on the most recent pre/post snapshot pair, restoring the filesystem to the state before the last Salt apply.

### Emergency TTY

If the graphical session fails to start, switch to a TTY:

- **Ctrl+Alt+F2** — greetd emergency TTY (always available)
- **Ctrl+Alt+F3-F6** — additional TTYs

Log in and inspect logs:

```bash
journalctl -b --priority=err
systemctl --failed
```

### Reverting mkinitcpio changes

If changing mkinitcpio compression breaks boot:

1. Select the **fallback** entry in the Limine boot menu
2. Log in via TTY
3. Edit `/etc/mkinitcpio.conf` — revert the `COMPRESSION_OPTIONS` line
4. Regenerate initramfs: `sudo mkinitcpio -P`
5. Reboot normally

Alternatively, run `just rollback` if the change was applied via Salt.
