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

# Настроить backend для gopass
# GPG/Yubikey flow:
gpg --card-status

# age flow:
export GPG_TTY="$(tty)"
# gopass age identities keygen
gopass age agent unlock
gopass show -o email/gmail/address
gopass clone <store-url>

# Применить конфигурацию + dotfiles
cd ~/src/salt && scripts/salt-apply.sh

# Добавить XFS-монтирования в fstab
echo '/dev/mapper/xenon-one  /mnt/one  xfs  noatime  0  0' | sudo tee -a /etc/fstab
echo '/dev/mapper/argon-zero /mnt/zero xfs  noatime  0  0' | sudo tee -a /etc/fstab
```

Если эта машина используется как staging/cutover host для миграции backend `gopass`,
подготовьте rollback package до production cutover: копия active store, git history
store, legacy unlock materials и written rollback steps. Не переписывайте git history
в основном migration flow, проверьте representative subset attached/non-password entries
и держите legacy path доступным в течение фиксированного 7-дневного stabilization window.

## Содержимое xenon-one

После подготовки всё необходимое для развёртывания находится на XFS:

| Путь | Назначение |
|------|---------|
| `/mnt/one/cachyos-root/` | Подготовленный rootfs |
| `/mnt/one/salt/` | Полный salt-репозиторий (states, dotfiles, scripts, build) |
| `/mnt/one/salt/scripts/deploy-cachyos.sh` | Скрипт развёртывания |
| `/mnt/one/salt/scripts/cachyos-packages.sh` | Установщик пакетов |
| `/mnt/one/salt/scripts/salt-apply.sh` | Применение Salt + chezmoi после загрузки |

## Менеджер входа

Salt разворачивает **greetd** как менеджер входа (экран логина) и отключает SDDM:

- Конфиг greetd: `/etc/greetd/config.toml` (деплоится из `greetd.sls`)
- Приветственный экран: cage kiosk compositor + quickshell greeter
- Обёртка сессии: `/etc/greetd/session-wrapper` (запускает Hyprland)
- Аварийный TTY: `Ctrl+Alt+F2` всегда переключает на текстовый вход (`getty@tty2`)

greetd **активируется** через Salt (`service.enabled`), но требует перезагрузки.
После завершения `salt-apply.sh` первая перезагрузка покажет графический приветственный экран.

Если приветственный экран не появляется (чёрный экран), переключитесь на TTY2 (`Ctrl+Alt+F2`) и проверьте:

```bash
journalctl -u greetd --no-pager -n 50
systemctl status greetd
cat /etc/greetd/config.toml
```

## Алиасы хостов

`states/data/hosts.yaml` поддерживает алиасы имён хостов для сценариев миграции.
Секция `aliases:` отображает одно имя хоста на конфигурацию другого:

```yaml
aliases:
  cachyos: telfir    # хост "cachyos" использует конфигурацию telfir
```

Это полезно, когда hostname ещё не установлен (например, первая загрузка с live USB
показывает hostname по умолчанию). Алиас разрешается до слияния конфигурации,
поэтому все флаги фич и переопределения целевого хоста применяются прозрачно.

Чтобы добавить новый хост, создайте запись в секции `hosts:` файла `states/data/hosts.yaml`.
Переопределяйте только значения, отличающиеся от defaults — всё остальное наследуется
через рекурсивное слияние (`slsutil.merge` со стратегией `recurse`).

## Решение проблем

### Проблемы загрузки

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

### Проблемы Salt / chezmoi

**chezmoi apply падает (gopass unlock path недоступен)**

`salt-apply.sh` выведет диагностику со списком затронутых `.tmpl` файлов.
Частые причины:
- Для GPG/Yubikey flow: токен не подключён или GPG-агент не запущен
- Для age flow: identity не разблокирована в текущей user session
- gopass-хранилище не склонировано (см. шаг 6 в POST-BOOT.md)

Исправление:
```bash
# GPG/Yubikey flow:
gpg --card-status                    # проверить, что Yubikey обнаружен

# age flow:
export GPG_TTY="$(tty)"
gopass age agent unlock              # если включён age agent
gopass show -o email/gmail/address   # проверить, что расшифровка работает
chezmoi apply --force --source ~/src/salt/dotfiles  # перезапустить только chezmoi
```

При cutover на `age` не убирайте старый GPG/Yubikey path сразу. Оставьте его
доступным, пока не закончится 7-дневное окно стабилизации без fallback и без
нерешённых сбоев в обязательных workflow.

Важно: Salt states выполняются независимо от chezmoi. Если chezmoi упадёт, вся системная
конфигурация всё равно будет применена — только dotfiles с секретами не развернутся.

**Salt state падает с "file not found" для /mnt/one или /mnt/zero**

XFS-диски с данными должны быть примонтированы до запуска Salt. States, зависящие от
`/mnt/one` (кэш amnezia, музыкальная библиотека), имеют явные `require: mount` guard-ы,
но сами точки монтирования должны существовать:

```bash
sudo vgchange -ay xenon argon
sudo mount /dev/mapper/xenon-one /mnt/one
sudo mount /dev/mapper/argon-zero /mnt/zero
# Перезапустить Salt
cd ~/src/salt && scripts/salt-apply.sh
```

**greetd показывает чёрный экран после перезагрузки**

Переключитесь на TTY2 (`Ctrl+Alt+F2`), залогиньтесь и проверьте:

```bash
journalctl -u greetd --no-pager -n 50
# Частые причины:
# - Нет конфигурации дисплея: проверьте host.display и host.primary_output в hosts.yaml
# - Quickshell greeter не собран: проверьте ~/.config/quickshell/
# - Cage не установлен: pacman -Q cage
```

Восстановление: временно переключиться на консольный вход для отладки:
```bash
sudo systemctl disable greetd
sudo systemctl enable getty@tty1
sudo reboot
```

**Сервис не запускается после Salt apply**

```bash
systemctl status <service>           # проверить статус
journalctl -u <service> -n 50       # проверить логи
systemctl reset-failed <service>    # сбросить failed-состояние
systemctl restart <service>          # повторить запуск
```

Для пользовательских сервисов (MPD, mpdas, mpDris2, ProxyPilot и т.д.):
```bash
systemctl --user status <service>
journalctl --user -u <service> -n 50
```

### Кастомные пакеты

6 пакетов собираются из PKGBUILDs в `build/pkgbuilds/` через Salt states:
raise, neg-pretty-printer, richcolors, albumdetails, duf (custom_pkgs.sls),
iosevka-neg-fonts (fonts.sls).
Собираются автоматически при запуске `scripts/salt-apply.sh`.
