# Nix-Only & Hard-to-Port Utilities

Packages from `nixos-config` that required special effort to install on Fedora Atomic.
Most items have been resolved. See `states/system_description.sls` for the actual states.

## Resolved — Installation Method Used

| Package | Method | Salt State |
|---------|--------|------------|
| handlr-regex | `cargo install` | `install_handlr` |
| scdl | `pip install --user` | `install_scdl` |
| dr14_tmeter | `pip install --user DR14-T.meter` | `install_dr14_tmeter` |
| pzip | `cargo install` | `install_pzip` |
| asciinema-agg | `cargo install --git` | `install_agg` |
| tailray | `cargo install` | `install_tailray` |
| espanso | COPR `eclipseo/espanso` | `install_espanso` |
| himalaya | COPR `atim/himalaya` | `install_himalaya` |
| spotifyd | COPR `mbooth/spotifyd` | `install_spotifyd` |
| sbctl | COPR `chenxiaolong/sbctl` | `install_sbctl` |
| yabridge + yabridgectl | COPR `patrickl/yabridge-stable` | `install_yabridge` |
| brutefir | COPR `ycollet/linuxmao` (Audinux) | `install_audinux_packages` |
| patchmatrix | COPR `ycollet/linuxmao` (Audinux) | `install_audinux_packages` |
| sc3-plugins | COPR `ycollet/linuxmao` (Audinux) | `install_audinux_packages` |
| below | Fedora RPM (categories dict) | `install_system_packages` |
| kernel-tools | Fedora RPM (categories dict) | `install_system_packages` |
| media-player-info | Fedora RPM (categories dict) | `install_system_packages` |
| jamesdsp | Flatpak `me.timschneeberger.jdsp4linux` | `install_flatpak_jamesdsp` |
| protonplus | Flatpak `com.vysp3r.ProtonPlus` | `install_flatpak_protonplus` |
| xray | GitHub binary (zip) | `install_xray` |
| sing-box | GitHub binary (tar.gz) | `install_sing_box` |
| tdl | GitHub binary (tar.gz) | `install_tdl` |
| camilladsp | GitHub binary (tar.gz) | `install_camilladsp` |
| opencode | GitHub binary (tar.gz) | `install_opencode` |
| adguardian | GitHub binary (direct) | `install_adguardian` |
| realesrgan-ncnn-vulkan | GitHub binary (zip) | `install_realesrgan` |
| essentia-extractor | Static binary (essentia.upf.edu) | `install_essentia_extractor` |
| roomeqwizard | Java app (direct download) | `install_roomeqwizard` |
| mpvc | Shell script (GitHub raw) | `install_mpvc` |
| rofi-systemd | Shell script (GitHub raw) | `install_rofi_systemd` |
| dool | Git clone + copy | `install_dool` |
| qmk-udev-rules | Udev rules file (GitHub raw) | `install_qmk_udev_rules` |
| oldschool-pc-font-pack | Font archive (int10h.org) | `install_oldschool_pc_fonts` |
| newsraft | Custom RPM build | `build_newsraft_rpm` |
| hy3 | Podman build (hy3.sls) | `build_hy3` |
| throne | GitHub zip (bundled Qt) | `install_throne` |
| overskride | Flatpak bundle (GitHub) | `install_overskride` |
| opensoundmeter | AppImage (GitHub) | `install_opensoundmeter` |
| unflac | Custom RPM build (Go) | `build_unflac_rpm` |
| matugen | Prebuilt binary (GitHub) | `install_matugen` |
| matugen-themes | Git clone templates | `install_matugen_themes` |
| droidcam | akmod-v4l2loopback + binary | `install_v4l2loopback` + `install_droidcam` |

## Skipped — Not Needed

| Package | Reason |
|---------|--------|
| spotify-tui | Abandoned (2021), broken Spotify API |
| wireless-tools | Deprecated; `iw` is the modern replacement |
| update-resolv-conf | Fedora uses systemd-resolved |
| read-edid | Use `edid-decode`; `ddcutil` already installed |
| cider | Paid app; Apple Music only |
| beautifulsoup4 | Python library, not a standalone tool |
| pynvim | Already present via pip |
| fontforge | Not needed |
| fonttools | Not needed |

## Still Pending

| Package | Issue | Notes |
|---------|-------|-------|
| winapps | Manual setup | Windows apps in KVM; complex, not automatable |
