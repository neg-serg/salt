# Package installation via rpm-ostree
# Salt state for installing system packages on Fedora Silverblue
# Packages in Wayblue base image (do NOT layer): rust, ImageMagick

# Core build dependencies
install_build_deps:
  cmd.run:
    - name: rpm-ostree install --idempotent --allow-inactive mpc cargo pipewire-devel clang-libs gcc g++ cmake ncurses-devel pulseaudio-libs-devel
    - unless: rpm -q cargo gcc cmake
    - runas: root

# Dev tools
install_dev_tools:
  cmd.run:
    - name: rpm-ostree install --idempotent --allow-inactive ShellCheck shfmt strace gdb hyperfine git-crypt git-extras diff-so-fancy onefetch
    - unless: rpm -q ShellCheck shfmt strace gdb hyperfine git-crypt git-extras diff-so-fancy onefetch
    - runas: root

# CLI utilities
install_cli_utilities:
  cmd.run:
    - name: rpm-ostree install --idempotent --allow-inactive ugrep aria2 jc yq glow lowdown moreutils rlwrap expect dcfldd prettyping speedtest-cli urlscan abduco cpufetch sad pastel miller
    - unless: rpm -q ugrep aria2 jc yq glow lowdown moreutils rlwrap expect dcfldd prettyping speedtest-cli urlscan abduco cpufetch sad pastel miller
    - runas: root

# Archives & compression
install_archive_tools:
  cmd.run:
    - name: rpm-ostree install --idempotent --allow-inactive pigz pbzip2 lbzip2 unar unrar patool
    - unless: rpm -q pigz pbzip2 lbzip2 unar unrar patool
    - runas: root

# Media & images
install_media_tools:
  cmd.run:
    - name: rpm-ostree install --idempotent --allow-inactive ffmpegthumbnailer mediainfo jpegoptim optipng pngquant advancecomp darktable rawtherapee swayimg
    - unless: rpm -q ffmpegthumbnailer mediainfo jpegoptim optipng pngquant advancecomp darktable rawtherapee swayimg
    - runas: root

# Backup & file management
install_file_tools:
  cmd.run:
    - name: rpm-ostree install --idempotent --allow-inactive borgbackup jdupes enca streamlink
    - unless: rpm -q borgbackup jdupes enca python3-streamlink
    - runas: root
