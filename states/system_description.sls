{% from 'host_config.jinja' import host %}
{% from 'packages.jinja' import categories, copr_packages,
    unwanted_packages, unwanted_base_packages, flatpak_apps %}
# Salt state for Fedora Silverblue
# Handles filesystem immutability

# Fix containers policy to allow podman to pull images
fix_containers_policy:
  file.managed:
    - name: /etc/containers/policy.json
    - source: salt://configs/containers-policy.json
    - user: root
    - group: root
    - mode: '0644'

system_timezone:
  timezone.system:
    - name: Europe/Moscow

system_locale_keymap:
  cmd.run:
    - name: |
        localectl set-locale LANG=en_US.UTF-8
        localectl set-x11-keymap ru,us
    - unless: |
        status=$(localectl status)
        echo "$status" | grep -q 'LANG=en_US.UTF-8' &&
        echo "$status" | grep -q 'X11 Layout.*ru'

system_hostname:
  cmd.run:
    - name: hostnamectl set-hostname {{ host.hostname }}
    - unless: test "$(hostname)" = "{{ host.hostname }}"

user_root:
  user.present:
    - name: root
    - shell: /usr/bin/zsh

user_neg:
  user.present:
    - name: neg
    - shell: /usr/bin/zsh
    - uid: 1000
    - gid: 1000

plugdev_group:
  group.present:
    - name: plugdev
    - system: True

# user.present groups broken on Python 3.14 (crypt module removed)
neg_groups:
  cmd.run:
    - name: usermod -aG wheel,libvirt,plugdev neg
    - unless: id -nG neg | tr ' ' '\n' | grep -qx plugdev
    - require:
      - group: plugdev_group

sudo_timeout:
  file.managed:
    - name: /etc/sudoers.d/timeout
    - contents: |
        Defaults timestamp_timeout=30
    - user: root
    - group: root
    - mode: '0440'
    - check_cmd: /usr/sbin/visudo -c -f

sudo_nopasswd:
  file.managed:
    - name: /etc/sudoers.d/99-neg-nopasswd
    - contents: |
        neg ALL=(ALL) NOPASSWD: ALL
    - user: root
    - group: root
    - mode: '0440'
    - check_cmd: /usr/sbin/visudo -c -f

# Package lists: see packages.jinja (categories, copr, flatpak, extensions)

include:
  - amnezia
  - bind_mounts
  - build_rpms
  - distrobox
  - dns
  - fira-code-nerd
  - floorp
  - greetd
  - hardware
  - hy3
  - install_rpms
  - installers
  - kernel_modules
  - kernel_params
  - monitoring
  - mpd
  - network
  - ollama
  - pkg_cache
  - services
  - sysctl
  - user_services

# Remove packages no longer in desired state (list in packages.jinja).
remove_unwanted_packages:
  cmd.run:
    - name: |
        {% raw %}
        to_remove=()
        pkgs=({% endraw %}{% for pkg in unwanted_packages %}'{{ pkg }}' {% endfor %}{% raw %})
        for pkg in "${pkgs[@]}"; do
          rpm -q "$pkg" > /dev/null 2>&1 && to_remove+=("$pkg")
        done
        if [ ${#to_remove[@]} -gt 0 ]; then
          echo "Removing: ${to_remove[*]}"
          rpm-ostree uninstall "${to_remove[@]}" || true
        fi
        {% endraw %}
    - onlyif: rpm -q {% for pkg in unwanted_packages %}{{ pkg }} {% endfor %}2>/dev/null | grep -v 'not installed'

# Remove base-image packages (rpm-ostree override remove, list in packages.jinja).
remove_unwanted_base_packages:
  cmd.run:
    - name: |
        {% raw %}
        to_remove=()
        overrides=$(rpm-ostree status --json | jq -r '.deployments[0]."requested-base-removals"[]?')
        pkgs=({% endraw %}{% for pkg in unwanted_base_packages %}'{{ pkg }}' {% endfor %}{% raw %})
        for pkg in "${pkgs[@]}"; do
          echo "$overrides" | grep -qx "$pkg" || to_remove+=("$pkg")
        done
        if [ ${#to_remove[@]} -gt 0 ]; then
          echo "Overriding base packages: ${to_remove[*]}"
          rpm-ostree override remove "${to_remove[@]}"
        fi
        {% endraw %}
    - unless: |
        {% raw %}
        overrides=$(rpm-ostree status --json | jq -r '.deployments[0]."requested-base-removals"[]?')
        pkgs=({% endraw %}{% for pkg in unwanted_base_packages %}'{{ pkg }}' {% endfor %}{% raw %})
        for pkg in "${pkgs[@]}"; do
          echo "$overrides" | grep -qx "$pkg" || exit 1
        done
        {% endraw %}

# Install all packages (system + COPR) in a single rpm-ostree transaction.
# One transaction = one deployment, much faster than two separate ones.
install_all_packages:
  cmd.run:
    - name: |
        {% raw %}
        wanted=({% endraw %}{% for cat, pkgs in categories | dictsort %}{% for pkg in pkgs %}{{ pkg.name }} {% endfor %}{% endfor %}{% for pkg in copr_packages %}{{ pkg.name }} {% endfor %}{% raw %})
        installed=$(rpm -qa --queryformat '%{NAME}\n' | sort -u)
        layered=$(rpm-ostree status --json | jq -r '.deployments[]."requested-packages"[]?' | sort -u)
        have=$(sort -u <(echo "$installed") <(echo "$layered"))
        missing=$(comm -23 <(printf '%s\n' "${wanted[@]}" | sort -u) <(echo "$have"))
        if [ -n "$missing" ]; then
          rpm-ostree install -y --allow-inactive $missing
        fi
        {% endraw %}
    - unless: rpm -q {% for cat, pkgs in categories | dictsort %}{% for pkg in pkgs %}{{ pkg.name }} {% endfor %}{% endfor %}{% for pkg in copr_packages %}{{ pkg.name }} {% endfor %}> /dev/null 2>&1
    - require:
      - file: fix_containers_policy
      - cmd: copr_dualsensectl
      - cmd: copr_espanso
      - cmd: copr_himalaya
      - cmd: copr_spotifyd
      - cmd: copr_sbctl
      - cmd: copr_audinux
      - cmd: rpmfusion_nonfree
      {# - cmd: copr_86box -- disabled, 86Box needs Qt 6.10 #}

zsh_config_dir:
  file.directory:
    - name: /etc/zsh
    - user: root
    - group: root
    - mode: '0755'

/etc/zshenv:
  file.managed:
    - contents: |
        # System-wide Zsh environment
        export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
    - user: root
    - group: root
    - mode: '0644'

/etc/zsh/zshrc:
  file.managed:
    - contents: |
        # System-wide zshrc
        # If ZDOTDIR is set, zsh will source it from there.
        # This ensures ZDOTDIR is respected even if set in /etc/zshenv
        [[ -f "$ZDOTDIR/.zshrc" ]] && source "$ZDOTDIR/.zshrc"
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: zsh_config_dir

# Force shell update for users (rpm-ostree might be tricky with user.present)
force_zsh_neg:
  cmd.run:
    - name: usermod -s /usr/bin/zsh neg
    - unless: 'test "$(getent passwd neg | cut -d: -f7)" = "/usr/bin/zsh"'

force_zsh_root:
  cmd.run:
    - name: usermod -s /usr/bin/zsh root
    - unless: 'test "$(getent passwd root | cut -d: -f7)" = "/usr/bin/zsh"'

etckeeper_init:
  cmd.run:
    - name: etckeeper init && etckeeper commit "Initial commit"
    - unless: test -d /etc/.git
    - onlyif: command -v etckeeper

running_services:
  service.running:
    - names:
      - NetworkManager
      - firewalld
      - chronyd
      - dbus-broker
      - bluetooth
      - libvirtd
      - openrgb
    - enable: True

# Disable tuned: its throughput-performance profile conflicts with custom
# I/O tuning (sets read_ahead_kb=8192 on NVMe, may override sysctl values).
# All tuning is managed manually via sysctl.sls, kernel_params.sls, hardware.sls.
disable_tuned:
  service.dead:
    - name: tuned
    - enable: False

/mnt/zero:
  file.directory:
    - makedirs: True

mount_zero:
  mount.mounted:
    - name: /mnt/zero
    - device: /dev/mapper/argon-zero
    - fstype: xfs
    - mkmnt: True
    - opts: noatime
    - persist: True

/mnt/one:
  file.directory:
    - makedirs: True

mount_one:
  mount.mounted:
    - name: /mnt/one
    - device: /dev/mapper/xenon-one
    - fstype: xfs
    - mkmnt: True
    - opts: noatime
    - persist: True

# btrfs compression: set as filesystem property since Fedora Atomic's ostree
# mount mechanism ignores compress= fstab option (not shown in /proc/mounts).
btrfs_compress_home:
  cmd.run:
    - name: btrfs property set /var/home compression zstd:-1
    - unless: btrfs property get /var/home compression 2>/dev/null | grep -q 'zstd:-1'

btrfs_compress_var:
  cmd.run:
    - name: btrfs property set /var compression zstd:-1
    - unless: btrfs property get /var compression 2>/dev/null | grep -q 'zstd:-1'

# Flatpak applications (list in packages.jinja)
install_flatpak_apps:
  cmd.run:
    - name: |
        installed=$(flatpak list --user --app --columns=application)
        apps=({% for app in flatpak_apps %}'{{ app.id }}' {% endfor %})
        missing=()
        for app in "${apps[@]}"; do
          grep -qxF "$app" <<< "$installed" || missing+=("$app")
        done
        if [ -n "${missing[*]}" ]; then
          flatpak install --user -y flathub "${missing[@]}"
        fi
    - runas: neg
    - unless: |
        installed=$(flatpak list --user --app --columns=application)
        apps=({% for app in flatpak_apps %}'{{ app.id }}' {% endfor %})
        for app in "${apps[@]}"; do
          grep -qxF "$app" <<< "$installed" || exit 1
        done

# Flatpak overrides: Wayland cursor + GTK dark theme
flatpak_overrides:
  cmd.run:
    - name: flatpak override --user --env=XCURSOR_PATH=/run/host/user-share/icons:/run/host/share/icons --env=GTK_THEME=Adwaita:dark
    - runas: neg
    - require:
      - cmd: install_flatpak_apps
    - unless: flatpak override --user --show 2>/dev/null | grep -q XCURSOR_PATH

# --- COPR repo enables (fast test -f guards) ---
{% set copr_repos = [
    ('dualsensectl', 'kapsh',        'dualsensectl'),
    ('espanso',      'eclipseo',     'espanso'),
    ('himalaya',     'atim',         'himalaya'),
    ('spotifyd',     'mbooth',       'spotifyd'),
    ('sbctl',        'chenxiaolong', 'sbctl'),
    ('yabridge',     'patrickl',     'wine-tkg'),
    ('audinux',      'ycollet',      'audinux'),
] %}
{% for suffix, owner, project in copr_repos %}
copr_{{ suffix }}:
  cmd.run:
    - name: dnf copr enable -y {{ owner }}/{{ project }}
    - unless: test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:{{ owner }}:{{ project }}.repo
{% endfor %}

{# Kernel variant from host_config: 'lto' → kernel-cachyos-lto, 'gcc' → kernel-cachyos #}
{% set _kvar = host.features.kernel.variant %}
{% set _kcopr = 'kernel-cachyos-lto' if _kvar == 'lto' else 'kernel-cachyos' %}
{% set _kpkg  = 'kernel-cachyos-lto' if _kvar == 'lto' else 'kernel-cachyos' %}

copr_cachyos_kernel:
  cmd.run:
    - name: dnf copr enable -y bieszczaders/{{ _kcopr }}
    - unless: test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:bieszczaders:{{ _kcopr }}.repo

# --- RPM Fusion (nonfree — for Steam; pulls in free as dependency) ---
rpmfusion_nonfree:
  cmd.run:
    - name: dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    - unless: test -f /etc/yum.repos.d/rpmfusion-nonfree.repo

{# copr_86box: disabled, 86Box needs Qt 6.10 but base image pins 6.9.2
copr_86box:
  cmd.run:
    - name: dnf copr enable -y rob72/86Box
    - unless: test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:rob72:86Box.repo
#}

# --- CachyOS kernel (special: override remove + install, stays separate) ---
install_cachyos_kernel:
  cmd.run:
    - name: rpm-ostree override remove kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra --install {{ _kpkg }} --install {{ _kpkg }}-devel-matched
    - require:
      - cmd: copr_cachyos_kernel
    - unless: rpm -q {{ _kpkg }} || rpm-ostree status --json | grep -q {{ _kpkg }}

# --- SSH directory setup ---
ssh_dir:
  file.directory:
    - name: /var/home/neg/.ssh
    - user: neg
    - group: neg
    - mode: '0700'

# --- Wallust cache defaults (prevents hyprland source errors on first boot) ---
wallust_cache_dir:
  file.directory:
    - name: /var/home/neg/.cache/wallust
    - user: neg
    - group: neg
    - mode: '0755'

wallust_hyprland_defaults:
  file.managed:
    - name: /var/home/neg/.cache/wallust/hyprland.conf
    - user: neg
    - group: neg
    - mode: '0644'
    - replace: false
    - contents: |
        $col_border_active_base = rgba(00285981)
        $col_border_inactive   = rgba(00000000)
        $shadow_color          = rgba(005fafaa)
    - require:
      - file: wallust_cache_dir

# --- dconf: GTK/icon/font theme for Wayland apps ---
set_dconf_themes:
  cmd.run:
    - name: |
        dconf write /org/gnome/desktop/interface/gtk-theme "'Flight-Dark-GTK'"
        dconf write /org/gnome/desktop/interface/icon-theme "'kora'"
        dconf write /org/gnome/desktop/interface/font-name "'Iosevka 10'"
    - runas: neg
    - env:
      - DBUS_SESSION_BUS_ADDRESS: "unix:path=/run/user/1000/bus"
    - unless: |
        test "$(dconf read /org/gnome/desktop/interface/gtk-theme)" = "'Flight-Dark-GTK'" &&
        test "$(dconf read /org/gnome/desktop/interface/icon-theme)" = "'kora'" &&
        test "$(dconf read /org/gnome/desktop/interface/font-name)" = "'Iosevka 10'"
