# Руководство по настройке gopass

Пошаговая инструкция по заведению всех секретов для Salt/chezmoi конфигурации.
Каждый секрет используется в chezmoi-шаблонах или Salt states — без них деплой упадёт.

## 0. Предварительная проверка

```bash
# Проверить, что gopass инициализирован
gopass ls

# Посмотреть, какие секреты уже есть, а какие отсутствуют
for key in \
    email/gmail/app-password email/gmail/address \
    caldav/google/client-id caldav/google/client-secret \
    lastfm/username lastfm/password lastfm/api-key lastfm/api-secret \
    api/github-token api/brave-search api/context7 \
    api/proxypilot-local api/proxypilot-management \
    api/anthropic api/openclaw-telegram api/openclaw-telegram-uid \
    ssh-key yubikey-pin; do
  if gopass show -o "$key" >/dev/null 2>&1; then
    echo "  ✓ $key"
  else
    echo "  ✗ $key  (MISSING)"
  fi
done
```

---

## 1. Инициализация gopass (если хранилище не существует)

Выберите один допустимый backend и сохраняйте те же `gopass`-пути секретов независимо
от backend:

```bash
# GPG backend (текущий hardware-backed flow)
gopass init <GPG-KEY-ID>

# age backend (password-protected identity flow)
gopass age identities keygen
gopass init --crypto age

gopass git init

# Проверка
gopass ls
```

---

## 2. SSH и backend-specific unlock material (скрипт `unlock`)

Используются в: `~/.local/bin/unlock` — автоматический unlock SSH ключей при логине.

### 2a. Пароль SSH ключа

```bash
# Пароль от ~/.ssh/id_ed25519
gopass insert ssh-key
```

### 2b. PIN Yubikey

```bash
# PIN для разблокировки Yubikey GPG ключа. Используется только с GPG/Yubikey backend.
gopass insert yubikey-pin
```

### 2c. Разблокировка age identity

Если используется `age` backend, защитите сгенерированную identity сильным паролем и
храните инструкции по recovery вне самого store. Рекомендуемый session flow:

```bash
# Однократная настройка
gopass age identities keygen

# Опциональный session agent
gopass config age.agent-enabled true
gopass age agent start
```

Сделайте отдельный backup для `age` identity и пароля, который её разблокирует.
Не удаляйте прежний GPG/Yubikey access path, пока не закончится stabilization window
после миграции.

---

## 3. Email — Gmail

Используются в: `mbsync` (получение почты), `msmtp` (отправка), `imapnotify` (push-уведомления).
Шаблоны: `dot_config/mbsync/mbsyncrc.tmpl`, `dot_config/msmtp/config.tmpl`, `dot_config/imapnotify/gmail.json.tmpl`

### 3a. Gmail адрес

```bash
gopass insert email/gmail/address
# Ввести: ваш gmail адрес (например serg.zorg@gmail.com)
```

### 3b. Gmail App Password

**Где получить:**
1. Перейти на https://myaccount.google.com/apppasswords
2. Выбрать имя приложения (например "mbsync")
3. Нажать "Create"
4. Скопировать сгенерированный 16-символьный пароль

**Требования:** на аккаунте должна быть включена 2FA (без неё App Passwords недоступны).

```bash
gopass insert email/gmail/app-password
# Ввести: 16-символьный App Password (без пробелов)
```

---

## 4. Календарь — Google OAuth (vdirsyncer)

Используются в: `vdirsyncer` (синхронизация Google Calendar → локальные .ics файлы).
Шаблон: `dot_config/vdirsyncer/config.tmpl`

**Где получить:**
1. Перейти на https://console.cloud.google.com/
2. Создать проект (или выбрать существующий)
3. Перейти в **APIs & Services → Library**
4. Найти и включить **Google Calendar API**
5. Перейти в **APIs & Services → Credentials**
6. Нажать **Create Credentials → OAuth client ID**
7. Тип приложения: **Desktop app**
8. Имя: любое (например "vdirsyncer")
9. Нажать **Create**
10. Скопировать **Client ID** и **Client Secret**

**Важно:** Также нужно настроить OAuth consent screen:
- **APIs & Services → OAuth consent screen**
- User type: External (или Internal, если Google Workspace)
- Добавить scope: `Google Calendar API — .../auth/calendar`
- Добавить свой email в test users (если приложение в Testing статусе)

```bash
gopass insert caldav/google/client-id
# Ввести: Client ID (формат: xxxx.apps.googleusercontent.com)

gopass insert caldav/google/client-secret
# Ввести: Client Secret (формат: GOCSPX-xxx)
```

---

## 5. Last.fm (mpdas + rescrobbled)

Используются в: `mpdas` (scrobbler через Salt state `mpd.sls`), `rescrobbled` (альтернативный scrobbler).
Шаблон: `dot_config/rescrobbled/config.toml.tmpl`

### 5a. Логин и пароль Last.fm

```bash
gopass insert lastfm/username
# Ввести: ваш Last.fm username

gopass insert lastfm/password
# Ввести: ваш Last.fm пароль
```

### 5b. API ключи Last.fm

**Где получить:**
1. Перейти на https://www.last.fm/api/account/create
2. Залогиниться (если не залогинены)
3. Заполнить форму:
   - Application name: любое (например "rescrobbled")
   - Application description: любое
   - Callback URL: оставить пустым
4. Нажать **Submit**
5. Скопировать **API key** и **Shared secret**

```bash
gopass insert lastfm/api-key
# Ввести: API key (32 hex символа)

gopass insert lastfm/api-secret
# Ввести: Shared secret (32 hex символа)
```

---

## 6. API ключи (zsh окружение)

Используются в: `~/.config/zsh/10-secrets.zsh` — экспортируются как переменные окружения.
Шаблон: `dot_config/zsh/10-secrets.zsh.tmpl`

### 6a. GitHub Personal Access Token

**Где получить:**
1. Перейти на https://github.com/settings/tokens?type=beta
2. Нажать **Generate new token**
3. Выбрать нужные permissions (минимум: `repo`, `read:org`)
4. Установить срок действия
5. Нажать **Generate token**
6. Скопировать токен (показывается один раз!)

```bash
gopass insert api/github-token
# Ввести: github_pat_xxx или ghp_xxx
```

### 6b. Brave Search API Key

**Где получить:**
1. Перейти на https://api.search.brave.com/app/keys
2. Зарегистрироваться / залогиниться
3. Создать ключ (Free план: 2000 запросов/мес)
4. Скопировать API key

```bash
gopass insert api/brave-search
# Ввести: BSA-xxx
```

### 6c. Context7 API Key

**Где получить:**
1. Перейти на https://context7.com/
2. Зарегистрироваться / залогиниться
3. Получить API key в настройках аккаунта

```bash
gopass insert api/context7
# Ввести: ваш Context7 API key
```

---

## 7. ProxyPilot + OpenClaw (AI-инструментарий)

Используются в: ProxyPilot (AI API прокси), OpenClaw (AI агент-шлюз), OpenCode (TUI-агент).
Шаблоны: `dot_config/proxypilot/config.yaml.tmpl`, `dot_config/zsh/10-secrets.zsh.tmpl`
Salt states: `opencode.sls`, `openclaw_agent.sls`

### 7a. ProxyPilot API Key (клиентская авторизация)

Этот ключ аутентифицирует локальные AI-инструменты (Claude Code, OpenCode) через ProxyPilot-прокси.

```bash
gopass insert api/proxypilot-local
# Ввести: API-ключ для клиентской авторизации ProxyPilot
```

### 7b. ProxyPilot Management Key

Доступ к дашборду/статистике прокси через management API (только localhost).

```bash
gopass insert api/proxypilot-management
# Ввести: management API key
```

### 7c. Anthropic API Key (прямой доступ)

Используется OpenClaw как основной провайдер (прямой доступ к Anthropic API).

```bash
gopass insert api/anthropic
# Ввести: sk-ant-xxx (API-ключ Anthropic)
```

### 7d. OpenClaw Telegram-бот

Используется OpenClaw для интеграции с Telegram.

```bash
gopass insert api/openclaw-telegram
# Ввести: токен Telegram-бота (формат: 123456:ABC-DEF...)

gopass insert api/openclaw-telegram-uid
# Ввести: Telegram user ID для allowlist (например 109503498)
```

---

## 8. Справка по bootstrap backend

### 8a. GPG Key ID

При инициализации GPG backend (шаг 1) `<GPG-KEY-ID>` — это fingerprint вашего GPG-ключа.
Как его найти:

```bash
gpg --list-keys --keyid-format long
# Ищите 40-символьный fingerprint или 16-символьный key ID после "rsa4096/"
# Пример: gpg --list-keys покажет "Key fingerprint = ABCD 1234 ..."
# Используйте полный fingerprint: gopass init ABCD1234...
```

Если используется Yubikey, ключ находится на карте:

```bash
gpg --card-status
# Ищите строку "General key info" — это ваш key ID
```

### 8b. Recovery для age identity

При инициализации `age` backend:

- сгенерируйте identity один раз и защитите её сильным паролем;
- храните backup identity отдельно от рабочего store;
- задокументируйте, как разблокировать её на новой машине, прежде чем убирать legacy GPG access.

---

## 9. Применение

После заведения всех секретов:

```bash
# Проверить, что все секреты на месте (скрипт из шага 0)
# Затем:

# Salt state — деплоит конфиги, systemd-сервисы
sudo salt-call state.apply

# Chezmoi — рендерит шаблоны с секретами (потребует рабочий gopass unlock path)
chezmoi diff      # превью изменений
chezmoi apply -v  # применить
```

---

## 10. Активация сервисов

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

---

## 11. Первичная синхронизация

```bash
# Почта — первый полный sync (может занять время)
mbsync gmail

# Notmuch — инициализация поисковой базы
notmuch new

# Календарь — первый sync (откроет браузер для OAuth авторизации)
vdirsyncer discover
vdirsyncer sync
```

---

## 12. Финальная проверка

```bash
# Все секреты на месте
gopass ls

# chezmoi — нет расхождений
chezmoi verify

# Почта
ls ~/.local/mail/gmail/INBOX/

# Календарь
khal list today 7d

# MPD scrobbling
systemctl --user status rescrobbled

# API keys в окружении
source ~/.config/zsh/10-secrets.zsh
echo $GITHUB_TOKEN | head -c4    # начало токена
echo $BRAVE_API_KEY | head -c4
```
