{% from 'host_config.jinja' import host %}
{% from 'packages.jinja' import categories, copr_packages,
    unwanted_packages, unwanted_base_packages,
    flatpak_apps, floorp_extensions, unwanted_extensions %}
# Salt state for Fedora Silverblue
# Handles filesystem immutability

# Fix containers policy to allow podman to pull images
fix_containers_policy:
  file.managed:
    - name: /etc/containers/policy.json
    - contents: |
        {
            "default": [
                {
                    "type": "insecureAcceptAnything"
                }
            ],
            "transports":
                {
                    "docker-daemon":
                        {
                            "": [{"type":"insecureAcceptAnything"}]
                        }
                }
        }
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

# Package lists: see packages.jinja (categories, copr, flatpak, extensions)

include:
  - pkg_cache
  - amnezia
  - bind_mounts
  - build_rpms
  - distrobox
  - dns
  - fira-code-nerd
  - hardware
  - hy3
  - install_rpms
  - kernel_modules
  - kernel_params
  - monitoring
  - mpd
  - network
  - services
  - sysctl

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

# --- greetd: replace sddm with quickshell greeter ---
disable_sddm:
  service.dead:
    - name: sddm
    - enable: False

greetd_config_dir:
  file.directory:
    - name: /etc/greetd
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

greetd_config:
  file.managed:
    - name: /etc/greetd/config.toml
    - contents: |
        [terminal]
        vt = 1

        [default_session]
        command = "Hyprland -c /etc/greetd/hyprland-greeter.conf"
        user = "neg"
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: greetd_config_dir

greetd_hyprland_config:
  file.managed:
    - name: /etc/greetd/hyprland-greeter.conf
    - source: salt://configs/greetd-hyprland.conf.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: greetd_config_dir

greetd_session_wrapper:
  file.managed:
    - name: /etc/greetd/session-wrapper
    - contents: |
        #!/bin/sh
        [ -f /etc/profile ] && . /etc/profile
        set -a
        [ -f "$HOME/.config/environment.d/10-user.conf" ] && . "$HOME/.config/environment.d/10-user.conf"
        set +a
        exec /usr/bin/starthyprland
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: greetd_config_dir

greetd_wallpaper:
  cmd.run:
    - name: |
        wallpaper=$(tr '\0' '\n' < /var/home/neg/.cache/swww/DP-2 2>/dev/null | grep '^/')
        if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
          cp -f "$wallpaper" /var/home/neg/.cache/greeter-wallpaper
        fi
    - runas: neg
    - require:
      - file: greetd_config_dir

# SELinux: allow greeter (xdm_t) to mmap fontconfig cache and read wallpaper from user cache
greetd_selinux_cache:
  cmd.run:
    - name: |
        TMP=$(mktemp -d)
        cat > "$TMP/greetd-cache.te" << 'POLICY'
        module greetd-cache 1.0;
        require {
            type xdm_t;
            type cache_home_t;
            type user_fonts_cache_t;
            class file { read open getattr map };
        }
        allow xdm_t user_fonts_cache_t:file map;
        allow xdm_t cache_home_t:file { read open getattr map };
        POLICY
        checkmodule -M -m -o "$TMP/greetd-cache.mod" "$TMP/greetd-cache.te"
        semodule_package -o "$TMP/greetd-cache.pp" -m "$TMP/greetd-cache.mod"
        semodule -i "$TMP/greetd-cache.pp"
        rm -rf "$TMP"
    - unless: semodule -l | grep -q '^greetd-cache'

greetd_enabled:
  service.enabled:
    - name: greetd
    - require:
      - file: greetd_config
      - cmd: install_custom_rpms

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

# --- Floorp browser: user.js + userChrome.css + userContent.css ---
floorp_user_js:
  file.managed:
    - name: /var/home/neg/.var/app/one.ablaze.floorp/.floorp/ltjcyqj7.default-default/user.js
    - source: salt://dotfiles/dot_config/floorp/user.js
    - user: neg
    - group: neg
    - makedirs: True

floorp_userchrome:
  file.managed:
    - name: /var/home/neg/.var/app/one.ablaze.floorp/.floorp/ltjcyqj7.default-default/chrome/userChrome.css
    - source: salt://dotfiles/dot_config/floorp/userChrome.css
    - user: neg
    - group: neg
    - makedirs: True

floorp_usercontent:
  file.managed:
    - name: /var/home/neg/.var/app/one.ablaze.floorp/.floorp/ltjcyqj7.default-default/chrome/userContent.css
    - source: salt://dotfiles/dot_config/floorp/userContent.css
    - user: neg
    - group: neg
    - makedirs: True

# --- Floorp extensions (download .xpi into profile) ---
{% set floorp_profile = '/var/home/neg/.var/app/one.ablaze.floorp/.floorp/ltjcyqj7.default-default' %}
{% for ext in floorp_extensions %}
floorp_ext_{{ ext.slug | replace('-', '_') }}:
  cmd.run:
    - name: curl -fsSL -o '{{ floorp_profile }}/extensions/{{ ext.id }}.xpi' 'https://addons.mozilla.org/firefox/downloads/latest/{{ ext.slug }}/latest.xpi'
    - creates: {{ floorp_profile }}/extensions/{{ ext.id }}.xpi
    - runas: neg
    - require:
      - cmd: install_flatpak_apps
{% endfor %}

# Remove extensions no longer wanted (list in packages.jinja).
{% for ext_id in unwanted_extensions %}
floorp_remove_ext_{{ loop.index }}:
  file.absent:
    - name: {{ floorp_profile }}/extensions/{{ ext_id }}.xpi
{% endfor %}

# Remove extensions.json so Floorp rebuilds it on next launch,
# picking up extensions.autoDisableScopes=0 from user.js
floorp_reset_extensions_json:
  file.absent:
    - name: {{ floorp_profile }}/extensions.json
    - require:
      - file: floorp_user_js
{% for ext in floorp_extensions %}
      - cmd: floorp_ext_{{ ext.slug | replace('-', '_') }}
{% endfor %}

# --- Neovim Python dependencies (nvr + pynvim) ---
install_neovim_python_deps:
  cmd.run:
    - name: pip install --user pynvim neovim-remote
    - runas: neg
    - creates: /var/home/neg/.local/bin/nvr

install_zi:
  cmd.run:
    - name: |
        export ZI_HOME="$HOME/.config/zi"
        mkdir -p "$ZI_HOME"
        git clone https://github.com/z-shell/zi.git "$ZI_HOME/bin"
    - runas: neg
    - creates: /var/home/neg/.config/zi/bin/zi.zsh

install_oh_my_posh:
  cmd.run:
    - name: curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
    - runas: neg
    - creates: /var/home/neg/.local/bin/oh-my-posh

install_aliae:
  cmd.run:
    - name: curl -fsSL https://github.com/JanDeDobbeleer/aliae/releases/latest/download/aliae-linux-amd64 -o ~/.local/bin/aliae && chmod +x ~/.local/bin/aliae
    - runas: neg
    - creates: /var/home/neg/.local/bin/aliae

install_grimblast:
  cmd.run:
    - name: curl -fsSL https://raw.githubusercontent.com/hyprwm/contrib/main/grimblast/grimblast -o ~/.local/bin/grimblast && chmod +x ~/.local/bin/grimblast
    - runas: neg
    - creates: /var/home/neg/.local/bin/grimblast

install_hyprevents:
  cmd.run:
    - name: |
        set -eo pipefail
        tmpdir=$(mktemp -d)
        cd "$tmpdir"
        curl -fsSL https://github.com/vilari-mickopf/hyprevents/archive/refs/heads/master.tar.gz | tar xz --strip-components=1
        install -Dm755 hyprevents event_handler event_loader -t ~/.local/bin/
        rm -rf "$tmpdir"
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/hyprevents

install_hyprprop:
  cmd.run:
    - name: curl -fsSL https://raw.githubusercontent.com/vilari-mickopf/hyprprop/master/hyprprop -o ~/.local/bin/hyprprop && chmod +x ~/.local/bin/hyprprop
    - runas: neg
    - creates: /var/home/neg/.local/bin/hyprprop

install_sops:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsS -o /dev/null -w '%{redirect_url}' https://github.com/getsops/sops/releases/latest | sed 's|.*/tag/||')
        curl -fsSL "https://github.com/getsops/sops/releases/download/${TAG}/sops-${TAG}.linux.amd64" -o ~/.local/bin/sops
        chmod +x ~/.local/bin/sops
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/sops

install_xdg_ninja:
  cmd.run:
    - name: curl -fsSL https://github.com/b3nj5m1n/xdg-ninja/releases/latest/download/xdgnj -o ~/.local/bin/xdg-ninja && chmod +x ~/.local/bin/xdg-ninja
    - runas: neg
    - creates: /var/home/neg/.local/bin/xdg-ninja

install_rmpc:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsS -o /dev/null -w '%{redirect_url}' https://github.com/mierak/rmpc/releases/latest | sed 's|.*/tag/||')
        curl -fsSL "https://github.com/mierak/rmpc/releases/download/${TAG}/rmpc-${TAG}-x86_64-unknown-linux-gnu.tar.gz" -o /tmp/rmpc.tar.gz
        tar -xzf /tmp/rmpc.tar.gz -C /tmp rmpc
        mv /tmp/rmpc ~/.local/bin/
        rm -f /tmp/rmpc.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/rmpc

install_rustmission:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/intuis/rustmission/releases/download/v0.5.0/rustmission-x86_64-unknown-linux-gnu.tar.xz -o /tmp/rustmission.tar.xz
        tar -xJf /tmp/rustmission.tar.xz -C /tmp --strip-components=1 --wildcards '*/rustmission'
        mv /tmp/rustmission ~/.local/bin/
        rm -f /tmp/rustmission.tar.xz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/rustmission

install_httpstat:
  cmd.run:
    - name: pip install --user httpstat
    - runas: neg
    - creates: /var/home/neg/.local/bin/httpstat

install_ssh_to_age:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/Mic92/ssh-to-age/releases/latest/download/ssh-to-age.linux-amd64 -o ~/.local/bin/ssh-to-age
        chmod +x ~/.local/bin/ssh-to-age
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/ssh-to-age

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

install_yazi:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip -o /tmp/yazi.zip
        unzip -o /tmp/yazi.zip -d /tmp/yazi_extracted
        mv /tmp/yazi_extracted/yazi-x86_64-unknown-linux-musl/yazi ~/.local/bin/
        mv /tmp/yazi_extracted/yazi-x86_64-unknown-linux-musl/ya ~/.local/bin/
        rm -rf /tmp/yazi.zip /tmp/yazi_extracted
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/yazi

install_broot:
  cmd.run:
    - name: curl -fsSL https://dystroy.org/broot/download/x86_64-linux/broot -o ~/.local/bin/broot && chmod +x ~/.local/bin/broot
    - runas: neg
    - creates: /var/home/neg/.local/bin/broot

install_nushell:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsSL https://api.github.com/repos/nushell/nushell/releases/latest | jq -r .tag_name)
        curl -fsSL "https://github.com/nushell/nushell/releases/latest/download/nu-${TAG}-x86_64-unknown-linux-musl.tar.gz" -o /tmp/nu.tar.gz
        tar -xzf /tmp/nu.tar.gz -C /tmp
        mv /tmp/nu-*-x86_64-unknown-linux-musl/nu* ~/.local/bin/
        rm -rf /tmp/nu.tar.gz /tmp/nu-*-x86_64-unknown-linux-musl
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/nu

install_eza:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz -o /tmp/eza.tar.gz
        tar -xzf /tmp/eza.tar.gz -C /tmp
        mv /tmp/eza ~/.local/bin/
        rm /tmp/eza.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/eza

install_television:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsSL https://api.github.com/repos/alexpasmantier/television/releases/latest | jq -r .tag_name)
        curl -fsSL "https://github.com/alexpasmantier/television/releases/download/${TAG}/tv-${TAG}-x86_64-unknown-linux-musl.tar.gz" -o /tmp/tv.tar.gz
        tar -xzf /tmp/tv.tar.gz -C /tmp
        mv /tmp/tv-${TAG}-x86_64-unknown-linux-musl/tv ~/.local/bin/
        rm -rf /tmp/tv.tar.gz /tmp/tv-${TAG}-x86_64-unknown-linux-musl
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/tv

# --- GitHub binary downloads (remaining migration packages) ---
install_xray:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o /tmp/xray.zip
        unzip -o /tmp/xray.zip -d /tmp/xray
        mv /tmp/xray/xray ~/.local/bin/
        chmod +x ~/.local/bin/xray
        rm -rf /tmp/xray.zip /tmp/xray
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/xray

install_sing_box:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsSL https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r .tag_name)
        VER=${TAG#v}
        curl -fsSL "https://github.com/SagerNet/sing-box/releases/download/${TAG}/sing-box-${VER}-linux-amd64.tar.gz" -o /tmp/sing-box.tar.gz
        tar -xzf /tmp/sing-box.tar.gz -C /tmp
        mv /tmp/sing-box-${VER}-linux-amd64/sing-box ~/.local/bin/
        rm -rf /tmp/sing-box.tar.gz /tmp/sing-box-${VER}-linux-amd64
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/sing-box

install_tdl:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/iyear/tdl/releases/latest/download/tdl_Linux_64bit.tar.gz -o /tmp/tdl.tar.gz
        tar -xzf /tmp/tdl.tar.gz -C /tmp tdl
        mv /tmp/tdl ~/.local/bin/
        rm -f /tmp/tdl.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/tdl

install_camilladsp:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/HEnquist/camilladsp/releases/latest/download/camilladsp-linux-amd64.tar.gz -o /tmp/camilladsp.tar.gz
        tar -xzf /tmp/camilladsp.tar.gz -C /tmp
        mv /tmp/camilladsp ~/.local/bin/
        rm -f /tmp/camilladsp.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/camilladsp

install_opencode:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/opencode-ai/opencode/releases/latest/download/opencode-linux-x86_64.tar.gz -o /tmp/opencode.tar.gz
        tar -xzf /tmp/opencode.tar.gz -C /tmp opencode
        mv /tmp/opencode ~/.local/bin/
        rm -f /tmp/opencode.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/opencode

install_adguardian:
  cmd.run:
    - name: curl -fsSL https://github.com/Lissy93/AdGuardian-Term/releases/latest/download/adguardian-linux -o ~/.local/bin/adguardian && chmod +x ~/.local/bin/adguardian
    - runas: neg
    - creates: /var/home/neg/.local/bin/adguardian

install_realesrgan:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL "https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan/releases/download/v0.2.0/realesrgan-ncnn-vulkan-v0.2.0-ubuntu.zip" -o /tmp/realesrgan.zip
        unzip -o /tmp/realesrgan.zip -d /tmp/realesrgan
        mv /tmp/realesrgan/realesrgan-ncnn-vulkan-v0.2.0-ubuntu/realesrgan-ncnn-vulkan ~/.local/bin/
        chmod +x ~/.local/bin/realesrgan-ncnn-vulkan
        rm -rf /tmp/realesrgan.zip /tmp/realesrgan
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/realesrgan-ncnn-vulkan

install_essentia_extractor:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://data.metabrainz.org/pub/musicbrainz/acousticbrainz/extractors/essentia-extractor-v2.1_beta2-linux-x86_64.tar.gz -o /tmp/essentia.tar.gz
        tar -xzf /tmp/essentia.tar.gz -C /tmp
        mv /tmp/streaming_extractor_music ~/.local/bin/essentia_streaming_extractor_music
        chmod +x ~/.local/bin/essentia_streaming_extractor_music
        rm -rf /tmp/essentia.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/essentia_streaming_extractor_music

# --- pip installs ---
install_scdl:
  cmd.run:
    - name: pip install --user scdl
    - runas: neg
    - creates: /var/home/neg/.local/bin/scdl

install_dr14_tmeter:
  cmd.run:
    - name: pip install --user git+https://github.com/simon-r/dr14_t.meter.git
    - runas: neg
    - creates: /var/home/neg/.local/bin/dr14_tmeter

install_euporie:
  cmd.run:
    - name: pip install --user euporie
    - runas: neg
    - creates: /var/home/neg/.local/bin/euporie

# --- cargo installs ---
install_handlr:
  cmd.run:
    - name: cargo install handlr-regex
    - runas: neg
    - creates: /var/home/neg/.local/share/cargo/bin/handlr

install_agg:
  cmd.run:
    - name: cargo install --git https://github.com/asciinema/agg
    - runas: neg
    - creates: /var/home/neg/.local/share/cargo/bin/agg

# NOTE: tailray needs dbus-devel (libdbus-sys). May fail on first run
# if dbus-devel was just layered and not yet active (requires reboot).
install_tailray:
  cmd.run:
    - name: cargo install --git https://github.com/NotAShelf/tailray
    - runas: neg
    - creates: /var/home/neg/.local/share/cargo/bin/tailray
    - onlyif:
      - pkg-config --exists dbus-1
      - command -v cargo

install_pzip:
  cmd.run:
    - name: cargo install pzip
    - runas: neg
    - creates: /var/home/neg/.local/share/cargo/bin/pz

# --- Script and file installs ---
install_mpvc:
  cmd.run:
    - name: curl -fsSL https://raw.githubusercontent.com/lwilletts/mpvc/master/mpvc -o ~/.local/bin/mpvc && chmod +x ~/.local/bin/mpvc
    - runas: neg
    - creates: /var/home/neg/.local/bin/mpvc

install_rofi_systemd:
  cmd.run:
    - name: curl -fsSL https://raw.githubusercontent.com/IvanMalison/rofi-systemd/master/rofi-systemd -o ~/.local/bin/rofi-systemd && chmod +x ~/.local/bin/rofi-systemd
    - runas: neg
    - creates: /var/home/neg/.local/bin/rofi-systemd

install_dool:
  cmd.run:
    - name: |
        set -eo pipefail
        git clone --depth=1 https://github.com/scottchiefbaker/dool.git /tmp/dool
        cp /tmp/dool/dool ~/.local/bin/
        chmod +x ~/.local/bin/dool
        rm -rf /tmp/dool
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/dool

install_qmk_udev_rules:
  cmd.run:
    - name: curl -fsSL https://raw.githubusercontent.com/qmk/qmk_firmware/master/util/udev/50-qmk.rules -o /etc/udev/rules.d/50-qmk.rules && udevadm control --reload-rules
    - creates: /etc/udev/rules.d/50-qmk.rules

install_oldschool_pc_fonts:
  cmd.run:
    - name: |
        set -eo pipefail
        mkdir -p ~/.local/share/fonts/oldschool-pc
        curl -fsSL https://int10h.org/oldschool-pc-fonts/download/oldschool_pc_font_pack_v2.2_linux.zip -o /tmp/fonts.zip
        unzip -o /tmp/fonts.zip -d /tmp/oldschool-fonts
        find /tmp/oldschool-fonts -name '*.otf' -exec cp {} ~/.local/share/fonts/oldschool-pc/ \;
        fc-cache -f ~/.local/share/fonts/oldschool-pc/
        rm -rf /tmp/fonts.zip /tmp/oldschool-fonts
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/share/fonts/oldschool-pc

# --- Special: RoomEQ Wizard (Java acoustic measurement) ---
install_roomeqwizard:
  cmd.run:
    - name: |
        set -eo pipefail
        mkdir -p ~/.local/opt/roomeqwizard
        curl -fsSL 'https://www.roomeqwizard.com/installers/REW_linux_no_jre_5_33.zip' -o /tmp/rew.zip
        unzip -o /tmp/rew.zip -d ~/.local/opt/roomeqwizard
        rm -f /tmp/rew.zip
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/opt/roomeqwizard

# --- Throne (sing-box GUI proxy frontend, bundled Qt) ---
install_throne:
  cmd.run:
    - name: |
        set -eo pipefail
        mkdir -p ~/.local/opt/throne
        curl -fsSL https://github.com/throneproj/Throne/releases/download/1.0.13/Throne-1.0.13-linux-amd64.zip -o /tmp/throne.zip
        unzip -o /tmp/throne.zip -d ~/.local/opt/throne
        ln -sf ~/.local/opt/throne/Throne ~/.local/bin/throne
        rm -f /tmp/throne.zip
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/opt/throne

# --- Overskride (Bluetooth GTK4 client, Flatpak bundle from GitHub) ---
install_overskride:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/kaii-lb/overskride/releases/download/v0.6.6/overskride.flatpak -o /tmp/overskride.flatpak
        flatpak install --user -y /tmp/overskride.flatpak
        rm -f /tmp/overskride.flatpak
    - runas: neg
    - shell: /bin/bash
    - unless: flatpak info io.github.kaii_lb.Overskride &>/dev/null

# --- Nyxt browser (Electron AppImage) ---
install_nyxt:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/atlas-engineer/nyxt/releases/download/4.0.0/Linux-Nyxt-x86_64.tar.gz -o /tmp/nyxt.tar.gz
        tar -xzf /tmp/nyxt.tar.gz -C /tmp
        mv /tmp/Nyxt-x86_64.AppImage ~/.local/bin/nyxt
        chmod +x ~/.local/bin/nyxt
        rm -f /tmp/nyxt.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/nyxt

# --- Open Sound Meter (FFT acoustic analysis, AppImage) ---
install_opensoundmeter:
  cmd.run:
    - name: curl -fsSL https://github.com/psmokotnin/osm/releases/download/v1.5.2/Open_Sound_Meter-v1.5.2-x86_64.AppImage -o ~/.local/bin/opensoundmeter && chmod +x ~/.local/bin/opensoundmeter
    - runas: neg
    - creates: /var/home/neg/.local/bin/opensoundmeter

# --- matugen (Material You color generation) ---
install_matugen:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/InioX/matugen/releases/download/v3.1.0/matugen-3.1.0-x86_64.tar.gz -o /tmp/matugen.tar.gz
        tar -xzf /tmp/matugen.tar.gz -C /tmp
        mv /tmp/matugen ~/.local/bin/
        rm -f /tmp/matugen.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/matugen

install_matugen_themes:
  cmd.run:
    - name: |
        set -eo pipefail
        git clone --depth=1 https://github.com/InioX/matugen-themes.git /tmp/matugen-themes
        mkdir -p ~/.config/matugen/templates
        cp -r /tmp/matugen-themes/*/ ~/.config/matugen/templates/
        rm -rf /tmp/matugen-themes
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.config/matugen/templates

# --- DroidCam (phone as webcam via v4l2loopback) ---
install_v4l2loopback:
  cmd.run:
    - name: rpm-ostree install -y akmod-v4l2loopback
    - unless: rpm -q akmod-v4l2loopback &>/dev/null || rpm-ostree status | grep -q v4l2loopback

install_droidcam:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://files.dev47apps.net/linux/droidcam_2.1.3.zip -o /tmp/droidcam.zip
        unzip -o /tmp/droidcam.zip -d /tmp/droidcam
        mv /tmp/droidcam/droidcam ~/.local/bin/
        mv /tmp/droidcam/droidcam-cli ~/.local/bin/
        chmod +x ~/.local/bin/droidcam ~/.local/bin/droidcam-cli
        rm -rf /tmp/droidcam.zip /tmp/droidcam
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/droidcam

# --- blesh (Bash Line Editor) ---
install_blesh:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz -o /tmp/blesh.tar.xz
        tar -xJf /tmp/blesh.tar.xz -C ~/.local/share/ --strip-components=1
        rm -f /tmp/blesh.tar.xz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/share/ble.sh

# --- hishtory (synced shell history search) ---
install_hishtory:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsSL https://api.github.com/repos/ddworken/hishtory/releases/latest | jq -r .tag_name)
        curl -fsSL "https://github.com/ddworken/hishtory/releases/download/${TAG}/hishtory-linux-amd64" -o ~/.local/bin/hishtory
        chmod +x ~/.local/bin/hishtory
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/hishtory

# --- iwmenu (interactive Wi-Fi menu for iwd/Wayland) ---
install_iwmenu:
  cmd.run:
    - name: cargo install --git https://github.com/e-tho/iwmenu
    - runas: neg
    - creates: /var/home/neg/.local/share/cargo/bin/iwmenu

# --- ollama: systemd service + models ---
ollama_service_unit:
  file.managed:
    - name: /etc/systemd/system/ollama.service
    - contents: |
        [Unit]
        Description=Ollama LLM Server
        After=network-online.target

        [Service]
        ExecStart=/usr/bin/ollama serve
        User=neg
        Group=neg
        Restart=always
        RestartSec=3
        WorkingDirectory=/var/home/neg
        Environment="HOME=/var/home/neg"
        Environment="OLLAMA_HOST=127.0.0.1:11434"
        Environment="OLLAMA_MODELS=/var/mnt/one/ollama/models"

        [Install]
        WantedBy=default.target
    - user: root
    - group: root
    - mode: '0644'

ollama_models_dir:
  file.directory:
    - name: /var/mnt/one/ollama/models
    - user: neg
    - group: neg
    - makedirs: True
    - require:
      - mount: mount_one

ollama_selinux_context:
  cmd.run:
    - name: |
        semanage fcontext -a -t var_lib_t "/mnt/one/ollama(/.*)?" 2>/dev/null || \
        semanage fcontext -m -t var_lib_t "/mnt/one/ollama(/.*)?"
        restorecon -Rv /var/mnt/one/ollama
    - unless: matchpathcon -V /var/mnt/one/ollama/models 2>&1 | grep -q verified
    - require:
      - file: ollama_models_dir

# ollama server (init_t) needs to read its key from ~/.ollama/ (user_home_t → var_lib_t)
# uses /var/home path per equivalency rule '/home /var/home'
ollama_selinux_homedir:
  cmd.run:
    - name: |
        semanage fcontext -a -t var_lib_t "/var/home/neg/\.ollama(/.*)?" 2>/dev/null || \
        semanage fcontext -m -t var_lib_t "/var/home/neg/\.ollama(/.*)?"
        restorecon -Rv /var/home/neg/.ollama
    - unless: ls -Z /var/home/neg/.ollama/id_ed25519 | grep -q var_lib_t

# ollama runs as init_t (no custom SELinux type) and needs outbound HTTPS for model pulls
ollama_selinux_network:
  cmd.run:
    - name: |
        TMP=$(mktemp -d)
        cat > "$TMP/ollama-network.te" << 'POLICY'
        module ollama-network 1.0;
        require {
            type init_t;
            type http_port_t;
            class tcp_socket name_connect;
        }
        allow init_t http_port_t:tcp_socket name_connect;
        POLICY
        checkmodule -M -m -o "$TMP/ollama-network.mod" "$TMP/ollama-network.te"
        semodule_package -o "$TMP/ollama-network.pp" -m "$TMP/ollama-network.mod"
        semodule -i "$TMP/ollama-network.pp"
        rm -rf "$TMP"
    - unless: semodule -l | grep -q '^ollama-network'

ollama_enable:
  cmd.run:
    - name: systemctl daemon-reload && systemctl enable ollama
    - onchanges:
      - file: ollama_service_unit
    - onlyif: command -v ollama
    - require:
      - cmd: ollama_selinux_context

ollama_start:
  cmd.run:
    - name: |
        systemctl daemon-reload
        systemctl restart ollama
        for i in $(seq 1 30); do
          curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && exit 0
          sleep 1
        done
        echo "ollama failed to start within 30s" >&2
        exit 1
    - unless: curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1
    - require:
      - cmd: ollama_enable
      - cmd: ollama_selinux_homedir

{% for model in ['deepseek-r1:8b', 'llama3.2:3b', 'qwen2.5-coder:7b'] %}
pull_{{ model | replace('.', '_') | replace(':', '_') | replace('-', '_') }}:
  cmd.run:
    - name: >-
        curl -sf --max-time 600
        -X POST http://127.0.0.1:11434/api/pull
        -d '{"name": "{{ model }}", "stream": false}'
    - unless: >-
        curl -sf http://127.0.0.1:11434/api/tags |
        grep -q '"{{ model }}"'
    - timeout: 600
    - require:
      - cmd: ollama_start
      - cmd: ollama_selinux_network
{% endfor %}

# --- openclaw (local AI assistant agent) ---
install_openclaw:
  cmd.run:
    - name: npm install -g openclaw
    - runas: neg
    - creates: /var/home/neg/.npm-global/bin/openclaw

# --- rofi-pass (password-store rofi frontend) ---
install_rofi_pass:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://raw.githubusercontent.com/carnager/rofi-pass/master/rofi-pass -o ~/.local/bin/rofi-pass
        chmod +x ~/.local/bin/rofi-pass
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/rofi-pass

# --- Theme packages not in Fedora repos ---
install_kora_icons:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsSL https://api.github.com/repos/bikass/kora/releases/latest | jq -r .tag_name)
        curl -fsSL "https://github.com/bikass/kora/archive/refs/tags/${TAG}.tar.gz" -o /tmp/kora.tar.gz
        tar -xzf /tmp/kora.tar.gz -C /tmp
        mkdir -p ~/.local/share/icons
        cp -r /tmp/kora-*/kora ~/.local/share/icons/
        cp -r /tmp/kora-*/kora-light ~/.local/share/icons/
        cp -r /tmp/kora-*/kora-light-panel ~/.local/share/icons/
        cp -r /tmp/kora-*/kora-pgrey ~/.local/share/icons/
        gtk-update-icon-cache ~/.local/share/icons/kora 2>/dev/null || true
        rm -rf /tmp/kora.tar.gz /tmp/kora-*
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/share/icons/kora

install_flight_gtk_theme:
  cmd.run:
    - name: |
        set -eo pipefail
        git clone --depth=1 https://github.com/neg-serg/Flight-Plasma-Themes.git /tmp/flight-gtk
        mkdir -p ~/.local/share/themes
        cp -r /tmp/flight-gtk/Flight-Dark-GTK ~/.local/share/themes/
        cp -r /tmp/flight-gtk/Flight-light-GTK ~/.local/share/themes/
        rm -rf /tmp/flight-gtk
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/share/themes/Flight-Dark-GTK

# --- MPV scripts (installed per-user, not in Fedora repos) ---
install_mpv_scripts:
  cmd.run:
    - name: |
        set -eo pipefail
        SCRIPTS_DIR=~/.config/mpv/scripts
        mkdir -p "$SCRIPTS_DIR"
        # uosc (modern UI)
        TAG=$(curl -fsSL https://api.github.com/repos/tomasklaen/uosc/releases/latest | jq -r .tag_name)
        curl -fsSL "https://github.com/tomasklaen/uosc/releases/download/${TAG}/uosc.zip" -o /tmp/uosc.zip
        unzip -qo /tmp/uosc.zip -d ~/.config/mpv/
        rm /tmp/uosc.zip
        # thumbfast
        curl -fsSL https://raw.githubusercontent.com/po5/thumbfast/master/thumbfast.lua -o "$SCRIPTS_DIR/thumbfast.lua"
        # sponsorblock
        curl -fsSL https://raw.githubusercontent.com/po5/mpv_sponsorblock/master/sponsorblock.lua -o "$SCRIPTS_DIR/sponsorblock.lua"
        # quality-menu
        curl -fsSL https://raw.githubusercontent.com/christoph-heinrich/mpv-quality-menu/master/quality-menu.lua -o "$SCRIPTS_DIR/quality-menu.lua"
        # mpris
        TAG=$(curl -fsSL https://api.github.com/repos/hoyon/mpv-mpris/releases/latest | jq -r .tag_name)
        curl -fsSL "https://github.com/hoyon/mpv-mpris/releases/download/${TAG}/mpris.so" -o "$SCRIPTS_DIR/mpris.so"
        # cutter
        curl -fsSL https://raw.githubusercontent.com/rushmj/mpv-video-cutter/master/cutter.lua -o "$SCRIPTS_DIR/cutter.lua"
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.config/mpv/scripts/thumbfast.lua

# --- Systemd user services for media ---
# Remove legacy custom mpdris2.service (replaced by drop-in for RPM unit)
mpdris2_legacy_cleanup:
  file.absent:
    - name: /var/home/neg/.config/systemd/user/mpdris2.service

# Drop-in override for RPM-shipped mpDris2.service: adds MPD ordering
mpdris2_user_service:
  file.managed:
    - name: /var/home/neg/.config/systemd/user/mpDris2.service.d/override.conf
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        After=mpd.service
        Wants=mpd.service

mpdris2_daemon_reload:
  cmd.run:
    - name: systemctl --user daemon-reload
    - runas: neg
    - env:
      - XDG_RUNTIME_DIR: /run/user/1000
    - onchanges:
      - file: mpdris2_user_service

chezmoi_config:
  file.managed:
    - name: /var/home/neg/.config/chezmoi/chezmoi.toml
    - source: salt://dotfiles/dot_config/chezmoi/chezmoi.toml
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True

chezmoi_source_symlink:
  file.symlink:
    - name: /var/home/neg/.local/share/chezmoi
    - target: /var/home/neg/src/salt/dotfiles
    - user: neg
    - group: neg
    - force: True
    - makedirs: True
    - require:
      - user: user_neg
      - file: chezmoi_config

# --- Mail directories (needed by mbsync) ---
mail_directories:
  file.directory:
    - names:
      - /var/home/neg/.local/mail/gmail/INBOX
      - /var/home/neg/.local/mail/gmail/[Gmail]/Sent Mail
      - /var/home/neg/.local/mail/gmail/[Gmail]/Drafts
      - /var/home/neg/.local/mail/gmail/[Gmail]/All Mail
      - /var/home/neg/.local/mail/gmail/[Gmail]/Trash
      - /var/home/neg/.local/mail/gmail/[Gmail]/Spam
    - user: neg
    - group: neg
    - makedirs: True

# --- Systemd user services for mail ---
mbsync_gmail_service:
  file.managed:
    - name: /var/home/neg/.config/systemd/user/mbsync-gmail.service
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Mailbox synchronization (Gmail)
        After=network-online.target
        Wants=network-online.target
        [Service]
        Type=oneshot
        ExecStart=/usr/bin/mbsync gmail
        [Install]
        WantedBy=default.target

mbsync_gmail_timer:
  file.managed:
    - name: /var/home/neg/.config/systemd/user/mbsync-gmail.timer
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Mailbox synchronization timer (Gmail)
        [Timer]
        OnBootSec=2min
        OnUnitActiveSec=10min
        [Install]
        WantedBy=timers.target

imapnotify_gmail_service:
  file.managed:
    - name: /var/home/neg/.config/systemd/user/imapnotify-gmail.service
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=IMAP IDLE notifications (Gmail)
        After=network-online.target
        Wants=network-online.target
        [Service]
        ExecStart=/usr/bin/goimapnotify -conf %h/.config/imapnotify/gmail.json
        Restart=on-failure
        RestartSec=30
        [Install]
        WantedBy=default.target

# --- Systemd user services for calendar ---
vdirsyncer_service:
  file.managed:
    - name: /var/home/neg/.config/systemd/user/vdirsyncer.service
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Synchronize calendars and contacts (vdirsyncer)
        After=network-online.target
        Wants=network-online.target
        [Service]
        Type=oneshot
        ExecStart=/usr/bin/vdirsyncer sync

vdirsyncer_timer:
  file.managed:
    - name: /var/home/neg/.config/systemd/user/vdirsyncer.timer
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Synchronize calendars and contacts timer
        [Timer]
        OnBootSec=2min
        OnUnitActiveSec=5min
        [Install]
        WantedBy=timers.target

# --- Surfingkeys HTTP server (browser extension helper) ---
surfingkeys_server_service:
  file.managed:
    - name: /var/home/neg/.config/systemd/user/surfingkeys-server.service
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Surfingkeys HTTP server (browser extension helper)
        After=graphical-session.target
        PartOf=graphical-session.target
        [Service]
        ExecStart=%h/.local/bin/surfingkeys-server
        Restart=on-failure
        RestartSec=5
        [Install]
        WantedBy=graphical-session.target

# --- Enable user services: single daemon-reload + batch enable ---
enable_user_services:
  cmd.run:
    - name: |
        systemctl --user daemon-reload
        systemctl --user enable imapnotify-gmail.service surfingkeys-server.service gpg-agent.socket gpg-agent-ssh.socket
        systemctl --user enable --now mbsync-gmail.timer vdirsyncer.timer
    - runas: neg
    - env:
      - XDG_RUNTIME_DIR: /run/user/1000
      - DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/1000/bus
    - unless: |
        systemctl --user is-enabled imapnotify-gmail.service 2>/dev/null &&
        systemctl --user is-enabled mbsync-gmail.timer 2>/dev/null &&
        systemctl --user is-enabled vdirsyncer.timer 2>/dev/null &&
        systemctl --user is-enabled surfingkeys-server.service 2>/dev/null &&
        systemctl --user is-enabled gpg-agent-ssh.socket 2>/dev/null
    - require:
      - file: imapnotify_gmail_service
      - file: mbsync_gmail_timer
      - file: vdirsyncer_timer
      - file: surfingkeys_server_service

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
