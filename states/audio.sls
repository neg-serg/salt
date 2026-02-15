# PipeWire audio stack — ensures all runtime components are installed
# On Arch/CachyOS, pipewire is a bare daemon; audio modules are separate packages
{% from '_macros.jinja' import pacman_install %}

{{ pacman_install('pipewire-audio', 'pipewire-audio', check='pipewire-audio') }}
{{ pacman_install('wireplumber', 'wireplumber') }}
{{ pacman_install('pipewire-pulse', 'pipewire-pulse') }}
{{ pacman_install('pipewire-alsa', 'pipewire-alsa') }}
{{ pacman_install('pipewire-jack', 'pipewire-jack') }}
