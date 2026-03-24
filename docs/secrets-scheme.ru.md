# Схема управления секретами

## Архитектура

```
gopass (зашифрованное хранилище; допустимый backend: gpg или age)
  |
  +---> chezmoi templates   (dotfiles с секретами)
  +---> salt cmd.run        (systemd-сервисы и т.д.)
```

**Единый источник правды**: `gopass` с допустимым зашифрованным backend.
И chezmoi, и Salt читают секреты из gopass во время деплоя.

Допустимые backend-режимы:

- `gpg`: текущий hardware-backed flow (например YubiKey + GPG agent)
- `age`: flow с password-protected identity и задокументированным backup/recovery

## Структура gopass-хранилища

```
ssh-key                   # Пароль SSH ключа (~/.ssh/id_ed25519)
yubikey-pin               # PIN Yubikey (нужен только при использовании GPG/Yubikey backend)

email/
  gmail/
    app-password          # Gmail App Password (для mbsync/msmtp/imapnotify)
    address               # serg.zorg@gmail.com

caldav/
  google/
    client-id             # Google Calendar OAuth client ID
    client-secret         # Google Calendar OAuth client secret

api/
  brave-search            # Brave Search API key
  github-token            # GitHub personal access token
  context7                # Context7 API key
  proxypilot-local        # API-ключ клиентской авторизации ProxyPilot
  proxypilot-management   # API-ключ management API ProxyPilot
  anthropic               # API-ключ Anthropic (прямой, для OpenClaw)
  openclaw-telegram       # Токен Telegram-бота OpenClaw
  openclaw-telegram-uid   # Telegram user ID для allowlist OpenClaw (основной)
  telegram-uid-levra      # Telegram user ID гостевого пользователя levra
  telegram-uid-guest2     # Telegram user ID гостевого пользователя guest2
  groq                    # API-ключ Groq (бесплатный fallback-провайдер)
  cerebras                # API-ключ Cerebras (бесплатный fallback-провайдер)
  openrouter              # API-ключ OpenRouter (бесплатный fallback-провайдер)
  deepseek                # API-ключ DeepSeek (опционально — пробные 5M токенов)

lastfm/
  password                # Пароль Last.fm (для mpdas)
  username                # Имя пользователя Last.fm (для mpdas)
  api-key                 # API ключ Last.fm (для rescrobbled)
  api-secret              # API secret Last.fm (для rescrobbled)
```

Подробные инструкции по заведению каждого секрета: см. `gopass-setup.ru.md`.

## Интеграция с chezmoi

Dotfiles, содержащие секреты, используют chezmoi-шаблоны (суффикс `.tmpl`):

| Dotfile | Шаблон | gopass-ключ |
|---|---|---|
| `~/.config/mbsync/mbsyncrc` | `dot_config/mbsync/mbsyncrc.tmpl` | `email/gmail/app-password`, `email/gmail/address` |
| `~/.config/msmtp/config` | `dot_config/msmtp/config.tmpl` | `email/gmail/app-password`, `email/gmail/address` |
| `~/.config/imapnotify/gmail.json` | `dot_config/imapnotify/gmail.json.tmpl` | `email/gmail/app-password`, `email/gmail/address` |
| `~/.config/vdirsyncer/config` | `dot_config/vdirsyncer/config.tmpl` | `caldav/google/client-id`, `caldav/google/client-secret` |
| `~/.config/rescrobbled/config.toml` | `dot_config/rescrobbled/config.toml.tmpl` | `lastfm/api-key`, `lastfm/api-secret` |
| `~/.config/zsh/10-secrets.zsh` | `dot_config/zsh/10-secrets.zsh.tmpl` | `api/github-token`, `api/brave-search`, `api/context7`, `api/proxypilot-local` |
| `~/.config/proxypilot/config.yaml` | `dot_config/proxypilot/config.yaml.tmpl` | `api/proxypilot-local`, `api/proxypilot-management` |

Синтаксис шаблонов:
```
# в dot_config/msmtp/config.tmpl
passwordeval   "gopass show -o email/gmail/app-password"
user           {{ gopass "email/gmail/address" }}
```

## Интеграция с Salt

Salt states используют Jinja-макрос `gopass_secret()` (из `_macros_common.jinja`),
который graceful fallback при недоступности gopass:

```yaml
# В .sls файле:
{%- set lastfm_user = gopass_secret('lastfm/username') | trim %}
{%- set lastfm_pass = gopass_secret('lastfm/password') | trim %}
mpdas_config:
  file.managed:
    - name: {{ home }}/.config/mpdasrc
    - mode: '0600'
    - replace: False
    - contents: |
        host = localhost
        port = 6600
        username = {{ lastfm_user }}
        password = {{ lastfm_pass }}
```

Макрос сначала пробует `gopass show -o <key>`. Если не удаётся (retcode != 0),
выполняет опциональную fallback-команду (по умолчанию `true`, что даёт пустую строку).

Salt states, использующие макрос `gopass_secret()` (с graceful fallback, если gopass недоступен):

| State | gopass-ключ | Fallback |
|---|---|---|
| `mpd.sls` | `lastfm/username`, `lastfm/password` | Пустая строка |
| `opencode.sls` | `api/proxypilot-local`, `api/proxypilot-management`, `api/groq`, `api/cerebras`, `api/openrouter` | Парсинг существующего конфига ProxyPilot (AWK-фолбэк) |
| `openclaw_agent.sls` | `api/proxypilot-local`, `api/openclaw-telegram`, `api/openclaw-telegram-uid`, `api/telegram-uid-levra`, `api/telegram-uid-guest2`, `api/groq` | Парсинг существующего конфига / credential-файлы |
| `telethon_bridge.sls` | `api/proxypilot-local`, `api/telegram-telethon-id`, `api/telegram-telethon-hash`, `api/openclaw-telegram-uid`, `api/telegram-uid-levra`, `api/telegram-uid-guest2` | Credential-файлы |

## Шаги настройки

1. **Инициализировать gopass-хранилище** (если ещё не создано):
   ```
   # Существующий hardware-backed flow
   gopass init <GPG-KEY-ID>

   # Password-based age flow
   gopass age identities keygen
   gopass init --crypto age

   gopass git init
   ```

2. **Заполнить секреты**:
   ```
   gopass insert email/gmail/app-password
   gopass insert email/gmail/address
   gopass insert caldav/google/client-id
   gopass insert caldav/google/client-secret
   gopass insert api/brave-search
   gopass insert api/github-token
   gopass insert api/context7
   gopass insert lastfm/password
   gopass insert lastfm/username
   gopass insert lastfm/api-key
   gopass insert lastfm/api-secret
   ```

3. **Настроить chezmoi** (деплоится Salt из `dotfiles/dot_config/chezmoi/chezmoi.toml`):
   ```toml
   [gopass]
   command = "gopass"
   ```

4. **Развернуть dotfiles с секретами**:
   ```
   chezmoi apply
   ```

## Свойства безопасности

- Секреты остаются зашифрованными в покое через `gopass`
- `gpg` backend может требовать hardware-backed unlock, например касание YubiKey
- `age` backend может использовать password-protected identity и agent-assisted session unlock
- gopass-хранилище можно версионировать в отдельном приватном git-репозитории
- Никаких открытых секретов в репозиториях salt/ или dotfiles/
- chezmoi-шаблоны содержат только ссылки на gopass, а не реальные значения
- Отрендеренные файлы с секретами получают права 0600
- Миграции backend должны сохранять пути секретов, поддерживать один активный source of truth и хранить rollback artifacts до конца stabilization window
