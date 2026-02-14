# CachyOS Deployment Guide

Deploy bootstrapped CachyOS rootfs to NVMe with LVM + btrfs.

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

## Prerequisites

Bootstrapped rootfs at `/var/mnt/one/cachyos-root` (from `bootstrap-cachyos.sh`).

All commands below run as **root** from the Fedora host.

## Part 1: Disk Setup

```bash
# ── Partition ──────────────────────────────────────────────
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 4GiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary 4GiB 100%

# ── Format ESP ────────────────────────────────────────────
mkfs.fat -F32 -n EFI /dev/nvme0n1p1

# ── LVM ───────────────────────────────────────────────────
pvcreate /dev/nvme0n1p2
vgcreate main /dev/nvme0n1p2
lvcreate -l 90%FREE -n sys main

# ── btrfs on LVM ──────────────────────────────────────────
mkfs.btrfs -f -L cachyos /dev/main/sys

# ── Create subvolumes ─────────────────────────────────────
mount /dev/main/sys /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@snapshots
umount /mnt
```

## Part 2: Mount & Copy

```bash
# ── Mount target layout ───────────────────────────────────
mount -o subvol=@,compress=zstd:1,noatime /dev/main/sys /mnt
mkdir -p /mnt/{boot,home,.snapshots,var/cache,var/log}
mount /dev/nvme0n1p1 /mnt/boot
mount -o subvol=@home,compress=zstd:1,noatime /dev/main/sys /mnt/home
mount -o subvol=@snapshots,compress=zstd:1,noatime /dev/main/sys /mnt/.snapshots
mount -o subvol=@cache,compress=zstd:1,noatime /dev/main/sys /mnt/var/cache
mount -o subvol=@log,compress=zstd:1,noatime /dev/main/sys /mnt/var/log

# ── Copy rootfs ───────────────────────────────────────────
rsync -aAXH --info=progress2 /var/mnt/one/cachyos-root/ /mnt/
```

After rsync, kernel + initramfs + limine.conf + EFI binary are on ESP
(they were in `/boot/` in the rootfs, which maps to the ESP mount).

## Part 3: Chroot

```bash
# ── Bind-mount pseudo-filesystems ─────────────────────────
mount --bind /dev /mnt/dev
mount --bind /dev/pts /mnt/dev/pts
mount -t proc proc /mnt/proc
mount -t sysfs sys /mnt/sys
mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars 2>/dev/null || true

chroot /mnt /bin/bash
```

Everything below runs **inside the chroot**.

### 3.1 Generate fstab

```bash
ESP_UUID=$(blkid -s UUID -o value /dev/nvme0n1p1)

cat > /etc/fstab <<EOF
# CachyOS — LVM + btrfs + ESP
/dev/mapper/main-sys  /              btrfs  subvol=@,compress=zstd:1,noatime          0  0
/dev/mapper/main-sys  /home          btrfs  subvol=@home,compress=zstd:1,noatime      0  0
/dev/mapper/main-sys  /.snapshots    btrfs  subvol=@snapshots,compress=zstd:1,noatime 0  0
/dev/mapper/main-sys  /var/cache     btrfs  subvol=@cache,compress=zstd:1,noatime     0  0
/dev/mapper/main-sys  /var/log       btrfs  subvol=@log,compress=zstd:1,noatime       0  0
UUID=${ESP_UUID}      /boot          vfat   umask=0077                                0  1
EOF
```

### 3.2 Verify mkinitcpio hooks

```bash
# lvm2 hook must be present (bootstrap adds it)
grep -q 'lvm2' /etc/mkinitcpio.conf || \
  sed -i 's/block filesystems/block lvm2 filesystems/' /etc/mkinitcpio.conf

# Rebuild initramfs
mkinitcpio -P
```

### 3.3 Update Limine config

```bash
cat > /boot/limine.conf <<'LIMINE'
timeout: 5
default_entry: 1
interface_branding: CachyOS

/CachyOS
    protocol: linux
    kernel_path: boot():/vmlinuz-linux-cachyos-lts
    kernel_cmdline: root=/dev/mapper/main-sys rootflags=subvol=@ rw quiet splash
    module_path: boot():/initramfs-linux-cachyos-lts.img

/CachyOS (fallback)
    protocol: linux
    kernel_path: boot():/vmlinuz-linux-cachyos-lts
    kernel_cmdline: root=/dev/mapper/main-sys rootflags=subvol=@ rw
    module_path: boot():/initramfs-linux-cachyos-lts-fallback.img
LIMINE
```

### 3.4 Install Limine EFI

```bash
mkdir -p /boot/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI

# Register in UEFI boot menu
efibootmgr --create --disk /dev/nvme0n1 --part 1 \
  --label "CachyOS" --loader "EFI\\BOOT\\BOOTX64.EFI"
```

### 3.5 Set passwords

```bash
passwd        # root
passwd neg    # user
```

### 3.6 Verify and exit

```bash
# Quick sanity checks
ls /boot/vmlinuz-linux-cachyos-lts    # kernel on ESP
ls /boot/initramfs-linux-cachyos-lts.img
cat /etc/fstab
grep lvm2 /etc/mkinitcpio.conf
systemctl is-enabled NetworkManager
systemctl is-enabled sshd

# Exit chroot
exit
```

## Part 4: Cleanup & Reboot

```bash
umount -R /mnt
reboot
```

Select "CachyOS" in UEFI boot menu (or it boots automatically via
`EFI/BOOT/BOOTX64.EFI` fallback path).

## Post-Boot

After first successful boot:

```bash
# Apply Salt configuration
cd ~/src/salt
./apply_cachyos.sh

# Deploy dotfiles
chezmoi apply
```

## Troubleshooting

**Kernel panic: VFS unable to mount root**
- Check that mkinitcpio has `lvm2` hook: `grep HOOKS /etc/mkinitcpio.conf`
- Rebuild: `mkinitcpio -P`
- Verify root device: `lvs` should show `main/sys`

**Limine doesn't find kernel**
- ESP must be mounted at `/boot` (not `/boot/efi`)
- `ls /boot/vmlinuz-linux-cachyos-lts` must exist on the FAT32 partition

**No network after boot**
- `systemctl start NetworkManager`
- `nmcli device wifi list` (Wi-Fi via iwd backend)
- Check: `cat /etc/resolv.conf` (fallback DNS: 1.1.1.1, 8.8.8.8)
