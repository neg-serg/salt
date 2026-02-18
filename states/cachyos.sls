{% from 'host_config.jinja' import host %}
{% set user = host.user %}
# CachyOS bootstrap verification state
# Validates that bootstrap-cachyos.sh + cachyos-packages.sh completed correctly.
# Run: sudo salt-call --local state.apply cachyos
# Verify only: sudo salt-call --local state.apply cachyos test=True

# ===================================================================
# User & Auth
# ===================================================================

cachyos_user_neg:
  user.present:
    - name: {{ user }}
    - shell: /bin/zsh
    - groups:
      - wheel

# ===================================================================
# Files that must exist
# ===================================================================

{% set required_files = {
    'sudo_nopasswd':  '/etc/sudoers.d/99-' ~ user ~ '-nopasswd',
    'vconsole':       '/etc/vconsole.conf',
    'limine_conf':    '/boot/limine.conf',
    'limine_efi':     '/boot/EFI/BOOT/BOOTX64.EFI',
    'snapper_config': '/etc/snapper/configs/root',
    'mirrorlist_v4':  '/etc/pacman.d/cachyos-v4-mirrorlist',
    'mirrorlist':     '/etc/pacman.d/cachyos-mirrorlist',
    'nm_iwd_backend': '/etc/NetworkManager/conf.d/wifi-iwd.conf',
} %}

{% for name, path in required_files.items() %}
cachyos_{{ name }}:
  file.exists:
    - name: {{ path }}
{% endfor %}

# ===================================================================
# Configuration & content verification checks
# ===================================================================

{% set verify_checks = {
    'sudo_nopasswd_content': "rg -q '" ~ user ~ " ALL=\\(ALL\\) NOPASSWD: ALL' /etc/sudoers.d/99-" ~ user ~ "-nopasswd",
    'wheel_sudoers':         "rg -q '^%wheel ALL=\\(ALL:ALL\\) ALL' /etc/sudoers",
    'timezone':              'readlink /etc/localtime | rg -q Europe/Moscow',
    'locale':                "rg -q '^LANG=en_US.UTF-8' /etc/locale.conf",
    'hostname':              "rg -q '^cachyos' /etc/hostname",
    'hosts':                 "rg -q 'cachyos' /etc/hosts",
    'limine_conf_content':   "rg -q 'vmlinuz-linux-cachyos-lts' /boot/limine.conf",
    'snapper_registered':    "rg -q 'root' /etc/conf.d/snapper 2>/dev/null",
    'mkinitcpio_lvm2_hook':  "rg -q 'lvm2' /etc/mkinitcpio.conf",
    'mkinitcpio_zstd':       "rg -q '^COMPRESSION=\"zstd\"' /etc/mkinitcpio.conf",
    'initramfs_exists':      'test -f /boot/initramfs-linux-cachyos-lts.img',
    'pacman_v4_arch':        "rg -q 'x86_64_v4' /etc/pacman.conf",
    'repo_znver4':           "rg -q '^\\[cachyos-znver4\\]' /etc/pacman.conf",
    'repo_core_znver4':      "rg -q '^\\[cachyos-core-znver4\\]' /etc/pacman.conf",
    'repo_extra_znver4':     "rg -q '^\\[cachyos-extra-znver4\\]' /etc/pacman.conf",
    'repo_cachyos':          "rg -q '^\\[cachyos\\]' /etc/pacman.conf",
    'nm_iwd_backend_content': "rg -q 'wifi.backend=iwd' /etc/NetworkManager/conf.d/wifi-iwd.conf",
    'resolv_conf':           'test -s /etc/resolv.conf',
    'zsh_neg':               'test "$(getent passwd ' ~ user ~ ' | cut -d: -f7)" = "/bin/zsh"',
    'zsh_root':              'test "$(getent passwd root | cut -d: -f7)" = "/bin/zsh"',
} %}

{% for name, check in verify_checks.items() %}
cachyos_{{ name }}:
  cmd.run:
    - name: 'true'
    - unless: '{{ check | replace("'", "''") }}'
{% endfor %}

# ===================================================================
# Services that must be enabled
# ===================================================================

{% set enabled_services = {
    'networkmanager':    'NetworkManager',
    'iwd':              'iwd',
    'sshd':             'sshd',
    'snapper_timeline': 'snapper-timeline.timer',
    'snapper_cleanup':  'snapper-cleanup.timer',
} %}

{% for id_suffix, svc in enabled_services.items() %}
cachyos_svc_{{ id_suffix }}:
  service.enabled:
    - name: {{ svc }}
{% endfor %}

# ===================================================================
# Package spot-checks (representative set from each category)
# ===================================================================

{% set package_checks = {
    'pkg': [
        'base', 'linux-cachyos-lts', 'linux-firmware',
        'limine', 'btrfs-progs', 'snapper', 'snap-pac',
        'networkmanager', 'openssh', 'paru', 'sudo', 'zsh', 'git',
        'hyprland', 'kitty', 'podman', 'pipewire',
        'rust', 'clang', 'cmake', 'nodejs',
        'bat', 'fd', 'fzf', 'ripgrep', 'zoxide',
        'mpd', 'mpv', 'ffmpegthumbnailer',
        'btop', 'fastfetch', 'smartmontools',
        'nmap', 'socat', 'ollama', 'telegram-desktop',
        'tmux', 'gopass', 'chezmoi', 'git-delta',
        'libvirt', 'qemu-desktop',
        'rofi', 'dunst', 'swappy', 'quickshell', 'swayosd', 'wl-clip-persist', 'ttf-material-symbols-variable',
        'ttf-jetbrains-mono-nerd', 'ttf-icomoon-feather', 'otf-font-awesome',
        'noto-fonts', 'noto-fonts-emoji', 'ttf-ibm-plex', 'inter-font',
        'imagemagick', 'yt-dlp',
        'unbound', 'avahi', 'samba', 'grafana',
    ],
    'aur': [
        'pyprland', 'wlogout',
        'carapace-bin', 'doggo', 'wallust',
        'pipemixer', 'newsraft', 'salt',
        'amneziawg-tools', 'amneziawg-dkms',
    ],
    'custom': [
        'raise', 'neg-pretty-printer', 'richcolors',
        'albumdetails', 'taoup', 'iosevka-neg-fonts',
    ],
} %}

{% for category, packages in package_checks.items() %}
{% for pkg in packages %}
cachyos_{{ category }}_{{ pkg | replace('-', '_') }}:
  cmd.run:
    - name: 'true'
    - unless: pacman -Q {{ pkg }} >/dev/null 2>&1
{% endfor %}
{% endfor %}
