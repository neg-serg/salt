# TODO

## Пайплайн анализа музыки (essentia + annoy)

Скрипты `music-highlevel`, `music-similar`, `music-index` требуют:
- `essentia` (предоставляет `streaming_extractor_music`) — нет в репозиториях Arch, нужен AUR или собственный PKGBUILD
- `python-annoy` — библиотека приближённых ближайших соседей, pip или AUR

Создать отдельный Salt-стейт (`music_analysis.sls` или расширить `installers.sls`):
1. Сборка/установка `essentia` через paru или PKGBUILD
2. Установка `python-annoy` через макрос pip_pkg
3. Идемпотентные проверки для обоих


## ProxyPilot: сломан Claude OAuth + паника tui flag

`proxypilot --claude-login` — OAuth-коллбэк не завершается (токен не сохраняется в `~/.cli-proxy-api/`).
`proxypilot --help` и все флаги `--*-login` паникуют с ошибкой `flag redefined: tui`.
Gemini и Antigravity OAuth работают нормально (токены добавлены вручную до появления бага).

**Обходной путь**: модели Claude доступны через провайдер Antigravity (`claude-sonnet-4-6`, `claude-opus-4-6-thinking`).
Инструменты разработки остаются проксированными (конфиги Claude Code/OpenCode + обёртка `claude-proxy`), а стандартный CLI `claude` теперь обращается к Anthropic напрямую.

- Бинарник: `~/.local/bin/proxypilot` v0.3.0-dev-0.39 (последний релиз всё ещё содержит баг tui flag)
- Конфиг: `~/.config/proxypilot/config.yaml`
- Репо: https://github.com/Finesssee/ProxyPilot
- Перепроверить `--claude-login` и `--gemini-cli-login` после следующего релиза ProxyPilot


## Сервис ydotool не включён

`ydotool.service` (systemd user unit) установлен, но **отключён и неактивен**.
Инструменты Hyprland MCP (`mouse_click`, `click_text`, `key_press` и др.) зависят от работающего `ydotoold`.

**Исправление**: включить пользовательский сервис через Salt (`user_services.sls` или аналог):
```
systemctl --user enable --now ydotool.service
```

Без этого инструменты автоматизации мыши/клавиатуры Hyprland MCP молча падают или выдают ошибки при click/type операциях. Скриншоты работают (используют `grim`/`slurp`, а не ydotool).


## OpenClaw: косметические улучшения

**npmrc prefix**: глобальный npm prefix установлен на `/nonexistent` (из `/etc/npmrc`).
Создать `~/.npmrc` с `prefix=$HOME/.local` через chezmoi (`dotfiles/dot_npmrc`).
Без этого `npm list -g` и `npm outdated -g` не работают (Salt-установка обходит проблему через `--prefix`).

**user_services.yaml**: `openclaw-gateway.service` управляется напрямую из `openclaw_agent.sls`, но не зарегистрирован в `data/user_services.yaml`. Для единообразия можно перенести `user_service_file` + `user_service_enable` туда, оставив в `openclaw_agent.sls` только npm install и конфиг.

**Комментарий к alias ProxyPilot**: формат `name/alias` в `proxypilot.yaml.j2` неочевиден. Добавить комментарий, объясняющий направление маппинга (alias = что шлёт клиент, name = локальный ID модели).


## Упаковка браузера Nyxt

`nyxt-bin` — бинарная упаковка браузера Nyxt. Требуется исследование:
текущий AUR-пакет может быть достаточным, или может потребоваться собственный PKGBUILD.
