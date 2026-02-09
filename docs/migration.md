● All done. Here's a summary of everything that was implemented:

  ★ Insight ─────────────────────────────────────
  Chezmoi vs Salt split strategy: Tridactylrc and themes go in chezmoi dotfiles (~/.config/tridactyl/) because they're user-level config files. But user.js and userChrome.css go to a Flatpak-specific path (~/.var/app/one.ablaze.floorp/.floorp/<profile>/) that's outside
  chezmoi's reach, so Salt file.managed states handle those. This dual-delivery pattern is common when mixing Flatpak apps with dotfile managers.

  RNNoise LADSPA path: The Fedora COPR package uses librnnoise_ladspa (without full path) because PipeWire resolves LADSPA plugins from the standard system path. On NixOS, full Nix store paths are required — one of the key differences when migrating audio configs.
  ─────────────────────────────────────────────────

  Что было сделано
  ┌───────────────────────────────────────────────────────────────────────────┬────────────────────────────────────────────────────────────┐
  │                                  Задача                                   │                           Файлы                            │
  ├───────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────┤
  │ grimblast — Salt state для скачивания с hyprwm/contrib                    │ system_description.sls                                     │
  ├───────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────┤
  │ RNNoise — COPR repo + PipeWire filter-chain конфиг                        │ system_description.sls, 95-rnnoise-filter-chain.conf (new) │
  ├───────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────┤
  │ WirePlumber — default volume 1.0                                          │ 10-default-volume.conf (new)                               │
  ├───────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────┤
  │ Locale — ru_RU.UTF-8 + keymap ru,us декларативно                          │ system_description.sls                                     │
  ├───────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────┤
  │ Tridactyl — tridactylrc, 4 темы, user.js, userChrome.css, userContent.css │ 8 новых файлов в dotfiles/dot_config/tridactyl/            │
  ├───────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────┤
  │ Floorp — Salt states для деплоя user.js и chrome в Flatpak-профиль        │ system_description.sls                                     │
  ├───────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────┤
  │ Firejail — удалён firejail.nix из nixos-config                            │ deleted                                                    │
  ├───────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────┤
  │ Migration doc — 16 новых секций (21-36), обновлены существующие           │ nixos-config-migration.md (236 строк добавлено)            │
  └───────────────────────────────────────────────────────────────────────────┴────────────────────────────────────────────────────────────┘
  Статус миграции теперь: 36 групп, ~140 элементов, ~99% complete. Осталось только: browser extensions (ручная установка) и rescrobbled systemd service (нужны API ключи Last.fm).
