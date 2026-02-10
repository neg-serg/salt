# Nix-Only & Hard-to-Port Utilities

Packages from `nixos-config` that don't have straightforward Fedora equivalents.
These require special effort (custom RPM build, cargo/pip install, or are truly
Nix-specific). Organized by installation difficulty.

## Easy: pip / cargo install

| Package | Type | Install Command | Notes |
|---------|------|-----------------|-------|
| beautifulsoup4 | Python | `pip install --user beautifulsoup4` | Web scraping lib |
| pynvim | Python | `pip install --user pynvim` | Neovim Python bindings (for nvr) |
| fonttools | Python | `pip install --user fonttools` | Font manipulation |
| fontforge | Python | `dnf install fontforge` | Check if Python bindings included |
| handlr-regex | Rust | `cargo install handlr-regex` | xdg-open replacement; also has GitHub binary |
| scdl | Python | `pip install --user scdl` | SoundCloud downloader |

## Medium: GitHub Binary / AppImage

| Package | Source | Notes |
|---------|--------|-------|
| espanso | [espanso.org](https://espanso.org) | AppImage available; text expansion daemon |
| below | [github.com/facebookincubator/below](https://github.com/facebookincubator/below) | BPF-based system monitor; has releases |
| realesrgan-ncnn-vulkan | [github.com/xinntao/Real-ESRGAN-ncnn-vulkan](https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan) | GPU image upscaler; prebuilt Linux binary |
| xray | [github.com/XTLS/Xray-core](https://github.com/XTLS/Xray-core) | VLESS/Reality proxy; Go binary |
| sing-box | [github.com/SagerNet/sing-box](https://github.com/SagerNet/sing-box) | Universal proxy platform; Go binary |
| tdl | [github.com/iyear/tdl](https://github.com/iyear/tdl) | Telegram downloader; Go binary |
| spotifyd | [github.com/Spotifyd/spotifyd](https://github.com/Spotifyd/spotifyd) | Spotify daemon; Rust, has releases |
| himalaya | [github.com/pimalaya/himalaya](https://github.com/pimalaya/himalaya) | Async email CLI; Rust, has releases |
| droidcam | [dev47apps.com](https://www.dev47apps.com) | Phone as webcam; proprietary installer |

## Hard: Custom RPM Build Needed

| Package | Language | Complexity | Notes |
|---------|----------|------------|-------|
| asciinema-agg | Rust | Low | GIF renderer for asciinema recordings |
| unflac | Go | Low | FLAC cuesheet splitter |
| mpvc | Shell/C | Low | mpv IPC controller |
| pzip | Rust | Low | Parallel zip implementation |
| dr14_tmeter | Python | Low | Dynamic range measurement |
| camilladsp | Rust | Medium | Flexible audio DSP pipeline |
| brutefir | C | Medium | Digital convolution engine |
| jamesdsp | C++ | Medium | Audio effect processor (EQ, bass boost) |
| opensoundmeter | Qt/C++ | Medium | FFT acoustic analysis |
| roomeqwizard | Java | Medium | Acoustic measurement (JAR, not RPM) |

## Complex: Build System / Dependencies

| Package | Issue | Notes |
|---------|-------|-------|
| yabridge + yabridgectl | Wine + VST bridge | Complex C++ build with Wine deps; bridges Windows VST plugins |
| supercolliderPlugins.sc3-plugins | CMake + SuperCollider SDK | Needs SC source headers to build |
| essentia-extractor | C++ + many deps | MIR audio feature extraction; complex build |
| patchmatrix | JACK + LV2 | JACK patchbay matrix; niche audio routing |

## Low Priority / Questionable Need

| Package | Reason |
|---------|--------|
| sbctl | Secure Boot debugging; only needed if using Secure Boot with custom keys |
| turbostat | Kernel power tool; usually in `kernel-tools` RPM |
| adguardian | Only useful with AdGuard Home server |
| media-player-info | udev hardware DB; may already be in base image |
| matugen-themes | Template pack for matugen; check if bundled with binary |
| oldschool-pc-font-pack | Retro PC fonts; cosmetic |
| cider | Apple Music client; proprietary/paid |
| spotify-tui | Unmaintained; superseded by other tools |
| protonplus | Proton prefix manager; ProtonUp-Qt already installed as Flatpak |
| dool | dstat replacement; `sysstat` covers most use cases |
| overskride | Bluetooth OBEX client; `bluez-tools` covers basics |
| wirelesstools | iwconfig helpers; `iw` from base image is modern replacement |
| read-edid | EDID reader; `ddcutil` already installed |
| qmk-udev-rules | Only needed with QMK keyboards |
| update-resolv-conf | OpenVPN DNS helper; NetworkManager handles this |
| throne | VPN proxy; niche |
| opencode | AI coding agent; experimental |
| rofi-systemd | systemd picker for rofi; low priority |

## Flake Inputs (External Nix Sources)

| Input | Status | Notes |
|-------|--------|-------|
| hy3 | Not installed | Hyprland i3-like layout plugin; check if COPR available |
| winapps | Not set up | Windows apps in KVM; complex setup |
| tailray | Not installed | Tailscale + xray integration |
