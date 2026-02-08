# gopass Setup Guide

## 1. Инициализация gopass

```bash
# Если gopass store ещё не существует
gopass init <GPG-KEY-ID>
gopass git init

# Проверка
gopass ls
```

## 2. Заполнение секретов

### Email (Gmail)
```bash
gopass insert email/gmail/app-password    # App Password из https://myaccount.google.com/apppasswords
gopass insert email/gmail/address         # serg.zorg@gmail.com
```

### Calendar (Google OAuth)
```bash
gopass insert caldav/google/client-id     # OAuth Client ID из Google Cloud Console
gopass insert caldav/google/client-secret  # OAuth Client Secret
```

### Last.fm (mpdas + rescrobbled)
```bash
gopass insert lastfm/username             # Last.fm username
gopass insert lastfm/password             # Last.fm password (для mpdas)
gopass insert lastfm/api-key              # API key из https://www.last.fm/api/account/create
gopass insert lastfm/api-secret           # API secret оттуда же
```

### API Keys (opencode)
```bash
gopass insert api/github-token            # GitHub PAT из https://github.com/settings/tokens
gopass insert api/brave-search            # Brave Search API key
gopass insert api/context7                # Context7 API key
```

## 3. Применение Salt state

```bash
# Деплоит chezmoi.toml, создаёт каталоги для почты, устанавливает systemd-сервисы
sudo salt-call state.apply
```

## 4. Применение chezmoi (рендеринг шаблонов)

```bash
# Превью — что будет изменено (без записи на диск)
chezmoi diff

# Применить (потребуется Yubikey для gopass)
chezmoi apply -v
```

## 5. Активация systemd-сервисов

```bash
# Почта
systemctl --user enable --now mbsync-gmail.timer
systemctl --user enable --now imapnotify-gmail.service

# Календарь
systemctl --user enable --now vdirsyncer.timer

# Проверка
systemctl --user list-timers
systemctl --user status mbsync-gmail.timer imapnotify-gmail vdirsyncer.timer
```

## 6. Первичная синхронизация

```bash
# Почта — первый полный sync (может занять время)
mbsync gmail

# Notmuch — инициализация базы
notmuch new

# Календарь — первый sync (попросит OAuth авторизацию в браузере)
vdirsyncer discover
vdirsyncer sync
```

## 7. Проверка

```bash
# gopass store
gopass ls

# chezmoi — все шаблоны отрендерены
chezmoi verify

# Почта
ls ~/.local/mail/gmail/INBOX/

# Календарь
khal list today 7d

# MPD scrobbling
systemctl --user status rescrobbled

# API keys в окружении
source ~/.config/zsh/10-secrets.zsh
echo $GITHUB_TOKEN | head -c4    # должно показать начало токена
```
