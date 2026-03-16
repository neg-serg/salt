# PipeWire audio stack — ensures all runtime components are installed
# On Arch/CachyOS, pipewire is a bare daemon; audio modules are separate packages
{% from '_macros_pkg.jinja' import pacman_install %}

{% for pkg in ['pipewire-audio', 'wireplumber', 'pipewire-pulse', 'pipewire-alsa', 'pipewire-jack', 'alsa-utils', 'playerctl'] %}
{{ pacman_install(pkg, pkg) }}
{% endfor %}

# Prevent snd-aloop from being re-added by droidcam package updates.
# PipeWire native loopback replaces all snd-aloop functionality;
# snd-aloop creates pro-output nodes that race with USB audio (RME) at startup.
snd_aloop_strip_droidcam:
  file.replace:
    - name: /etc/modules-load.d/droidcam.conf
    - pattern: '^snd-aloop\n?'
    - repl: ''
    - onlyif: test -f /etc/modules-load.d/droidcam.conf
