# NixOS Config Migration Inventory

Status legend: `[x]` migrated, `[~]` partial, `[ ]` not migrated, `[n/a]` not needed on Fedora

## 1. Shell & Terminal

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/zsh/.zshenv` | cli/shells.nix + cli/envs.nix | dot_config/zsh/dot_zshenv | [x] |
| `~/.config/zsh/*.zsh` | static files/ | dot_config/zsh/ | [x] |
| `~/.config/inputrc` | cli/shells.nix | dot_config/inputrc | [x] |
| `~/.config/aliae/config.yaml` | cli/shells.nix | dot_config/aliae/aliae.yaml | [x] |
| `~/.config/kitty/*` | static files/ | dot_config/kitty/ | [x] |
| `~/.config/tmux/tmux.conf` | cli/tmux/default.nix (programs.tmux) | dot_config/tmux/tmux.conf | [x] |

### Environment variables (cli/shells.nix, cli/envs.nix)
| Variable | Value | Status |
|---|---|---|
| `ZDOTDIR` | `~/.config/zsh` | [x] in dot_zshenv |
| `TERMINAL` | `kitty` | [x] in dot_zshenv |
| `MANWIDTH` | `80` | [x] in dot_zshenv |
| `GREP_COLOR`, `GREP_COLORS` | color codes | [x] in dot_zshenv |
| `XDG compliance vars` | CRAWL_DIR, GRIM_DEFAULT_DIR, NPM_*, etc. | [x] in dot_zshenv |

## 2. CLI Tools

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/tig/config` | cli/tig.nix | dot_config/tig/config | [x] |
| `~/.config/bat/config` | cli/search.nix | dot_config/bat/config | [x] |
| `~/.config/fd/ignore` | cli/search.nix | dot_config/fd/ignore | [x] |
| `~/.config/ripgrep/ripgreprc` | cli/search.nix | dot_config/ripgrep/ripgreprc | [x] |
| `~/.config/btop/btop.conf` | cli/monitoring.nix | dot_config/btop/btop.conf | [x] |
| `~/.config/btop/themes/midnight-ocean.theme` | static files/ | dot_config/btop/themes/ | [x] |
| `~/.config/broot/*` | static files/ | dot_config/broot/ | [x] |
| `~/.config/television/*` | static files/ | dot_config/television/ | [x] |
| `~/.config/fastfetch/*` | static files/ | dot_config/fastfetch/ | [x] |

### Environment variables (cli/search.nix)
| Variable | Value | Status |
|---|---|---|
| `RIPGREP_CONFIG_PATH` | `~/.config/ripgrep/ripgreprc` | [x] in dot_zshenv |
| `FZF_DEFAULT_COMMAND` | fd command | [x] in dot_zshenv |
| `FZF_DEFAULT_OPTS` | extensive options + colors | [x] in dot_zshenv |
| `FZF_CTRL_R_OPTS` | search options | [x] in dot_zshenv |
| `FZF_CTRL_T_OPTS` | file picker options | [x] in dot_zshenv |

## 3. Yazi File Manager

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/yazi/yazi.toml` | cli/yazi.nix (generated TOML) | dot_config/yazi/yazi.toml | [x] |
| `~/.config/yazi/theme.toml` | cli/yazi.nix (generated TOML) | dot_config/yazi/theme.toml | [x] |
| `~/.config/yazi/keymap.toml` | cli/yazi.nix (generated TOML) | dot_config/yazi/keymap.toml | [x] |
| `~/.config/yazi/plugins/smart-paste.yazi` | yazi-rs/plugins (fetchFromGitHub) | dot_config/yazi/plugins/smart-paste.yazi/ | [x] |
| `~/.config/yazi/plugins/save-file.yazi` | cli/yazi.nix (inline Lua) | dot_config/yazi/plugins/save-file.yazi/ | [x] |
| `~/.config/yazi/plugins/paste-to-select.yazi` | cli/yazi.nix (inline Lua) | dot_config/yazi/plugins/paste-to-select.yazi/ | [x] |

## 4. GUI: Hyprland

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/hypr/hyprland.conf` | hyprland/environment.nix | dot_config/hypr/hyprland.conf | [x] |
| `~/.config/hypr/env.conf` | hyprland/environment.nix | dot_config/hypr/env.conf | [x] |
| `~/.config/hypr/init.conf` | static files/ | dot_config/hypr/init.conf | [x] |
| `~/.config/hypr/bindings.conf` | static files/ | dot_config/hypr/bindings.conf | [x] |
| `~/.config/hypr/workspaces.conf` | hyprland/environment.nix (generated) | dot_config/hypr/workspaces.conf | [x] |
| `~/.config/hypr/rules-routing.conf` | hyprland/environment.nix (generated) | dot_config/hypr/rules-routing.conf | [x] |
| `~/.config/hypr/permissions.conf` | hyprland/environment.nix (generated) | — | [~] in init.conf |
| `~/.config/hypr/plugins.conf` | hyprland/environment.nix (conditional) | — | [~] in init.conf |
| `~/.config/hypr/animations/*` | static files/ | dot_config/hypr/animations/ | [x] |
| `~/.config/hypr/bindings/*` | static files/ | dot_config/hypr/bindings/ | [x] |
| `~/.config/hypr/hyprlock/*` | static files/ | dot_config/hypr/hyprlock/ | [x] |

### Environment variables (hyprland/environment.nix, gui/theme.nix, gui/qt.nix)
| Variable | Value | Status |
|---|---|---|
| `GDK_SCALE`, `QT_AUTO_SCREEN_SCALE_FACTOR` | scaling | [x] in env.conf |
| `GDK_BACKEND`, `QT_QPA_PLATFORM`, `SDL_VIDEODRIVER` | wayland | [x] in env.conf |
| `XDG_CURRENT_DESKTOP`, `XDG_SESSION_TYPE` | Hyprland/wayland | [x] in env.conf |
| `MOZ_ENABLE_WAYLAND`, `ELECTRON_OZONE_PLATFORM_HINT` | 1/auto | [x] in env.conf |
| `QT_QPA_PLATFORMTHEME`, `QT_STYLE_OVERRIDE` | qt6ct/kvantum | [x] in env.conf |
| `GTK_THEME`, `XCURSOR_THEME`, `HYPRCURSOR_*` | themes | [x] in env.conf |

## 5. GUI: Notifications (Dunst)

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/dunst/dunstrc` | gui/dunst.nix (generated INI) | dot_config/dunst/dunstrc | [x] |

## 6. GUI: Theme & Appearance

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/gtk-3.0/settings.ini` | gui/theme.nix (generated INI) | dot_config/gtk-3.0/settings.ini | [x] |
| `~/.config/gtk-3.0/gtk.css` | gui/theme.nix | dot_config/gtk-3.0/gtk.css | [x] |
| `~/.config/gtk-4.0/settings.ini` | gui/theme.nix (generated INI) | dot_config/gtk-4.0/settings.ini | [x] |
| `~/.config/gtk-4.0/gtk.css` | gui/theme.nix | dot_config/gtk-4.0/gtk.css | [x] |
| `~/.gtkrc-2.0` | gui/theme.nix | dot_gtkrc-2.0 | [x] |
| `~/.config/wallust/*` | gui/theme.nix (static files/) | dot_config/wallust/ | [x] |
| Flight-Dark-GTK theme | gui/theme.nix (package) | ~/.local/share/themes/ | [x] Salt installer |
| kora-icon-theme | gui/theme.nix (package) | ~/.local/share/icons/ | [x] Salt installer |

## 7. GUI: Qt Theming

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/Kvantum/kvantum.kvconfig` | gui/qt.nix | dot_config/Kvantum/kvantum.kvconfig | [x] |
| `~/.config/qt6ct/qt6ct.conf` | gui/qt.nix | dot_config/qt6ct/qt6ct.conf | [x] |
| `~/.config/qt5ct/qt5ct.conf` | gui/qt.nix | dot_config/qt5ct/qt5ct.conf | [x] |
| Packages: qt5ct, qt6ct, kvantum | gui/qt.nix | system_description.sls | [x] |

## 8. GUI: XDG & File Association

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/mimeapps.list` | gui/xdg.nix (generated INI) | dot_config/mimeapps.list | [x] |
| `~/.config/user-dirs.dirs` | gui/xdg.nix | dot_config/user-dirs.dirs | [x] |
| `kitty-open.desktop` | gui/xdg.nix | dot_local/share/applications/ | [x] |

## 9. Media: MPV

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/mpv/mpv.conf` | apps/mpv/config.nix | dot_config/mpv/mpv.conf | [x] |
| `~/.config/mpv/input.conf` | apps/mpv/input.nix | dot_config/mpv/input.conf | [x] |
| `~/.config/mpv/profiles.conf` | apps/mpv/profiles.nix | dot_config/mpv/profiles.conf | [x] |
| `~/.config/mpv/styles.ass` | apps/mpv/config.nix | dot_config/mpv/styles.ass | [x] |
| `~/.config/mpv/script-opts/osc.conf` | apps/mpv/scripts.nix | dot_config/mpv/script-opts/osc.conf | [x] |
| `~/.config/mpv/script-opts/uosc.conf` | apps/mpv/scripts.nix | dot_config/mpv/script-opts/uosc.conf | [x] |
| `~/.config/mpv/shaders/*` | apps/mpv/shaders.nix (fetchurl) | dot_config/mpv/shaders/ | [x] 4 GLSL files |
| MPV scripts (6 plugins) | apps/mpv/package.nix | system_description.sls | [x] Salt installer |

## 10. Media: MPD & Scrobblers

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/mpd/mpd.conf` | sys/media.nix | dot_config/mpd/mpd.conf | [x] |
| `~/.config/beets/config.yaml` | sys/media.nix (generated) | dot_config/beets/config.yaml | [x] |
| `~/.config/mpDris2/mpDris2.conf` | sys/media.nix | dot_config/mpDris2/mpDris2.conf | [x] |
| `~/.config/rescrobbled/config.toml` | sys/media.nix | dot_config/rescrobbled/config.toml | [x] |
| `~/.config/rmpc/*` | static files/ | dot_config/rmpc/ | [x] |

### Systemd services
| Service | Status |
|---|---|
| mpdris2 (MPRIS bridge) | [x] Salt state in system_description.sls |
| rescrobbled (MPRIS scrobbler) | [ ] TODO: see setup instructions below |
| mpdas (Last.fm) | [x] Salt cmd.run + gopass in mpd.sls |

### rescrobbled setup (TODO)

rescrobbled is an MPRIS scrobbler that scrobbles from any MPRIS2-capable player
(mpv, Spotify, browsers, etc.) to Last.fm/ListenBrainz. Unlike mpdas which only
covers MPD, rescrobbled covers everything that speaks MPRIS2.

Steps to enable:

1. **Build the RPM** (preferred) or install via cargo:
   - RPM: add a spec to `salt/specs/rescrobbled.spec`, add build section to
     `salt/build-rpm.sh`, entry in `build_rpms.sls`. It's a Rust crate:
     `cargo install rescrobbled`
   - Or directly: `cargo install rescrobbled` (binary lands in `~/.cargo/bin/`)
2. **Get Last.fm API credentials**:
   - Register an app at https://www.last.fm/api/account/create
   - Store keys in gopass: `gopass insert lastfm/api_key`, `gopass insert lastfm/secret`
3. **Authenticate**: run `rescrobbled` once interactively to complete the OAuth
   flow — it will write a `session_key` to the config
4. **Deploy config** via Salt/chezmoi to `~/.config/rescrobbled/config.toml`:
   ```toml
   [lastfm]
   api_key = "<from gopass>"
   secret = "<from gopass>"
   session_key = "<from step 3>"
   ```
5. **Add Salt states back**: systemd unit + enable state in `mpd.sls`
   (see git history for the removed states as a template)

## 11. Mail System

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/mbsync/mbsyncrc` | sys/mail.nix (credentials) | dot_config/mbsync/mbsyncrc.tmpl | [x] gopass template |
| `~/.config/msmtp/config` | sys/mail.nix | dot_config/msmtp/config.tmpl | [x] gopass template |
| `~/.config/notmuch/notmuchrc` | sys/mail.nix | dot_config/notmuch/notmuchrc | [x] |
| `~/.config/imapnotify/gmail.json` | sys/mail.nix | dot_config/imapnotify/gmail.json.tmpl | [x] gopass template |

### Systemd services
| Service | Status |
|---|---|
| mbsync-gmail.timer (10min mail sync) | [x] Salt state in system_description.sls |
| imapnotify-gmail (IMAP IDLE) | [x] Salt state in system_description.sls |

## 12. GPG/SSH

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.local/share/gnupg/gpg-agent.conf` | sys/gpg.nix | dot_local/share/gnupg/gpg-agent.conf | [x] |
| `~/.local/share/gnupg/scdaemon.conf` | sys/gpg.nix | dot_local/share/gnupg/scdaemon.conf | [x] |
| pinentry-rofi wrapper | sys/gpg.nix (custom script) | dot_local/bin/executable_pinentry-rofi-wrapper | [x] rofi + gnome3 fallback |
| gpg-agent systemd service | sys/gpg.nix | system_description.sls | [x] gpg-agent.socket enabled |

## 13. Calendar & Contacts

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/khal/config` | sys/khal.nix (generated) | dot_config/khal/config | [x] |
| `~/.config/vdirsyncer/config` | sys/vdirsyncer.nix (sops template) | dot_config/vdirsyncer/config.tmpl | [x] gopass template |

### Systemd services
| Service | Status |
|---|---|
| vdirsyncer.timer (5min calendar sync) | [x] Salt state in system_description.sls |

## 14. Download Tools

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/aria2/aria2.conf` | web/aria.nix | dot_config/aria2/aria2.conf | [x] |
| `~/.config/yt-dlp/config` | web/yt-dlp.nix | dot_config/yt-dlp/config | [x] |

## 15. Spell Checking

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/enchant/enchant.ordering` | sys/enchant.nix | dot_config/enchant/enchant.ordering | [x] |

## 16. Browser (Floorp Flatpak)

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `user.js` (Betterfox + prefs) | web/mozilla-common-lib.nix | dot_config/tridactyl/user.js | [x] Salt deploys to Floorp profile |
| `chrome/userChrome.css` | web/mozilla-common-lib.nix | dot_config/tridactyl/mozilla/userChrome.css | [x] Salt deploys to Floorp profile |
| `chrome/userContent.css` | web/mozilla-common-lib.nix | dot_config/tridactyl/mozilla/userContent.css | [x] Salt deploys to Floorp profile |
| `~/.config/tridactyl/tridactylrc` | files/misc/tridactyl/ | dot_config/tridactyl/tridactylrc | [x] |
| Tridactyl themes (4 CSS) | files/misc/tridactyl/themes/ | dot_config/tridactyl/themes/ | [x] |
| `~/.surfingkeys.js` | files/surfingkeys.js | dot_surfingkeys.js | [x] |
| `policies.json` | web/mozilla-common-lib.nix | — | [n/a] Flatpak, no /etc access |
| Extensions (*.xpi) | web/mozilla-common-lib.nix (fetchurl) | — | [x] Salt downloads .xpi into profile |

## 17. Editors (Antigravity, Opencode)

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/Antigravity/User/settings.json` | apps/antigravity.nix | dot_config/Antigravity/User/settings.json | [x] |
| `~/.config/opencode/opencode.json` | apps/opencode.nix | — | [~] config ok, API keys via zsh/10-secrets.zsh.tmpl |

## 18. Application Launcher (Walker)

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/walker/*` | static files/ | dot_config/walker/ | [x] |

## 19. QuickShell

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/quickshell/*` | static files/ | dot_config/quickshell/ | [x] |

## 20. Neovim

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/nvim/*` | user/neovim.nix + static | dot_config/nvim/ | [x] |

## 21. Clipboard (Wayland)

| Package/config | NixOS source | Salt location | Status |
|---|---|---|---|
| cliphist | session/clipboard.nix | system_description.sls (Wayland category) | [x] |
| wl-clipboard (wl-copy/wl-paste) | session/clipboard.nix | base image (Wayblue) | [x] |
| wl-clip-persist | session/clipboard.nix | custom RPM (install_rpms.sls) | [x] |

## 22. Screenshot & Recording

| Package/config | NixOS source | Salt location | Status |
|---|---|---|---|
| grim | session/screenshot.nix | rpm-ostree layered | [x] |
| slurp | session/screenshot.nix | rpm-ostree layered | [x] |
| grimblast | session/screenshot.nix | system_description.sls (install_grimblast) | [x] |
| swappy | session/screenshot.nix | system_description.sls (Wayland category) | [x] |
| wf-recorder | session/screenshot.nix | system_description.sls (Wayland category) | [x] |

## 23. Wayland Utilities

| Package/config | NixOS source | Salt location | Status |
|---|---|---|---|
| wtype | session/utils.nix | system_description.sls (Wayland) | [x] |
| ydotool | session/utils.nix | system_description.sls (Wayland) | [x] |
| wev | session/utils.nix | system_description.sls (Wayland) | [x] |
| waypipe | session/utils.nix | system_description.sls (Network) | [x] |
| zathura + pdf-poppler | session/utils.nix | system_description.sls (Shell & Tools) | [x] |
| udiskie | session/utils.nix | system_description.sls (Shell & Tools) | [x] |

## 24. Wallpaper & Theme Tools

| Package/config | NixOS source | Salt location | Status |
|---|---|---|---|
| swaybg | session/theme.nix | system_description.sls (Wayland) | [x] |
| swww | session/theme.nix | system_description.sls (Wayland) | [x] |

## 25. Rofi Launcher

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/rofi/config.rasi` | gui-packages.nix | dot_config/rofi/config.rasi | [x] |
| `~/.config/rofi/theme.rasi` | packages/rofi-config/ | dot_config/rofi/theme.rasi | [x] |
| `~/.config/rofi/*.rasi` (themes) | packages/rofi-config/ | dot_config/rofi/ | [x] |
| rofi package | gui-packages.nix | system_description.sls (Wayland) | [x] |

## 26. Wlogout

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/wlogout/layout*` | static files/ | dot_config/wlogout/ | [x] |
| `~/.config/wlogout/style*.css` | static files/ | dot_config/wlogout/ | [x] |
| `~/.config/wlogout/icons/*` | static files/ | dot_config/wlogout/icons/ | [x] |
| wlogout package | — | system_description.sls (Wayland) | [x] |

## 27. Chat Applications

| Package | NixOS source | Salt location | Status |
|---|---|---|---|
| telegram-desktop | session/chat.nix | system_description.sls (Network) | [x] |

## 28. Torrent Client

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| transmission-gtk | torrent/default.nix | system_description.sls (Network) | [x] |
| `~/.config/rustmission/config.toml` | files/config/rustmission/ | dot_config/rustmission/config.toml | [x] |
| `~/.config/rustmission/categories.toml` | files/config/rustmission/ | dot_config/rustmission/categories.toml | [x] |
| `~/.config/rustmission/keymap.toml` | files/config/rustmission/ | dot_config/rustmission/keymap.toml | [x] |

## 29. Text Processing Tools

| Package | NixOS source | Salt location | Status |
|---|---|---|---|
| jc | text/manipulate.nix | system_description.sls (Shell & Tools) | [x] |
| yq | text/manipulate.nix | system_description.sls (Shell & Tools) | [x] |
| glow | text/read.nix | system_description.sls (Shell & Tools) | [x] |
| lowdown | text/read.nix | system_description.sls (Shell & Tools) | [x] |
| par | cli/text.nix | system_description.sls (Shell & Tools) | [x] |
| htmlq | text/manipulate.nix | custom RPM (install_rpms.sls) | [x] |
| pup | text/manipulate.nix | custom RPM (install_rpms.sls) | [x] |
| choose | cli/text.nix | custom RPM (install_rpms.sls) | [x] |

## 30. Archive & Compression Tools

| Package | NixOS source | Salt location | Status |
|---|---|---|---|
| patool | cli/archives/pkgs.nix | system_description.sls (Archives) | [x] |
| lbzip2, pbzip2, pigz | cli/archives/pkgs.nix | system_description.sls (Archives) | [x] |
| unar | cli/archives/pkgs.nix | system_description.sls (Archives) | [x] |
| ouch | cli/archives/pkgs.nix | custom RPM (install_rpms.sls) | [x] |
| rapidgzip | cli/archives/pkgs.nix | custom RPM (install_rpms.sls) | [x] |

## 31. Network CLI Tools

| Package | NixOS source | Salt location | Status |
|---|---|---|---|
| prettyping | cli/network.nix | system_description.sls (Network) | [x] |
| speedtest-cli | cli/network.nix | system_description.sls (Network) | [x] |
| urlscan | cli/network.nix | system_description.sls (Shell & Tools) | [x] |
| xxh | cli/network.nix | custom RPM (install_rpms.sls) | [x] |

## 32. PipeWire & Audio

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| Clock rate + quantum | hardware/audio/pipewire/ | dot_config/pipewire/pipewire.conf.d/clock-rate.conf | [x] |
| Resample quality | — | dot_config/pipewire/pipewire.conf.d/resample-quality.conf | [x] |
| RME ADI-2 remap | — | dot_config/pipewire/pipewire.conf.d/98-adi2-remap.conf | [x] |
| Virtual sink (Carla) | — | dot_config/pipewire/pipewire.conf.d/10-virtual-sink.conf | [x] |
| RNNoise filter-chain | hardware/audio/pipewire/ | dot_config/pipewire/pipewire.conf.d/95-rnnoise-filter-chain.conf | [x] COPR plugin |
| WirePlumber ALSA config | hardware/audio/pipewire/ | dot_config/wireplumber/wireplumber.conf.d/50-alsa-config.conf | [x] |
| WirePlumber default volume | hardware/audio/pipewire/ | dot_config/wireplumber/wireplumber.conf.d/10-default-volume.conf | [x] |

## 33. Fonts

| Package | NixOS source | Salt location | Status |
|---|---|---|---|
| iosevka-neg (custom) | fonts.nix (flake input) | custom RPM (iosevka-neg-fonts) | [x] |
| fira-code-nerd | fonts.nix | fira-code-nerd.sls Salt state | [x] |
| material-icons-fonts | fonts.nix | system_description.sls (Fonts) | [x] |

## 34. Gaming & Emulation

| Package | NixOS source | Salt location | Status |
|---|---|---|---|
| gamescope | games/performance.nix | system_description.sls (Gaming) | [x] |
| mangohud | games/performance.nix | system_description.sls (Gaming) | [x] |
| dosbox-staging | emulators/pkgs.nix | system_description.sls (Gaming) | [x] |
| retroarch | emulators/pkgs.nix | system_description.sls (Gaming) | [x] |
| corectrl | hardware/gpu-corectrl.nix | system_description.sls (Desktop) | [x] |
| Steam (Flatpak) | — | system_description.sls (Flatpak) | [x] |
| PCSX2 (Flatpak) | — | system_description.sls (Flatpak) | [x] |
| `~/.config/dosbox/*.conf` | files/config/dosbox/ | dot_config/dosbox/ | [x] |

## 35. Locale & System

| Setting | NixOS source | Salt location | Status |
|---|---|---|---|
| Timezone (Europe/Moscow) | user/locale.nix | system_description.sls (system_timezone) | [x] |
| Locale (en_US.UTF-8) | user/locale.nix | system_description.sls (system_locale) | [x] |
| Keyboard layout (ru,us) | user/locale.nix | system_description.sls (system_keymap) | [x] |
| D-Bus broker | user/dbus.nix | system_description.sls (running_services) | [x] |

## 36. Miscellaneous Configs

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/amfora/config.toml` | files/config/amfora/ | dot_config/amfora/config.toml | [x] |
| `~/.config/git/*` | files/git/ | dot_config/git/ | [x] |
| liquidctl | hardware/liquidctl.nix | system_description.sls (Monitoring) | [x] |
| plocate | user/locate.nix | system_description.sls (File Management) | [x] |
| rmlint | cli/file-ops.nix | system_description.sls (File Management) | [x] |
| ollama | llm/ | system_description.sls (Network) | [x] |

---

## Not Applicable on Fedora Atomic

| Item | NixOS source | Reason |
|---|---|---|
| Firejail sandboxing | security/firejail.nix | SELinux + Flatpak sandboxing on Fedora |
| Greetd login manager | session/greetd.nix | GDM on Fedora Atomic |
| Plymouth theme | boot config | Fedora ships own Plymouth |
| Nix overlays | tools/ | Not applicable |
| USB automount scripts | hardware/usb-automount.nix | udisks2 works OOTB |
| geoclue2 | user/locale.nix | Fedora enables by default |

---

## Summary Statistics

- **Total config groups**: 36
- **Fully migrated** `[x]`: ~140 items across 36 groups
- **Partially migrated** `[~]`: 1 item (hyprland permissions.conf/plugins.conf)
- **Not migrated** `[ ]`: 1 item (rescrobbled service)
- **Not applicable** `[n/a]`: 6 items (firejail, greetd, plymouth, nix overlays, USB automount, policies.json)
