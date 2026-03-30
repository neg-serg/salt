# X11/Xorg VR session user (xen)
# i3 + KDE Plasma X11 sessions for SteamVR with Valve Index on AMD GPU.
# Two session options via greetd:
#   - "Xorg VR (i3 + SteamVR)" — minimal i3, auto-launches Steam bigpicture
#   - "Plasma (X11)" — full KDE desktop with Breeze Dark theme

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

# ── KDE Plasma X11 packages ───────────────────────────────────────
# plasma-desktop: core KDE shell; plasma-workspace: startplasma-x11;
# breeze: dark theme + icons; konsole: terminal emulator
{{ pacman_install('plasma_desktop', 'plasma-desktop plasma-workspace') }}
{{ pacman_install('breeze_theme', 'breeze breeze-icons') }}
{{ pacman_install('konsole', 'konsole') }}

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

{% set xen_hash = '$6$.Lgp.hRSogsdPLMm$uNMG6YZSAPsy7svfTwKtYY/x.UyCeYYMNKQeGcqTGQtphPbddP0yu5DCx2I..ysObFRHxnamOvcesFH15pc0f/' %}
xen_password:
  cmd.run:
    - name: usermod -p '{{ xen_hash }}' {{ xen_user }}
    - unless: getent shadow {{ xen_user }} | grep -q '{{ xen_hash }}'
    - require:
      - user: xen_user

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

# ── Session .desktop files for greetd ──────────────────────────────
xen_vr_session_desktop:
  file.managed:
    - name: /usr/share/xsessions/xen-vr.desktop
    - user: root
    - group: root
    - mode: '0644'
    - contents: |
        [Desktop Entry]
        Name=Xorg VR (i3 + SteamVR)
        Comment=X11 session for Valve Index VR with i3
        Exec=startx
        Type=XSession
        DesktopNames=i3

# plasma-workspace only ships wayland session; add X11 variant for xen
xen_plasma_x11_session_desktop:
  file.managed:
    - name: /usr/share/xsessions/plasma-x11.desktop
    - user: root
    - group: root
    - mode: '0644'
    - contents: |
        [Desktop Entry]
        Name=Plasma (X11)
        Comment=KDE Plasma Desktop on Xorg
        Exec=startplasma-x11
        TryExec=startplasma-x11
        Type=XSession
        DesktopNames=KDE

# ── KDE Breeze Dark theme for xen ─────────────────────────────────
{{ ensure_dir('xen_kde_config_dir', xen_home ~ '/.config', user=xen_user) }}

# Global KDE settings: Breeze Dark color scheme, dark Plasma theme
xen_kdeglobals:
  file.managed:
    - name: {{ xen_home }}/.config/kdeglobals
    - user: {{ xen_user }}
    - group: {{ xen_user }}
    - mode: '0644'
    - replace: False
    - contents: |
        [General]
        ColorScheme=BreezeDark
        WidgetStyle=Breeze

        [KDE]
        LookAndFeelPackage=org.kde.breezedark.desktop
        widgetStyle=Breeze

        [Icons]
        Theme=breeze-dark
    - require:
      - user: xen_user
      - file: xen_kde_config_dir

# Plasma shell: use Breeze Dark look-and-feel
xen_plasmarc:
  file.managed:
    - name: {{ xen_home }}/.config/plasmarc
    - user: {{ xen_user }}
    - group: {{ xen_user }}
    - mode: '0644'
    - replace: False
    - contents: |
        [Theme]
        name=breeze-dark
    - require:
      - user: xen_user
      - file: xen_kde_config_dir

# KWin: dark window decorations
xen_kwinrc:
  file.managed:
    - name: {{ xen_home }}/.config/kwinrc
    - user: {{ xen_user }}
    - group: {{ xen_user }}
    - mode: '0644'
    - replace: False
    - contents: |
        [org.kde.kdecoration2]
        library=org.kde.breeze
        theme=Breeze
    - require:
      - user: xen_user
      - file: xen_kde_config_dir

# Konsole: dark profile
{{ ensure_dir('xen_konsole_dir', xen_home ~ '/.local/share/konsole', user=xen_user) }}

xen_konsole_profile:
  file.managed:
    - name: {{ xen_home }}/.local/share/konsole/VR.profile
    - user: {{ xen_user }}
    - group: {{ xen_user }}
    - mode: '0644'
    - replace: False
    - contents: |
        [Appearance]
        ColorScheme=Breeze
        Font=Iosevka,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1

        [General]
        Name=VR
        Parent=FALLBACK/
    - require:
      - file: xen_konsole_dir

xen_konsolerc:
  file.managed:
    - name: {{ xen_home }}/.config/konsolerc
    - user: {{ xen_user }}
    - group: {{ xen_user }}
    - mode: '0644'
    - replace: False
    - contents: |
        [Desktop Entry]
        DefaultProfile=VR.profile
    - require:
      - user: xen_user
      - file: xen_kde_config_dir

# ── TTY3 for xen login (emergency fallback) ───────────────────────
xen_getty_tty3:
  service.enabled:
    - name: getty@tty3
