# NixOS Config Migration Inventory

Status legend: `[x]` migrated, `[~]` partial, `[ ]` not migrated, `[n/a]` not needed on Fedora

## 1. Shell & Terminal

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/zsh/.zshenv` | cli/shells.nix | dot_config/zsh/dot_zshenv | [x] |
| `~/.config/zsh/*.zsh` | static files/ | dot_config/zsh/ | [x] |
| `~/.config/inputrc` | cli/shells.nix | — | [ ] |
| `~/.config/aliae/config.yaml` | cli/shells.nix | dot_config/aliae/aliae.yaml | [x] |
| `~/.config/kitty/*` | static files/ | dot_config/kitty/ | [x] |
| `~/.config/tmux/tmux.conf` | cli/tmux/default.nix (programs.tmux) | dot_config/tmux/tmux.conf | [x] |

### Environment variables (cli/shells.nix, cli/envs.nix)
| Variable | Value | Status |
|---|---|---|
| `ZDOTDIR` | `~/.config/zsh` | [ ] need /etc/zshenv |
| `TERMINAL` | `kitty` | [ ] |
| `MANWIDTH` | `999` | [ ] |
| `GREP_COLOR`, `GREP_COLORS` | color codes | [ ] |
| `EZA_COLORS` | color string | [ ] |

## 2. CLI Tools

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/tig/config` | cli/tig.nix | dot_config/tig/config | [x] |
| `~/.config/bat/config` | cli/search.nix | — | [ ] |
| `~/.config/fd/ignore` | cli/search.nix | — | [ ] |
| `~/.config/ripgrep/ripgreprc` | cli/search.nix | — | [ ] |
| `~/.config/btop/btop.conf` | cli/monitoring.nix | dot_config/btop/btop.conf | [x] |
| `~/.config/broot/*` | static files/ | dot_config/broot/ | [x] |
| `~/.config/television/*` | static files/ | dot_config/television/ | [x] |
| `~/.config/fastfetch/*` | static files/ | dot_config/fastfetch/ | [x] |

### Environment variables (cli/search.nix)
| Variable | Value | Status |
|---|---|---|
| `RIPGREP_CONFIG_PATH` | `~/.config/ripgrep/ripgreprc` | [ ] |
| `FZF_DEFAULT_COMMAND` | fd command | [ ] |
| `FZF_DEFAULT_OPTS` | extensive options | [ ] |
| `FZF_CTRL_R_OPTS` | search options | [ ] |
| `FZF_CTRL_T_OPTS` | file picker options | [ ] |

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
| `~/.config/hypr/init.conf` | static files/ | dot_config/hypr/init.conf | [x] |
| `~/.config/hypr/bindings.conf` | static files/ | dot_config/hypr/bindings.conf | [x] |
| `~/.config/hypr/workspaces.conf` | hyprland/environment.nix (generated) | dot_config/hypr/workspaces.conf | [x] |
| `~/.config/hypr/rules-routing.conf` | hyprland/environment.nix (generated) | dot_config/hypr/rules-routing.conf | [x] |
| `~/.config/hypr/permissions.conf` | hyprland/environment.nix (generated) | — | [~] in init.conf |
| `~/.config/hypr/plugins.conf` | hyprland/environment.nix (conditional) | — | [~] in init.conf |
| `~/.config/hypr/animations/*` | static files/ | dot_config/hypr/animations/ | [x] |
| `~/.config/hypr/bindings/*` | static files/ | dot_config/hypr/bindings/ | [x] |
| `~/.config/hypr/hyprlock/*` | static files/ | dot_config/hypr/hyprlock/ | [x] |

## 5. GUI: Notifications (Dunst)

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/dunst/dunstrc` | gui/dunst.nix (generated INI) | dot_config/dunst/dunstrc | [x] |

### Systemd service: dunst
- Type: dbus, BusName: org.freedesktop.Notifications
- Status: [ ] need to create user service or autostart

## 6. GUI: Theme & Appearance

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/gtk-3.0/settings.ini` | gui/theme.nix (generated INI) | — | [ ] |
| `~/.config/gtk-3.0/gtk.css` | gui/theme.nix | — | [ ] |
| `~/.config/gtk-4.0/settings.ini` | gui/theme.nix (generated INI) | — | [ ] |
| `~/.config/gtk-4.0/gtk.css` | gui/theme.nix | — | [ ] |
| `~/.gtkrc-2.0` | gui/theme.nix | — | [ ] |
| `~/.config/wallust/*` | gui/theme.nix (static files/) | dot_config/wallust/ | [x] |

### Environment variables (gui/theme.nix)
| Variable | Value | Status |
|---|---|---|
| `GTK_THEME` | `Flight-Dark-GTK` | [ ] |
| `XCURSOR_THEME` | `Alkano-aio` | [ ] |
| `XCURSOR_SIZE` | `23` | [ ] |
| `HYPRCURSOR_THEME` | `Alkano-aio` | [ ] |
| `HYPRCURSOR_SIZE` | `23` | [ ] |

## 7. GUI: Qt Theming

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/Kvantum/kvantum.kvconfig` | gui/qt.nix | — | [ ] |
| `~/.config/qt6ct/qt6ct.conf` | gui/qt.nix | — | [ ] |
| `~/.config/qt5ct/qt5ct.conf` | gui/qt.nix | — | [ ] |

### Environment variables (gui/qt.nix)
| Variable | Value | Status |
|---|---|---|
| `QT_QPA_PLATFORMTHEME` | `qt6ct` | [ ] |
| `QT_STYLE_OVERRIDE` | `kvantum` | [ ] |

## 8. GUI: XDG & File Association

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/mimeapps.list` | gui/xdg.nix (generated INI) | — | [ ] |
| `~/.config/user-dirs.dirs` | gui/xdg.nix | — | [ ] |
| desktop entries | gui/xdg.nix | — | [ ] |

## 9. Media: MPV

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/mpv/mpv.conf` | apps/mpv/config.nix | dot_config/mpv/mpv.conf | [x] |
| `~/.config/mpv/input.conf` | apps/mpv/input.nix | dot_config/mpv/input.conf | [x] |
| `~/.config/mpv/profiles.conf` | apps/mpv/profiles.nix | dot_config/mpv/profiles.conf | [x] |
| `~/.config/mpv/styles.ass` | apps/mpv/config.nix | dot_config/mpv/styles.ass | [x] |
| `~/.config/mpv/script-opts/osc.conf` | apps/mpv/scripts.nix | dot_config/mpv/script-opts/osc.conf | [x] |
| `~/.config/mpv/script-opts/uosc.conf` | apps/mpv/scripts.nix | dot_config/mpv/script-opts/uosc.conf | [x] |
| `~/.config/mpv/shaders/*` | apps/mpv/shaders.nix (fetchurl) | dot_config/mpv/shaders/ | [ ] need shader files |

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
| `~/.gnupg/gpg-agent.conf` | sys/gpg.nix | — | [ ] |
| `~/.gnupg/scdaemon.conf` | sys/gpg.nix | — | [ ] |

## 13. Calendar & Contacts

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/khal/config` | sys/khal.nix (generated) | — | [ ] |
| `~/.config/vdirsyncer/config` | sys/vdirsyncer.nix (sops template) | dot_config/vdirsyncer/ | [~] |

## 14. Download Tools

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/aria2/aria2.conf` | web/aria.nix | — | [ ] |
| `~/.config/yt-dlp/config` | web/yt-dlp.nix | — | [ ] |

## 15. Spell Checking

| Config file | NixOS source | Dotfiles path | Status |
|---|---|---|---|
| `~/.config/enchant/enchant.ordering` | sys/enchant.nix | — | [ ] |

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
| `~/.config/Antigravity/User/settings.json` | apps/antigravity.nix | — | [ ] |
| `~/.config/opencode/opencode.json` | apps/opencode.nix | — | [ ] |

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
- **Fully migrated** `[x]`: ~50 files across 12 groups
- **Partially migrated** `[~]`: 4 items
- **Not migrated** `[ ]`: ~40 items across 14 groups
- **Priority for next migration**: GTK theme, Qt theme, XDG mime, search tools (bat/fd/rg), yazi, env vars
