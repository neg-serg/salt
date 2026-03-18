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

## 2. UEFI Settings Checklist

These changes are made in the motherboard BIOS/UEFI setup (typically accessed via Del or F2 at POST).

| Setting | Action | Expected Savings |
|---|---|---|
| Fast Boot / Quick Boot | **Enable** — skips full memory training on warm boots | 5-10s |
| Network Boot / PXE | **Disable** — no network boot needed on a workstation | 1-3s |
| POST Delay | **Set to 0** — removes artificial "press key" wait | 0-5s |
| USB Port Initialization | **Minimize** — init only ports needed at boot (keyboard) | 1-2s |
| CSM / Legacy Boot | **Disable** — UEFI-only mode skips legacy option ROM scan | variable |
| USB Keyboard Support | **Keep enabled** — required for BIOS access on next boot | 0s |

After applying these settings, firmware phase should drop to 5-10s on warm boots.

**Important**: Fast Boot may prevent BIOS access on the next reboot. Most boards still allow access by holding the key during a cold boot (power off, then on). Verify this works before enabling.

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
