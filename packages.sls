# Package installation via rpm-ostree
# Salt state for installing system packages on Fedora Silverblue

{% set user = 'neg' %}
{% set home = '/var/home/' ~ user %}

# Core packages for development and media
install_base_packages:
  cmd.run:
    - name: rpm-ostree install --idempotent mpc cargo rust pipewire-devel clang-libs gcc g++ cmake ncurses-devel pulseaudio-libs-devel
    - unless: rpm -q mpc cargo rust

# Note: --apply-live is not used here as it requires reboot for full effect
# Run `rpm-ostree apply-live` manually or reboot after applying this state
