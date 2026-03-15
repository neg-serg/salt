# TODO

## Пайплайн анализа музыки (essentia + annoy)

Скрипты `music-highlevel`, `music-similar`, `music-index` требуют:
- `essentia` (предоставляет `streaming_extractor_music`) — нет в репозиториях Arch, нужен AUR или собственный PKGBUILD
- `python-annoy` — библиотека приближённых ближайших соседей, pip или AUR

Создать отдельный Salt-стейт (`music_analysis.sls` или расширить `installers.sls`):
1. Сборка/установка `essentia` через paru или PKGBUILD
2. Установка `python-annoy` через макрос pip_pkg
3. Идемпотентные проверки для обоих


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


## SaluteSpeech — оценка STT/TTS

Оценить [SaluteSpeech](https://developers.sber.ru/docs/ru/salutespeech/overview) (Сбер) для распознавания (STT) и синтеза (TTS) русской речи.

- Freemium: ~1000 мин/мес STT бесплатно
- Сравнить с локальными альтернативами: `faster-whisper` (large-v3), Vosk
- Решение: облачный API (SaluteSpeech) vs self-hosted (Whisper на GPU)
- При внедрении: Salt-стейт для установки, API-ключ в gopass, systemd-сервис
