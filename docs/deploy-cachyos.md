# CachyOS Deployment Guide

Deploy bootstrapped CachyOS rootfs to NVMe with LVM + btrfs + Limine.

## Layout

```
/dev/nvme0n1
├── p1  4 GiB   FAT32 (ESP)     → /boot
└── p2  rest    LVM PV
    └── VG: main
        └── LV: sys (90% VG)
            └── btrfs
                ├── @          → /
                ├── @home      → /home
                ├── @cache     → /var/cache
                ├── @log       → /var/log
                └── @snapshots → /.snapshots
```

## Quick Start

### 1. Bootstrap

```bash
sudo ./scripts/bootstrap-cachyos.sh
```

Produces rootfs at `/mnt/one/cachyos-root/` and copies the salt
repo to `/mnt/one/salt/` for use from a live USB.

### 2. Deploy (from existing host or live USB)

**From the host:**

```bash
sudo ./scripts/deploy-cachyos.sh /dev/nvme0n1
```

**From a live USB:**

```bash
vgchange -ay xenon
mount /dev/mapper/xenon-one /mnt/one
bash /mnt/one/salt/scripts/deploy-cachyos.sh /dev/nvme0n1 /mnt/one/cachyos-root
```

The script handles everything automatically:
- GPT partitioning (4 GiB ESP + LVM)
- LVM setup (VG `main`, LV `sys` at 90%)
- Btrfs with subvolumes (@, @home, @cache, @log, @snapshots)
- rsync of rootfs
- fstab generation
- mkinitcpio with lvm2 hook
- Limine bootloader + UEFI boot entry

### 3. Set passwords and reboot

```bash
chroot /mnt/deploy passwd        # root
chroot /mnt/deploy passwd neg    # user
umount -R /mnt/deploy
reboot
```

### 4. After first boot

A detailed guide is written to `/root/POST-BOOT.md` during deploy.
Summary:

```bash
# Mount XFS data disks
sudo vgchange -ay xenon argon
sudo mkdir -p /mnt/{one,zero}
sudo mount /dev/mapper/xenon-one /mnt/one
sudo mount /dev/mapper/argon-zero /mnt/zero

# Copy salt repo
cp -a /mnt/one/salt ~/src/salt

# Set up GPG (Yubikey) + gopass
gpg --card-status
gopass clone <store-url>

# Apply config + dotfiles
cd ~/src/salt && scripts/salt-apply.sh

# Persist XFS mounts
echo '/dev/mapper/xenon-one  /mnt/one  xfs  noatime  0  0' | sudo tee -a /etc/fstab
echo '/dev/mapper/argon-zero /mnt/zero xfs  noatime  0  0' | sudo tee -a /etc/fstab
```

## What's on xenon-one

After bootstrap, everything needed for deploy lives on XFS:

| Path | Purpose |
|------|---------|
| `/mnt/one/cachyos-root/` | Bootstrapped rootfs |
| `/mnt/one/salt/` | Full salt repo (states, dotfiles, scripts, build) |
| `/mnt/one/salt/scripts/deploy-cachyos.sh` | Deploy script |
| `/mnt/one/salt/scripts/cachyos-packages.sh` | Package installer |
| `/mnt/one/salt/scripts/salt-apply.sh` | Post-boot Salt + chezmoi apply |

## Troubleshooting

**Kernel panic: VFS unable to mount root**
- Check lvm2 hook: `grep HOOKS /etc/mkinitcpio.conf`
- Rebuild: `mkinitcpio -P`
- Verify: `lvs` should show `main/sys`

**Limine doesn't find kernel**
- ESP must be at `/boot` (not `/boot/efi`)
- Verify: `ls /boot/vmlinuz-linux-cachyos-lts`

**No network after boot**
- `systemctl start NetworkManager`
- Wi-Fi: `nmcli device wifi connect <SSID> --ask`
- DNS fallback: `cat /etc/resolv.conf` (1.1.1.1, 8.8.8.8)

**Custom packages (automated by Salt)**
- 5 packages built from PKGBUILDs in `build/pkgbuilds/` via Salt states:
  raise, neg-pretty-printer, richcolors, albumdetails (custom_pkgs.sls),
  iosevka-neg-fonts (iosevka.sls)
- Built automatically during `scripts/salt-apply.sh`
