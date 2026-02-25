# Руководство по развёртыванию CachyOS

Развёртывание подготовленного rootfs CachyOS на NVMe с LVM + btrfs + Limine.

## Разметка

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

## Быстрый старт

### 1. Подготовка rootfs

```bash
sudo ./scripts/bootstrap-cachyos.sh
```

Создаёт rootfs в `/mnt/one/cachyos-root/` и копирует salt-репозиторий в `/mnt/one/salt/` для использования с live USB.

### 2. Развёртывание (с основной машины или live USB)

**С основной машины:**

```bash
sudo ./scripts/deploy-cachyos.sh /dev/nvme0n1
```

**С live USB:**

```bash
vgchange -ay xenon
mount /dev/mapper/xenon-one /mnt/one
bash /mnt/one/salt/scripts/deploy-cachyos.sh /dev/nvme0n1 /mnt/one/cachyos-root
```

Скрипт выполняет всё автоматически:
- GPT-разметка (4 GiB ESP + LVM)
- Настройка LVM (VG `main`, LV `sys` на 90%)
- Btrfs с subvolumes (@, @home, @cache, @log, @snapshots)
- rsync rootfs
- Генерация fstab
- mkinitcpio с lvm2 hook
- Установка загрузчика Limine + UEFI boot entry

### 3. Установить пароли и перезагрузиться

```bash
chroot /mnt/deploy passwd        # root
chroot /mnt/deploy passwd neg    # пользователь
umount -R /mnt/deploy
reboot
```

### 4. После первой загрузки

Подробное руководство записывается в `/root/POST-BOOT.md` во время развёртывания.
Краткое содержание:

```bash
# Подключить XFS-диски с данными
sudo vgchange -ay xenon argon
sudo mkdir -p /mnt/{one,zero}
sudo mount /dev/mapper/xenon-one /mnt/one
sudo mount /dev/mapper/argon-zero /mnt/zero

# Скопировать salt-репозиторий
cp -a /mnt/one/salt ~/src/salt

# Настроить GPG (Yubikey) + gopass
gpg --card-status
gopass clone <store-url>

# Применить конфигурацию + dotfiles
cd ~/src/salt && scripts/salt-apply.sh

# Добавить XFS-монтирования в fstab
echo '/dev/mapper/xenon-one  /mnt/one  xfs  noatime  0  0' | sudo tee -a /etc/fstab
echo '/dev/mapper/argon-zero /mnt/zero xfs  noatime  0  0' | sudo tee -a /etc/fstab
```

## Содержимое xenon-one

После подготовки всё необходимое для развёртывания находится на XFS:

| Путь | Назначение |
|------|---------|
| `/mnt/one/cachyos-root/` | Подготовленный rootfs |
| `/mnt/one/salt/` | Полный salt-репозиторий (states, dotfiles, scripts, build) |
| `/mnt/one/salt/scripts/deploy-cachyos.sh` | Скрипт развёртывания |
| `/mnt/one/salt/scripts/cachyos-packages.sh` | Установщик пакетов |
| `/mnt/one/salt/scripts/salt-apply.sh` | Применение Salt + chezmoi после загрузки |

## Решение проблем

**Kernel panic: VFS unable to mount root**
- Проверить lvm2 hook: `grep HOOKS /etc/mkinitcpio.conf`
- Пересобрать: `mkinitcpio -P`
- Убедиться: `lvs` должен показывать `main/sys`

**Limine не находит ядро**
- ESP должен быть примонтирован в `/boot` (не `/boot/efi`)
- Проверить: `ls /boot/vmlinuz-linux-cachyos-lts`

**Нет сети после загрузки**
- `systemctl start NetworkManager`
- Wi-Fi: `nmcli device wifi connect <SSID> --ask`
- Резервный DNS: `cat /etc/resolv.conf` (1.1.1.1, 8.8.8.8)

**Кастомные пакеты (автоматизировано через Salt)**
- 5 пакетов собираются из PKGBUILDs в `build/pkgbuilds/` через Salt states:
  raise, neg-pretty-printer, richcolors, albumdetails (custom_pkgs.sls),
  iosevka-neg-fonts (iosevka.sls)
- Собираются автоматически при запуске `scripts/salt-apply.sh`
