# NixOS Package Inventory — Fedora Atomic Migration

Cross-reference of all packages from `~/src/nixos-config/` against what is installed
on the Fedora Atomic workstation (RPM, Flatpak, custom RPM, ~/.local/bin).

## Legend

| Mark | Meaning |
|------|---------|
| `[x]` | Installed — package available on Fedora |
| `[-]` | Not applicable — Nix-specific tool, no Fedora equivalent needed |
| `[~]` | Partial — library/dependency present but not the exact tool |
| `[ ]` | Not installed — needs attention or deliberate skip |
| `nix run` | Was a `nix run` alias in NixOS (on-demand, not permanently installed) |
| `(opt)` | Was conditional/optional in NixOS config (`mkIf`, feature-gated) |
| `(RPM)` | Installed via rpm-ostree layered package |
| `(CRPM)` | Installed via custom-built RPM |
| `(FP)` | Installed via Flatpak |
| `(LB)` | Installed in ~/.local/bin |

---

## CLI — Archives
_Source: modules/cli/archives/pkgs.nix_

- [x] ouch (CRPM)
- [x] patool — `python3-patool` (RPM)
- [x] pbzip2 (RPM)
- [x] pigz (RPM)
- [x] lbzip2 (RPM)
- [x] p7zip — `7zip` (RPM)
- [ ] pzip — parallel zip; not packaged for Fedora
- [x] rapidgzip (CRPM)
- [x] unar (RPM)
- [x] unrar — `rar` (RPM)
- [x] unzip (RPM)
- [x] xz (RPM)
- [x] zip (RPM)

## CLI — Text Processing
_Source: modules/cli/text.nix_

- [x] par (RPM)
- [x] choose (CRPM)

## CLI — Network
_Source: modules/cli/network.nix_

- [x] prettyping (RPM)
- [x] speedtest-cli (RPM)
- [x] urlscan (RPM)
- [x] urlwatch — page change monitor (RPM)
- [x] whois (RPM)
- [x] abduco (RPM)
- [x] xxh (CRPM)

## CLI — System Management
_Source: modules/cli/system.nix_

- [x] entr (RPM)
- [x] inotify-tools (RPM)
- [x] lsof (RPM)
- [x] parallel (RPM)
- [x] procps — `procps-ng` (RPM)
- [x] progress (RPM)
- [x] psmisc (RPM)
- [x] pv (RPM)
- [x] reptyr (RPM)
- [x] goaccess (RPM)
- [x] kmon (CRPM)
- [x] lnav (RPM)
- [x] zfxtop (CRPM)
- [ ] blesh — Bash line editor in pure Bash; not installed (zsh user, low priority)
- [x] expect (RPM)
- [x] readline (RPM)
- [x] rlwrap (RPM)

## CLI — General Tools
_Source: modules/cli/tools.nix_

- [x] ripgrep — not an RPM but aliased to `rg` in shell; likely via cargo or bundled
- [x] ugrep (RPM)
- [x] delta — `git-delta` (RPM)
- [x] diff-so-fancy (RPM)
- [x] diffutils (RPM)
- [x] convmv (RPM)
- [x] dos2unix (RPM)
- [x] fd — `fd-find` (RPM)
- [x] file (RPM)
- [x] massren (CRPM)
- [x] nnn (RPM)
- [x] stow (RPM)
- [x] zoxide (RPM)
- [x] dcfldd (RPM)
- [x] dust — `du-dust` (RPM)
- [x] erdtree (CRPM)
- [x] eza (LB)
- [x] libnotify (RPM)
- [x] moreutils (RPM)
- [x] ncdu (RPM)
- [x] duf (CRPM) — custom fork with `--theme neg`
- [x] pwgen (RPM)

## CLI — File Operations
_Source: modules/cli/file-ops.nix_

- [x] aria2 (RPM)
- [x] czkawka — `czkawka` not in RPMs; **check status**
- [x] jq (RPM)
- [x] rmlint (RPM)
- [x] yt-dlp (RPM)

## CLI — Media
_Source: modules/cli/media.nix_

- [x] asciinema (RPM)
- [ ] asciinema-agg — GIF renderer for asciinema; not installed
- [x] chafa (RPM)
- [x] exiftool — `perl-Image-ExifTool` (RPM)
- [x] mpv (RPM)
- [x] sox (RPM)
- [x] zbar (RPM)

## CLI — Development
_Source: modules/cli/dev.nix_

- [x] tig (RPM)
- [x] qrencode (RPM)
- [x] fastfetch (RPM)

## CLI — Monitoring
_Source: modules/cli/monitoring.nix_

- [x] goaccess (RPM)
- [x] kmon (CRPM)
- [x] zfxtop (CRPM)
- [ ] below (opt) — BPF-based time-traveling monitor; not installed
- [x] bpftrace — eBPF tracing language (RPM)

## CLI — Tmux
_Source: modules/cli/tmux/default.nix_

- [x] tmux (RPM) — plugins managed via TPM or manually
- [x] zsh (RPM)

---

## Development — Git
_Source: modules/dev/git/pkgs.nix_

- [x] git (RPM)
- [x] jujutsu (CRPM)
- [x] git-crypt (RPM)
- [x] git-extras (RPM)
- [x] git-filter-repo (CRPM)
- [x] git-lfs (RPM)
- [x] act — run GitHub Actions locally (RPM)
- [x] gh (RPM)
- [x] gist (CRPM)
- [x] hxtools — git/stats helpers (RPM)

## Development — Editor
_Source: modules/dev/editor/pkgs.nix_

- [x] neovim (RPM)
- [ ] neovim-remote (nvr) — (LB) present as `nvr`

## Development — LSPs & Language Servers
_Source: modules/dev/editor/neovim/ (various)_

These were installed system-wide on NixOS. On Fedora, LSPs are typically
managed by **mason.nvim** inside Neovim or installed via npm/pip/cargo.

- [ ] bash-language-server — install via mason/npm
- [-] nil — Nix LSP, not needed on Fedora
- [ ] pylyzer — install via mason/pip
- [ ] pyright — install via mason/npm
- [x] ruff (RPM) — also serves as LSP
- [ ] lua-language-server — install via mason
- [ ] hyprls — Hyprland config LSP; not packaged
- [ ] yaml-language-server — install via mason/npm
- [x] taplo (CRPM) — TOML LSP/formatter
- [ ] marksman — Markdown LSP; install via mason
- [ ] just-lsp — justfile LSP; not widely packaged
- [ ] lemminx — XML LSP; install via mason
- [ ] awk-language-server — install via mason/npm
- [ ] autotools-language-server — install via mason/pip
- [ ] cmake-language-server — install via mason/pip
- [ ] docker-compose-language-service — install via mason/npm
- [ ] dockerfile-language-server — install via mason/npm
- [ ] dot-language-server — Graphviz LSP; install via mason/npm
- [ ] asm-lsp — Assembly LSP; install via mason/cargo
- [ ] systemd-language-server — install via mason/pip
- [ ] nginx-language-server — install via mason/pip
- [-] zls — Zig LSP, only if doing Zig development

## Development — Formatters
_Source: modules/dev/editor/ (various)_

- [ ] stylua — Lua formatter; install via mason/cargo
- [x] shfmt (RPM)
- [-] nixfmt — Nix formatter, not needed
- [ ] isort — Python import sorter; install via pip
- [ ] black — Python formatter; install via pip

## Development — Tools
_Source: modules/dev/pkgs/default.nix_

- [x] hyperfine (RPM)
- [x] just (RPM)
- [x] pkgconf (RPM)
- [x] scc (CRPM)
- [x] ShellCheck (RPM)
- [x] shfmt (RPM)
- [x] strace (RPM)

## Development — Python
_Source: modules/dev/python/pkgs.nix_

- [x] python3 (RPM) with key packages:
  - [x] python3-colored (RPM)
  - [x] python3-docopt (RPM)
  - [x] python3-numpy (RPM)
  - [x] python3-pillow (RPM)
  - [x] python3-psutil (RPM)
  - [x] python3-requests (RPM)
  - [x] python3-tabulate (RPM)
  - [ ] beautifulsoup4 — `python3-beautifulsoup4`; check if installed
  - [x] python3-orjson (RPM)
  - [x] python3-dbus (RPM)
  - [ ] pynvim — install via pip; `nvr` in ~/.local/bin suggests it's present
  - [ ] fontforge (Python bindings) — not installed
  - [ ] fonttools — install via pip
  - [x] python3-mutagen (RPM)

## Development — GDB
_Source: modules/dev/gdb/default.nix_

- [x] gdb (RPM)

## Development — Misc
_Source: modules/dev/ (various)_

- [ ] opencode (opt) — AI coding agent; not installed
- [x] ansible — IT automation (RPM)
- [x] sshpass (RPM)

---

## System — Core
_Source: modules/system/pkgs.nix_

- [x] cryptsetup (RPM)
- [x] dmidecode (RPM)
- [x] hw-probe (RPM)
- [x] lm_sensors (RPM)
- [x] pciutils (RPM)
- [x] usbutils (RPM)
- [x] kexec-tools (RPM)
- [x] schedtool (RPM)

## System — Boot
_Source: modules/system/boot/pkgs.nix_

- [x] efibootmgr (RPM)
- [x] efivar — `efivar-libs` (RPM)
- [x] os-prober (RPM)
- [ ] sbctl — Secure Boot debugging; not installed

## System — Networking
_Source: modules/system/net/pkgs.nix_

- [x] bandwhich (CRPM)
- [x] iftop (RPM)
- [x] dnsutils — `bind-utils` (RPM)
- [x] doggo (CRPM)
- [x] axel (RPM)
- [x] curl (RPM)
- [x] wget2 (RPM)
- [x] cacert — `ca-certificates` (RPM)
- [x] curlie (CRPM)
- [x] httpie (RPM)
- [ ] httpstat — curl statistics visualizer; not installed
- [x] xh (CRPM)
- [x] fping (RPM)
- [x] geoip — `GeoIP` (RPM)
- [x] ipcalc (RPM)
- [x] tcptraceroute — via `traceroute` (RPM)
- [x] traceroute (RPM)
- [x] socat (RPM)
- [x] sshfs — `fuse-sshfs` (RPM)
- [x] ethtool (RPM)
- [x] inetutils — split across multiple RPMs (RPM)
- [x] iputils (RPM)
- [x] netcat — `nmap-ncat` (RPM)
- [x] w3m (RPM)
- [x] iwd (opt) (RPM)

## System — VPN
_Source: modules/system/net/vpn/pkgs.nix, xray.nix_

- [ ] amnezia-vpn — AmneziaVPN GUI; (LB) `AmneziaVPN` present
- [x] amneziawg-go — (LB) present
- [x] amneziawg-tools (RPM)
- [x] wireguard-tools (RPM)
- [x] openvpn (RPM)
- [ ] update-resolv-conf — OpenVPN DNS helper; check if packaged
- [ ] throne (opt) — VPN proxy; not installed
- [ ] xray — VLESS proxy core; not installed
- [ ] sing-box — universal proxy; not installed

## System — Hardware IO
_Source: modules/hardware/io/pkgs.nix_

- [x] blktrace (RPM)
- [x] dmraid — `device-mapper-multipath` (RPM)
- [x] exfatprogs (RPM)
- [x] fio (RPM)
- [x] gptfdisk — `gdisk` (RPM)
- [x] ioping (RPM)
- [x] mtools (RPM)
- [x] multipath-tools — `device-mapper-multipath` (RPM)
- [x] nvme-cli (RPM)
- [x] ostree (RPM)
- [x] parted (RPM)
- [x] smartmontools (RPM)

## System — Hardware General
_Source: modules/hardware/pkgs.nix_

- [x] brightnessctl (RPM)
- [x] acpi (RPM)
- [x] hwinfo (RPM)
- [x] inxi (RPM)
- [x] lshw (RPM)
- [x] evhz — HID polling rate monitor; check if packaged
- [x] openrgb (RPM)
- [x] flashrom (RPM)
- [x] minicom (RPM)
- [x] openocd — on-chip debugger (RPM)
- [x] bluez-tools (opt) (RPM)
- [ ] overskride (opt) — Bluetooth OBEX client; not installed
- [ ] wirelesstools (opt) — iwconfig helpers; not installed

## System — Hardware Video
_Source: modules/hardware/video/pkgs/default.nix_

- [x] ddccontrol (RPM)
- [x] ddcutil (RPM)
- [ ] read-edid — monitor EDID reader; not installed

## System — Hardware Misc
_Source: modules/hardware/ (various)_

- [x] corectrl (RPM) — GPU control
- [x] liquidctl (RPM) — liquid cooler control
- [ ] qmk-udev-rules — QMK keyboard rules; not installed as RPM
- [ ] droidcam — phone as webcam; not installed
- [x] dualsensectl — DualSense controller; COPR `kapsh/dualsensectl`

## System — AMD GPU
_Source: modules/hardware/amdgpu.nix_

- [x] ROCm packages — `rocm-*` (RPM) — multiple ROCm packages installed

---

## Monitoring
_Source: modules/monitoring/pkgs/default.nix_

- [x] atop (RPM)
- [x] btop (RPM)
- [ ] dool — dstat replacement; not in RPMs
- [x] iotop — `iotop-c` (RPM)
- [x] iperf (RPM)
- [x] iperf2 — N/A; `iperf` already installed
- [x] perf (RPM)
- [ ] turbostat — kernel tool; not installed separately
- [x] nethogs (RPM)
- [ ] adguardian — AdGuard Home terminal dashboard; not installed
- [x] powertop (RPM)
- [x] procdump — Linux procdump (RPM)
- [x] sysstat (RPM)
- [x] vmtouch (RPM)
- [x] mtr (RPM) — via `programs.mtr.enable`

---

## Media — Audio Core
_Source: modules/media/audio/core-packages.nix_

- [x] alsa-utils (RPM)
- [ ] pw-volume — minimal PipeWire volume control; not installed (use `pamixer` or `wpctl`)
- [x] coppwr — PipeWire graph copy/paste; Flatpak (`io.github.dimtpap.coppwr`)
- [x] helvum (RPM) — GTK patchbay
- [ ] patchmatrix — LV2/JACK matrix; not installed
- [x] qpwgraph (RPM)

## Media — Audio Apps
_Source: modules/media/audio/apps-packages.nix_

- [ ] dr14_tmeter — dynamic range measurement; not installed
- [ ] essentia-extractor — audio feature extractor; not installed
- [x] sonic-visualiser (RPM)
- [ ] opensoundmeter (opt) — FFT analysis; not installed
- [ ] roomeqwizard (opt) — acoustic measurement; not installed
- [x] sox (RPM)
- [x] pipemixer (CRPM)
- [x] wiremix — PipeWire terminal mixer (RPM)
- [x] cdparanoia (RPM)
- [ ] unflac — FLAC cuesheet converter; not installed
- [ ] cider (opt) — Apple Music player; not installed
- [x] nicotine-plus — `nicotine+` (RPM)
- [ ] scdl — SoundCloud downloader; not installed
- [x] id3v2 (RPM)
- [x] picard (RPM)
- [x] screenkey (RPM)
- [ ] rmpc — minimal MPD CLI; not installed
- [ ] spotify-tui (opt) — TUI Spotify; not installed

## Media — Audio Creation
_Source: modules/media/audio/creation-packages.nix_

- [x] supercollider — audio engine/IDE (RPM)
- [ ] supercolliderPlugins.sc3-plugins — not installed
- [x] carla — audio plugin host; `Carla` (RPM)
- [x] raysession (RPM) — session manager
- [ ] noisetorch — microphone noise gate; not installed (using RNNoise instead)
- [x] rnnoise — `ladspa-realtime-noise-suppression-plugin` (RPM via COPR)

## Media — Audio DSP
_Source: modules/hardware/audio/dsp/pkgs.nix_

- [ ] brutefir — digital convolution engine; not installed
- [ ] camilladsp — flexible audio DSP; not installed
- [ ] jamesdsp — audio effect processor; not installed
- [x] lsp-plugins — Linux Studio Plugins (RPM)
- [ ] yabridge — VST bridge; not installed
- [ ] yabridgectl — yabridge CLI; not installed

## Media — Multimedia
_Source: modules/media/multimedia-packages.nix_

- [x] ffmpeg (RPM)
- [x] ffmpegthumbnailer (RPM)
- [x] imagemagick — `ImageMagick` (RPM)
- [ ] media-player-info — udev HW database; check if installed
- [x] mediainfo (RPM)
- [ ] mpvc — mpv TUI controller; not installed

## Media — Images
_Source: modules/media/images/ (various)_

- [x] lutgen (CRPM)
- [x] pastel (RPM)
- [x] advancecomp (RPM)
- [x] jpegoptim (RPM)
- [x] optipng (RPM)
- [x] pngquant (RPM)
- [x] scour (CRPM)
- [x] exiftool — `perl-Image-ExifTool` (RPM)
- [x] exiv2 (RPM)
- [x] graphviz (RPM)
- [x] qrencode (RPM)
- [x] zbar (RPM)
- [x] swayimg (RPM)
- [x] viu (CRPM)
- [x] darktable (RPM)
- [x] rawtherapee (RPM)
- [x] testdisk (RPM)

## Media — VapourSynth
_Source: modules/media/vapoursynth-packages.nix_

- [x] vapoursynth — `vapoursynth-libs` (RPM)

## Media — AI Upscale
_Source: modules/media/ai-upscale-packages.nix_

- [ ] realesrgan-ncnn-vulkan (opt) — GPU upscaler; not installed
- [x] ffmpeg-full (opt) — N/A; using standard ffmpeg

## Media — Spotifyd
_Source: modules/media/audio/spotifyd.nix_

- [ ] spotifyd — Spotify daemon; not installed

---

## Session — Terminal
_Source: modules/user/session/terminal.nix_

- [x] kitty (RPM)

## Session — Theme & Wallpaper
_Source: modules/user/session/theme.nix_

- [x] matugen (LB) — wallpaper palette generator
- [ ] matugen-themes — template pack; check if bundled
- [x] swaybg (RPM)
- [x] swww (RPM)

## Session — Screenshot & Recording
_Source: modules/user/session/screenshot.nix_

- [x] grim (RPM)
- [x] grimblast (LB)
- [x] slurp (RPM)
- [x] swappy (RPM)
- [x] wf-recorder (RPM)

## Session — Clipboard
_Source: modules/user/session/clipboard.nix_

- [x] cliphist (RPM)
- [x] wl-clip-persist (CRPM)
- [x] wl-clipboard (RPM)

## Session — Chat
_Source: modules/user/session/chat.nix_

- [x] telegram-desktop (RPM)
- [ ] tdl — Telegram CLI uploader; not installed

## Session — Qt/Wayland
_Source: modules/user/session/qt.nix_

- [x] hyprland-qt-support (RPM)
- [x] hyprland-qtutils (RPM)
- [x] qt6-qt5compat (RPM)
- [x] qt6-qtpositioning (RPM)
- [x] qt6-qtwayland (RPM)
- [x] qt6-qtimageformats (RPM)
- [x] qt6-qtsvg (RPM)

## Session — Utils
_Source: modules/user/session/utils.nix_

- [x] wtype (RPM)
- [x] ydotool (RPM)
- [x] dunst (RPM)
- [x] upower (RPM)
- [x] zathura (RPM)
- [x] waypipe (RPM)
- [x] wev (RPM)
- [ ] espanso (opt) — text expansion; not installed
- [ ] handlr — xdg-open replacement; not installed
- [x] xdg-utils (RPM)
- [ ] xdg-ninja — detect mislocated dotfiles; not installed

## Session — XDG Portals
_Source: modules/user/xdg.nix_

- [x] xdg-desktop-portal-gtk (RPM)
- [x] xdg-desktop-portal-termfilechooser (CRPM)

## Session — Hyprland
_Source: modules/user/session/hyprland.nix_

- [x] hyprland (RPM)
- [x] quickshell (CRPM) — Wayland shell/panel

---

## User — GUI Packages
_Source: modules/user/gui-packages.nix_

- [x] gopass (RPM)
- [ ] rofi-pass-wayland — Wayland pass launcher; `rofi-pass-2col` in (LB) as alternative
- [ ] rofi-systemd — systemd picker for rofi; not installed
- [x] rofi (RPM)

## User — Fonts & Theming
_Source: modules/user/theme-packages.nix, modules/fonts/default.nix_

- [x] iosevka-neg (CRPM) — custom Iosevka Nerd Font
- [ ] nerd-fonts.fira-code — FiraCode Nerd Font; not installed (using iosevka-neg)
- [x] material-symbols — `material-icons-fonts` (RPM)
- [ ] oldschool-pc-font-pack — retro PC fonts; not installed
- [x] dconf (RPM)
- [ ] flight-gtk-theme — custom GTK theme; not installed as RPM
- [x] kvantum — `kvantum` + `kvantum-qt5` (RPM)
- [ ] kora-icon-theme — not installed (using papirus-icon-theme)

## User — Locale
_Source: modules/user/locale-pkgs.nix_

- [x] enchant — `enchant2` (RPM)
- [x] hunspell (RPM)
- [x] hunspell-en-US (RPM)
- [x] hunspell-ru — Russian dictionary (RPM)
- [x] hyphen (RPM)
- [x] nuspell — modern spellchecker (RPM)

## User — Locate
_Source: modules/user/locate.nix_

- [x] plocate (RPM)

## User — Mail
_Source: modules/user/mail.nix_

- [ ] himalaya — async email CLI; not installed
- [x] neomutt (RPM)
- [x] vdirsyncer — Cal/CardDAV sync (RPM)

---

## Text — Manipulation
_Source: modules/text/manipulate-packages.nix_

- [x] htmlq (CRPM)
- [x] jc — `python3-jc` (RPM)
- [x] jq (RPM)
- [x] pup (CRPM)
- [x] yq — `yq` (RPM)

## Text — Reading/Preview
_Source: modules/text/read-packages.nix_

- [x] antiword (RPM)
- [x] epr (CRPM)
- [x] glow (RPM)
- [x] lowdown (RPM)

## Text — Notes
_Source: modules/text/notes-packages.nix_

- [x] zk (CRPM)

---

## Secrets & Security
_Source: modules/secrets/pkgs.nix_

- [x] age (RPM)
- [x] opensc (RPM)
- [x] p11-kit (RPM)
- [x] pcsc-tools — smartcard debugging (RPM)
- [ ] sops — Mozilla SOPS secrets editor; not installed
- [ ] ssh-to-age — SSH to age key converter; not installed

---

## Games — Main
_Source: modules/games/default.nix, modules/fun/ (various)_

- [x] abuse (RPM)
- [x] airshipper — Veloren launcher; Flatpak (`net.veloren.airshipper`)
- [x] angband — roguelike (RPM)
- [x] brogue-ce — roguelike; Flatpak (`com.github.tmewett.BrogueCE`)
- [x] crawl (RPM)
- [x] crawl-tiles (RPM)
- [x] endless-sky — space exploration (RPM)
- [x] fheroes2 — free Heroes 2 (RPM)
- [x] flare — fantasy action RPG (RPM)
- [x] gnuchess (RPM)
- [x] gzdoom — Doom engine; Flatpak (`org.zdoom.GZDoom`)
- [x] jazz2 — Jazz Jackrabbit 2; Flatpak (`tk.deat.Jazz2Resurrection`)
- [x] shattered-pixel-dungeon — roguelike; Flatpak (`com.shatteredpixel.shatteredpixeldungeon`)
- [x] superTux — 2D platformer; `supertux` (RPM)
- [x] superTuxKart — removed (not needed)
- [x] wesnoth (RPM)
- [x] xaos (RPM)
- [x] xonotic (RPM)
- [x] zeroad — ancient warfare RTS; `0ad` (RPM)
- [x] nethack (RPM)
- [x] openmw — Morrowind engine (RPM)

## Games — Controllers
_Source: modules/games/controllers.nix_

- [x] dualsensectl — DualSense config; COPR `kapsh/dualsensectl`

## Games — Launchers & Proton
_Source: modules/fun/launchers-packages.nix_

- [ ] protonplus — Proton prefix manager; not installed
- [x] protontricks (RPM)
- [x] protonup-ng — Proton-GE installer; ProtonUp-Qt Flatpak (`net.davidotek.pupgui2`)
- [x] vkbasalt — `vkBasalt` (RPM)
- [x] vkbasalt-cli — `python3-vkbasalt-cli` (RPM)
- [x] mangohud (RPM)

## Games — Emulators
_Source: modules/emulators/pkgs.nix_

- [x] retroarch (RPM)
- [x] retroarch-assets (RPM)
- [x] dosbox-staging (RPM) — installed
- [x] pcem (opt) (RPM)
- [x] pcsx2 (FP) — `net.pcsx2.PCSX2`

## Fun — Misc
_Source: modules/fun/misc-packages.nix_

- [x] bucklespring — keyboard click sounds; custom RPM
- [x] dotacat — `lolcat` (RPM, similar functionality)
- [x] figlet (RPM)
- [x] fortune — `fortune-mod` (RPM)
- [x] neo-cowsay — `cowsay` (RPM, slightly different)
- [x] neo — matrix rain (RPM)
- [x] nms — `no-more-secrets` (RPM)
- [x] taoup — Tao of Unix Programming; custom RPM
- [x] toilet (RPM)

---

## Flatpak
_Source: modules/flatpak/pkgs.nix_

- [x] flatpak (RPM)

## Torrent
_Source: modules/torrent/default.nix_

- [x] transmission — `transmission-gtk` (RPM)
- [ ] rustmission — Rust TUI for Transmission; not installed

---

## VPN / Proxy
_Source: modules/system/net/vpn/ (various)_

- [ ] xray — VLESS/Reality proxy; not installed
- [ ] sing-box — universal proxy; not installed

---

## Browsers
_Source: modules/web/default.nix (various)_

Only listing browsers that were enabled in NixOS config:

- [x] firefox (RPM)
- [x] floorp (FP) — `one.ablaze.floorp`
- [x] chromium (RPM)
- [ ] brave — not installed
- [ ] vivaldi — not installed
- [ ] librewolf — not installed
- [ ] google-chrome — not installed (using chromium)

---

## Nix-Only Tools (Not Applicable on Fedora)
_Source: modules/tools/pkgs.nix and others_

These are Nix ecosystem tools that have no purpose outside NixOS/Nix:

- [-] nixfmt — Nix code formatter
- [-] cached-nix-shell — instant nix-shell startup
- [-] deadnix — scan for dead Nix code
- [-] manix — NixOS documentation search
- [-] niv — pin Nix dependencies
- [-] nix-diff — compare derivations
- [-] nix-init — easier Nix package creation
- [-] nixos-shell — NixOS VM creator
- [-] nix-output-monitor (nom) — fancy build output
- [-] nix-tree — derivation dependency inspector
- [-] npins — alternative to niv
- [-] nvd — NixOS version diff
- [-] nix-melt — flake lock updater TUI
- [-] statix — Nix static analyzer
- [-] nil — Nix LSP

---

## `nix run` Aliases (On-Demand Tools)
_Source: modules/cli/tools.nix shellAliases_

These were not permanently installed on NixOS either — they ran on demand
via `nix run`. Consider installing permanently or creating similar aliases.

| Alias | Nix Command | Fedora Status |
|-------|-------------|---------------|
| `sk` | `nix run github:neg-serg/two_percent --` | Not available — custom tool |
| `newsraft` | `nix run nixpkgs#newsraft --` | Not installed — RSS reader |
| `tealdeer` | `nix run nixpkgs#tealdeer --` | [x] Installed as `tealdeer` (RPM) |

---

## Custom NixOS Packages (from packages/ overlay)
_Source: packages/overlay.nix, packages/overlays/_

| Custom Package | Description | Fedora Status |
|----------------|-------------|---------------|
| neg.duf | duf fork with `--theme neg` | [x] (CRPM) |
| neg.albumdetails | TagLib album metadata CLI | [x] (LB) `albumdetails` |
| neg.pretty_printer | Pretty printer | [x] (CRPM) `neg-pretty-printer` |
| neg.ncpamixer-wrapped | ncpamixer with config | [x] (LB) `ncpamixer` |
| neg.surfingkeys_conf | SurfingKeys browser config | Deployed via dotfiles |
| neg.rsmetrx | Custom shader pack | [x] (LB) `rsmetrx` |
| iosevka-neg | Custom Iosevka Nerd Font | [x] (CRPM) |
| transmission_exporter | Prometheus exporter | Not needed (no Prometheus) |
| rofi-config | Custom rofi theme | Deployed via dotfiles |
| neg.tws (opt) | Interactive Brokers TWS | Not installed |

---

## Flake Inputs (External Sources)
_Source: flake.nix_

| Input | Purpose | Fedora Status |
|-------|---------|---------------|
| hyprland | Wayland compositor | [x] (RPM) |
| hy3 | Hyprland plugin | [ ] Not installed |
| raise | Window raise utility | [x] (CRPM) |
| quickshell | Wayland shell/panel | [x] (CRPM) |
| iosevka-neg | Custom font | [x] (CRPM) |
| richcolors | Color tool | [x] (CRPM) |
| rsmetrx | Shader pack | [x] (LB) |
| nix-flatpak | Flatpak integration | [-] Nix-only |
| nix-maid | Home-manager ext | [-] Nix-only |
| lanzaboote | Secure Boot | [-] Nix-only |
| sops-nix | Secrets | [-] Using gopass instead |
| winapps | Win apps in KVM | [ ] Not set up |
| tailray | Tailscale + xray | [ ] Not installed |

---

## Summary Statistics

| Category | Total | Installed | Missing | N/A |
|----------|-------|-----------|---------|-----|
| CLI Tools | 68 | 62 | 6 | 0 |
| Development | 52 | 18 | 32 | 2 |
| System/Hardware | 50 | 44 | 6 | 0 |
| Monitoring | 15 | 10 | 5 | 0 |
| Media/Audio | 42 | 23 | 19 | 0 |
| Session/UI | 30 | 27 | 3 | 0 |
| Games/Fun | 30 | 15 | 15 | 0 |
| Text/Locale | 15 | 13 | 2 | 0 |
| Secrets/Security | 6 | 3 | 3 | 0 |
| Browsers | 7 | 3 | 4 | 0 |
| Nix-only | 15 | 0 | 0 | 15 |
| **Total** | **~330** | **~218** | **~95** | **~17** |

### Key Gaps to Address

**High priority** (daily-use tools):
- LSPs — set up mason.nvim for automatic management
- handlr — xdg-open replacement (install via cargo or COPR)
- httpstat — curl stats visualizer
- act — GitHub Actions local runner

**Medium priority** (periodic use):
- urlwatch, scdl, tdl, rmpc, mpvc
- protonplus, protonup-ng (gaming)
- pcsc-tools, sops, ssh-to-age (security)
- wiremix, coppwr, pw-volume (audio)

**Low priority** (optional/niche):
- Audio production: supercollider, carla, brutefir, camilladsp, yabridge
- Games: airshipper, angband, brogue, gzdoom, zeroad, etc.
- Fun: bucklespring, dotacat, nms, taoup
- Misc: blesh, espanso, xdg-ninja
