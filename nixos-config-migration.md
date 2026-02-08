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
| `~/.config/yazi/yazi.toml` | cli/yazi.nix (generated TOML) | — | [ ] |
| `~/.config/yazi/theme.toml` | cli/yazi.nix (generated TOML) | — | [ ] |
| `~/.config/yazi/keymap.toml` | cli/yazi.nix (generated TOML) | — | [ ] |
| `~/.config/yazi/plugins/*.lua` | cli/yazi.nix (inline text) | — | [ ] |

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

### MPV scripts (bundled in NixOS mpv package)
- cutter, mpris, quality-menu, sponsorblock, thumbfast, uosc
- Status: [ ] need manual install on Fedora

## 10. Media: MPD & Scrobblers

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/mpd/mpd.conf` | sys/media.nix | — | [~] mpd.sls exists |
| `~/.config/beets/config.yaml` | sys/media.nix (generated) | — | [ ] |
| `~/.config/mpDris2/mpDris2.conf` | sys/media.nix | — | [ ] |
| `~/.config/rescrobbled/config.toml` | sys/media.nix | — | [ ] |
| `~/.config/rmpc/*` | static files/ | dot_config/rmpc/ | [x] |

### Systemd services
- mpdris2 (MPRIS bridge), mpdas (Last.fm), rescrobbled (MPRIS scrobbler)
- Status: [ ] need user services

## 11. Mail System

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/mbsync/mbsyncrc` | sys/mail.nix (credentials) | — | [ ] |
| `~/.config/msmtp/config` | sys/mail.nix | — | [ ] |
| `~/.config/notmuch/notmuchrc` | sys/mail.nix | — | [ ] |
| `~/.config/imapnotify/gmail.json` | sys/mail.nix | — | [ ] |

## 12. GPG/SSH

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.local/share/gnupg/gpg-agent.conf` | sys/gpg.nix | dot_local/share/gnupg/gpg-agent.conf | [x] |
| `~/.local/share/gnupg/scdaemon.conf` | sys/gpg.nix | dot_local/share/gnupg/scdaemon.conf | [x] |
| pinentry-rofi wrapper | sys/gpg.nix (custom script) | — | [~] using pinentry-gnome3 |
| gpg-agent systemd service | sys/gpg.nix | — | [ ] |

## 13. Calendar & Contacts

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/khal/config` | sys/khal.nix (generated) | — | [ ] |
| `~/.config/vdirsyncer/config` | sys/vdirsyncer.nix (sops template) | dot_config/vdirsyncer/ | [~] |

## 14. Download Tools

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/aria2/aria2.conf` | web/aria.nix | dot_config/aria2/aria2.conf | [x] |
| `~/.config/yt-dlp/config` | web/yt-dlp.nix | dot_config/yt-dlp/config | [x] |

## 15. Spell Checking

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/enchant/enchant.ordering` | sys/enchant.nix | dot_config/enchant/enchant.ordering | [x] |

## 16. Browser (Firefox/Floorp)

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.mozilla/firefox/*/user.js` | web/mozilla-common-lib.nix | — | [ ] complex |
| `~/.mozilla/firefox/*/chrome/userChrome.css` | web/mozilla-common-lib.nix | — | [ ] complex |
| `policies.json` | web/mozilla-common-lib.nix | — | [ ] /etc level |
| Extensions (*.xpi) | web/mozilla-common-lib.nix (fetchurl) | — | [ ] |

## 17. Editors (Antigravity, Opencode)

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/Antigravity/User/settings.json` | apps/antigravity.nix | dot_config/Antigravity/User/settings.json | [x] |
| `~/.config/opencode/opencode.json` | apps/opencode.nix | — | [ ] contains API keys |

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

---

## Summary Statistics

- **Total config groups**: 20
- **Fully migrated** `[x]`: ~75 files across 17 groups
- **Partially migrated** `[~]`: 4 items (permissions.conf, plugins.conf, vdirsyncer, pinentry)
- **Not migrated** `[ ]`: ~15 items across 6 groups
- **Remaining**: Yazi, MPV scripts, MPD/beets/scrobblers, mail system, browser, opencode, khal, systemd services
