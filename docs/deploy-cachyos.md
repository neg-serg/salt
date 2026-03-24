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

# Set up gopass backend
# GPG/Yubikey flow:
gpg --card-status

# age flow:
# gopass age identities keygen
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

## Display Manager

Salt deploys **greetd** as the display manager (login screen) and disables SDDM:

- greetd config: `/etc/greetd/config.toml` (deployed by `greetd.sls`)
- Greeter: cage kiosk compositor + quickshell greeter
- Session wrapper: `/etc/greetd/session-wrapper` (launches Hyprland)
- Emergency TTY: `Ctrl+Alt+F2` always drops to a text login (`getty@tty2`)

greetd is **enabled** by Salt (`service.enabled`) but requires a reboot to take effect.
After `salt-apply.sh` completes, the first reboot will show the graphical greeter.

If the greeter doesn't appear (black screen), switch to TTY2 (`Ctrl+Alt+F2`) and check:

```bash
journalctl -u greetd --no-pager -n 50
systemctl status greetd
cat /etc/greetd/config.toml
```

## Host Aliases

`states/data/hosts.yaml` supports hostname aliases for migration scenarios.
The `aliases:` section maps one hostname to another's config:

```yaml
aliases:
  cachyos: telfir    # "cachyos" hostname uses telfir's config
```

This is useful when the hostname hasn't been set yet (e.g. first boot from a live
USB still reports the default hostname). The alias resolves before config merge,
so all feature flags and overrides from the target host apply transparently.

To add a new host, add an entry under `hosts:` in `states/data/hosts.yaml`.
Only override values that differ from defaults — everything else is inherited
via recursive merge (`slsutil.merge` with `strategy='recurse'`).

## Troubleshooting

### Boot issues

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

### Salt / chezmoi issues

**chezmoi apply fails (gopass unlock path not available)**

`salt-apply.sh` will show diagnostic output listing affected `.tmpl` files.
Common causes:
- GPG/Yubikey flow: token not plugged in or GPG agent not running
- age flow: identity not unlocked for the current user session
- gopass store not cloned yet (see step 6 in POST-BOOT.md)

Fix:
```bash
# GPG/Yubikey flow:
gpg --card-status                    # verify Yubikey detected

# age flow:
# gopass age agent unlock
gopass ls                            # verify store accessible
chezmoi apply --force --source ~/src/salt/dotfiles  # re-run chezmoi only
```

Note: Salt states complete independently of chezmoi. If chezmoi fails, all system
configuration is still applied — only dotfiles with secrets are affected.

**Salt state fails with "file not found" for /mnt/one or /mnt/zero**

XFS data disks must be mounted before Salt runs. Salt states that depend on
`/mnt/one` (amnezia cache, music library) have explicit `require: mount` guards,
but the mounts themselves must exist:

```bash
sudo vgchange -ay xenon argon
sudo mount /dev/mapper/xenon-one /mnt/one
sudo mount /dev/mapper/argon-zero /mnt/zero
# Re-run Salt
cd ~/src/salt && scripts/salt-apply.sh
```

**greetd shows black screen after reboot**

Switch to TTY2 (`Ctrl+Alt+F2`), log in, and check:

```bash
journalctl -u greetd --no-pager -n 50
# Common causes:
# - Missing display config: check host.display and host.primary_output in hosts.yaml
# - Quickshell greeter not built: check ~/.config/quickshell/
# - Cage not installed: pacman -Q cage
```

Recovery: temporarily switch to console login while debugging:
```bash
sudo systemctl disable greetd
sudo systemctl enable getty@tty1
sudo reboot
```

**Service won't start after Salt apply**

```bash
systemctl status <service>           # check status
journalctl -u <service> -n 50       # check logs
systemctl reset-failed <service>    # clear failed state
systemctl restart <service>          # retry
```

For user services (MPD, mpdas, mpDris2, ProxyPilot, etc.):
```bash
systemctl --user status <service>
journalctl --user -u <service> -n 50
```

### Custom packages

6 packages built from PKGBUILDs in `build/pkgbuilds/` via Salt states:
raise, neg-pretty-printer, richcolors, albumdetails, duf (custom_pkgs.sls),
iosevka-neg-fonts (fonts.sls).
Built automatically during `scripts/salt-apply.sh`.
