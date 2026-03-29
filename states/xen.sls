# X11/Xorg VR session user (xen)
# Minimal i3 + Xorg setup for SteamVR with Valve Index on AMD GPU.
# Login via getty on VT3: `Ctrl+Alt+F3 → xen → startx`

{% from '_imports.jinja' import host, user, home %}
{% from '_macros_pkg.jinja' import pacman_install %}
{% from '_macros_service.jinja' import ensure_dir %}

{% set xen_user = 'xen' %}
{% set xen_uid = 1100 %}
{% set xen_home = '/home/' ~ xen_user %}

include:
  - users

# ── Xorg + i3 packages ──────────────────────────────────────────────
{{ pacman_install('xorg_server', 'xorg-server xorg-xinit xf86-video-amdgpu') }}
{{ pacman_install('i3_wm', 'i3-wm i3status') }}

# ── User account ────────────────────────────────────────────────────
xen_group:
  group.present:
    - name: {{ xen_user }}
    - gid: {{ xen_uid }}

xen_user:
  user.present:
    - name: {{ xen_user }}
    - shell: /usr/bin/zsh
    - uid: {{ xen_uid }}
    - gid: {{ xen_uid }}
    - home: {{ xen_home }}
    - createhome: True
    - failhard: True
    - require:
      - group: xen_group

# video+render: GPU access; input: VR controllers; uucp: Valve Index USB
xen_groups:
  cmd.run:
    - name: usermod -aG video,render,input,plugdev,uucp {{ xen_user }}
    - unless: id -nG {{ xen_user }} | grep -qw uucp
    - require:
      - user: xen_user
      - group: plugdev_group

# ── Shared Steam library access ────────────────────────────────────
# Add both users to a shared 'steam' group so xen can read neg's Steam files
xen_steam_group:
  group.present:
    - name: steam
    - members:
      - {{ user }}
      - {{ xen_user }}
    - require:
      - user: xen_user

# Symlink neg's Steam library into xen's home
{{ ensure_dir('xen_local_share', xen_home ~ '/.local/share', user=xen_user) }}

xen_steam_symlink:
  file.symlink:
    - name: {{ xen_home }}/.local/share/Steam
    - target: {{ home }}/.local/share/Steam
    - user: {{ xen_user }}
    - group: {{ xen_user }}
    - force: True
    - require:
      - file: xen_local_share
      - user: xen_user

# Set group-readable permissions on neg's Steam directory
xen_steam_acl:
  cmd.run:
    - name: |
        setfacl -R -m g:steam:rX {{ home }}/.local/share/Steam 2>/dev/null || true
        setfacl -R -d -m g:steam:rX {{ home }}/.local/share/Steam 2>/dev/null || true
    - unless: getfacl {{ home }}/.local/share/Steam 2>/dev/null | grep -q 'group:steam:r'
    - require:
      - group: xen_steam_group
    - onlyif: test -d {{ home }}/.local/share/Steam

# ── .xinitrc: start i3 on startx ───────────────────────────────────
xen_xinitrc:
  file.managed:
    - name: {{ xen_home }}/.xinitrc
    - user: {{ xen_user }}
    - group: {{ xen_user }}
    - mode: '0755'
    - contents: |
        #!/bin/sh
        # Valve Index VR session — i3 + SteamVR
        export XDG_SESSION_TYPE=x11

        # AMD GPU: use RADV Vulkan driver
        export AMD_VULKAN_ICD=RADV
        export RADV_PERFTEST=gpl

        exec i3
    - require:
      - user: xen_user

# ── Minimal i3 config (auto-launch Steam) ──────────────────────────
{{ ensure_dir('xen_i3_config_dir', xen_home ~ '/.config/i3', user=xen_user) }}

xen_i3_config:
  file.managed:
    - name: {{ xen_home }}/.config/i3/config
    - user: {{ xen_user }}
    - group: {{ xen_user }}
    - mode: '0644'
    - contents: |
        # i3 config for VR session (xen user)
        set $mod Mod4

        # Basic keybindings
        bindsym $mod+Return exec xterm
        bindsym $mod+Shift+q kill
        bindsym $mod+Shift+e exec i3-nagbar -t warning -m 'Exit i3?' -B 'Yes' 'i3-msg exit'

        # Launch Steam on startup
        exec --no-startup-id steam -bigpicture
    - require:
      - file: xen_i3_config_dir

# ── TTY3 for xen login ─────────────────────────────────────────────
xen_getty_tty3:
  service.enabled:
    - name: getty@tty3
