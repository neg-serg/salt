# CachyOS bootstrap verification state
# Validates that bootstrap-cachyos.sh + cachyos-packages.sh completed correctly.
# Run: sudo salt-call --local state.apply cachyos
# Verify only: sudo salt-call --local state.apply cachyos test=True

# ===================================================================
# User & Auth
# ===================================================================

cachyos_user_neg:
  user.present:
    - name: neg
    - shell: /bin/zsh
    - groups:
      - wheel

cachyos_sudo_nopasswd:
  file.exists:
    - name: /etc/sudoers.d/99-neg-nopasswd

cachyos_sudo_nopasswd_content:
  cmd.run:
    - name: 'true'
    - unless: grep -q 'neg ALL=(ALL) NOPASSWD: ALL' /etc/sudoers.d/99-neg-nopasswd

cachyos_wheel_sudoers:
  cmd.run:
    - name: 'true'
    - unless: grep -q '^%wheel ALL=(ALL:ALL) ALL' /etc/sudoers

# ===================================================================
# Locale, Timezone, Hostname
# ===================================================================

cachyos_timezone:
  cmd.run:
    - name: 'true'
    - unless: readlink /etc/localtime | grep -q Europe/Moscow

cachyos_locale:
  cmd.run:
    - name: 'true'
    - unless: grep -q '^LANG=en_US.UTF-8' /etc/locale.conf

cachyos_hostname:
  cmd.run:
    - name: 'true'
    - unless: grep -q '^cachyos' /etc/hostname

cachyos_vconsole:
  file.exists:
    - name: /etc/vconsole.conf

cachyos_hosts:
  cmd.run:
    - name: 'true'
    - unless: grep -q 'cachyos' /etc/hosts

# ===================================================================
# Bootloader (Limine)
# ===================================================================

cachyos_limine_conf:
  file.exists:
    - name: /boot/limine.conf

cachyos_limine_efi:
  file.exists:
    - name: /boot/EFI/BOOT/BOOTX64.EFI

cachyos_limine_conf_content:
  cmd.run:
    - name: 'true'
    - unless: grep -q 'vmlinuz-linux-cachyos-lts' /boot/limine.conf

# ===================================================================
# Btrfs & Snapper
# ===================================================================

cachyos_snapper_config:
  file.exists:
    - name: /etc/snapper/configs/root

cachyos_snapper_registered:
  cmd.run:
    - name: 'true'
    - unless: grep -q 'root' /etc/conf.d/snapper 2>/dev/null

# ===================================================================
# Initramfs
# ===================================================================

cachyos_mkinitcpio_lvm2_hook:
  cmd.run:
    - name: 'true'
    - unless: grep -q 'lvm2' /etc/mkinitcpio.conf

cachyos_mkinitcpio_zstd:
  cmd.run:
    - name: 'true'
    - unless: grep -q '^COMPRESSION="zstd"' /etc/mkinitcpio.conf

cachyos_initramfs_exists:
  cmd.run:
    - name: 'true'
    - unless: test -f /boot/initramfs-linux-cachyos-lts.img

# ===================================================================
# Pacman & Repos
# ===================================================================

cachyos_pacman_v4_arch:
  cmd.run:
    - name: 'true'
    - unless: grep -q 'x86_64_v4' /etc/pacman.conf

cachyos_repo_znver4:
  cmd.run:
    - name: 'true'
    - unless: grep -q '^\[cachyos-znver4\]' /etc/pacman.conf

cachyos_repo_core_znver4:
  cmd.run:
    - name: 'true'
    - unless: grep -q '^\[cachyos-core-znver4\]' /etc/pacman.conf

cachyos_repo_extra_znver4:
  cmd.run:
    - name: 'true'
    - unless: grep -q '^\[cachyos-extra-znver4\]' /etc/pacman.conf

cachyos_repo_cachyos:
  cmd.run:
    - name: 'true'
    - unless: grep -q '^\[cachyos\]' /etc/pacman.conf

cachyos_mirrorlist_v4:
  file.exists:
    - name: /etc/pacman.d/cachyos-v4-mirrorlist

cachyos_mirrorlist:
  file.exists:
    - name: /etc/pacman.d/cachyos-mirrorlist

# ===================================================================
# Services
# ===================================================================

cachyos_svc_networkmanager:
  service.enabled:
    - name: NetworkManager

cachyos_svc_iwd:
  service.enabled:
    - name: iwd

cachyos_svc_sshd:
  service.enabled:
    - name: sshd

cachyos_svc_snapper_timeline:
  service.enabled:
    - name: snapper-timeline.timer

cachyos_svc_snapper_cleanup:
  service.enabled:
    - name: snapper-cleanup.timer

# ===================================================================
# Networking
# ===================================================================

cachyos_nm_iwd_backend:
  file.exists:
    - name: /etc/NetworkManager/conf.d/wifi-iwd.conf

cachyos_nm_iwd_backend_content:
  cmd.run:
    - name: 'true'
    - unless: grep -q 'wifi.backend=iwd' /etc/NetworkManager/conf.d/wifi-iwd.conf

cachyos_resolv_conf:
  cmd.run:
    - name: 'true'
    - unless: test -s /etc/resolv.conf

# ===================================================================
# Key packages (spot-check representative set from each category)
# ===================================================================

{% set check_packages = [
    'base', 'linux-cachyos-lts', 'linux-firmware',
    'limine', 'btrfs-progs', 'snapper', 'snap-pac',
    'networkmanager', 'openssh', 'paru', 'sudo', 'zsh', 'git',
    'hyprland', 'kitty', 'podman', 'pipewire',
    'rust', 'clang', 'cmake', 'nodejs',
    'bat', 'fd', 'fzf', 'ripgrep', 'zoxide',
    'mpd', 'mpv', 'ffmpegthumbnailer',
    'btop', 'fastfetch', 'smartmontools',
    'nmap', 'ollama', 'telegram-desktop',
    'tmux', 'gopass', 'chezmoi', 'git-delta',
    'libvirt', 'qemu-desktop',
    'rofi', 'dunst', 'swappy', 'quickshell', 'swayosd', 'wl-clip-persist',
    'imagemagick', 'yt-dlp',
    'unbound', 'avahi', 'samba', 'grafana',
] %}

{% for pkg in check_packages %}
cachyos_pkg_{{ pkg | replace('-', '_') }}:
  cmd.run:
    - name: 'true'
    - unless: pacman -Q {{ pkg }} >/dev/null 2>&1
{% endfor %}

# ===================================================================
# AUR packages (spot-check)
# ===================================================================

{% set check_aur = [
    'pyprland', 'wlogout',
    'carapace-bin', 'doggo', 'wallust',
    'pipemixer', 'newsraft', 'salt',
    'amneziawg-tools', 'amneziawg-dkms',
] %}

{% for pkg in check_aur %}
cachyos_aur_{{ pkg | replace('-', '_') }}:
  cmd.run:
    - name: 'true'
    - unless: pacman -Q {{ pkg }} >/dev/null 2>&1
{% endfor %}

# ===================================================================
# Zsh configuration
# ===================================================================

cachyos_zsh_neg:
  cmd.run:
    - name: 'true'
    - unless: 'test "$(getent passwd neg | cut -d: -f7)" = "/bin/zsh"'

cachyos_zsh_root:
  cmd.run:
    - name: 'true'
    - unless: 'test "$(getent passwd root | cut -d: -f7)" = "/bin/zsh"'
