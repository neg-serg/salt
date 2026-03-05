# PipeWire audio stack — ensures all runtime components are installed
# On Arch/CachyOS, pipewire is a bare daemon; audio modules are separate packages
{% from '_macros_pkg.jinja' import pacman_install %}

{% for pkg in ['pipewire-audio', 'wireplumber', 'pipewire-pulse', 'pipewire-alsa', 'pipewire-jack', 'alsa-utils', 'playerctl'] %}
{{ pacman_install(pkg, pkg) }}
{% endfor %}
