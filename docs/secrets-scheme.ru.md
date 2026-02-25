# Схема управления секретами

## Архитектура

```
gopass (GPG-зашифрованное хранилище, Yubikey)
  |
  +---> chezmoi templates   (dotfiles с секретами)
  +---> salt cmd.run         (systemd-сервисы и т.д.)
```

**Единый источник правды**: `gopass` с GPG-бэкендом (аппаратный ключ Yubikey).
И chezmoi, и Salt читают секреты из gopass во время деплоя.

## Структура gopass-хранилища

```
ssh-key                   # Пароль SSH ключа (~/.ssh/id_ed25519)
yubikey-pin               # PIN Yubikey (для разблокировки GPG)

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
| `~/.config/zsh/10-secrets.zsh` | `dot_config/zsh/10-secrets.zsh.tmpl` | `api/github-token`, `api/brave-search`, `api/context7` |

Синтаксис шаблонов:
```
# в dot_config/msmtp/config.tmpl
passwordeval   "gopass show -o email/gmail/app-password"
user           {{ gopass "email/gmail/address" }}
```

## Интеграция с Salt

Для Salt states, которым нужны секреты (например, конфиг mpdas в `mpd.sls`):

```yaml
mpdas_config:
  cmd.run:
    - name: |
        USER=$(gopass show -o lastfm/username)
        PASS=$(gopass show -o lastfm/password)
        cat > ~/.config/mpdas/mpdas.rc << EOF
        host = localhost
        port = 6600
        service = lastfm
        username = ${USER}
        password = ${PASS}
        EOF
    - runas: neg
    - creates: ~/.config/mpdas/mpdas.rc
```

## Шаги настройки

1. **Инициализировать gopass-хранилище** (если ещё не создано):
   ```
   gopass init <GPG-KEY-ID>
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

- Секреты зашифрованы в покое с помощью GPG (AES-256)
- Расшифровка требует физического касания Yubikey
- gopass-хранилище можно версионировать в отдельном приватном git-репозитории
- Никаких открытых секретов в репозиториях salt/ или dotfiles/
- chezmoi-шаблоны содержат только ссылки на gopass, а не реальные значения
- Отрендеренные файлы с секретами получают права 0600
