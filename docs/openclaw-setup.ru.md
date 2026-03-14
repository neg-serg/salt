# OpenClaw: руководство по настройке

## Обзор

OpenClaw — локальный AI-агент gateway. Все модели маршрутизируются через ProxyPilot
(доступ к Claude через OAuth, DeepSeek, Groq, Cerebras и др.).
Предоставляет Web UI (чат-панель) и канал Telegram-бота.

## Архитектура

```
Браузер / Telegram
        │
        ▼
┌─────────────────────────┐
│  openclaw-gateway       │  ← systemd user service
│  ws://127.0.0.1:18789   │     auth: token
└──────────┬──────────────┘
           │
           │
           ▼
┌─────────────────────────┐
│  ProxyPilot             │  ← OpenAI-совместимый прокси
│  http://127.0.0.1:8317  │     Claude OAuth, DeepSeek, Groq и др.
└─────────────────────────┘
```

## Компоненты

| Компонент | Путь / описание |
|---|---|
| Бинарник | `~/.local/bin/openclaw` (npm, версия зафиксирована в `data/versions.yaml`) |
| Конфиг | `~/.openclaw/openclaw.json` (начальный seed от Salt, далее управляется OpenClaw) |
| Сервис | `~/.config/systemd/user/openclaw-gateway.service` |
| Salt-стейт | `states/openclaw_agent.sls` |
| Шаблон конфига | `states/configs/openclaw.json.j2` |
| Unit-файл | `states/units/user/openclaw-gateway.service` |
| Порт | `127.0.0.1:18789` (только loopback) |
| Аутентификация | Токен (автогенерация при первом запуске) |

## Секреты (gopass)

| Ключ | Назначение |
|---|---|
| `api/proxypilot-local` | API-ключ ProxyPilot (общий с Claude Code, OpenCode) |
| `api/openclaw-telegram` | Токен Telegram-бота (`@negserg_openclaw_bot`) |
| `api/openclaw-telegram-uid` | Числовой Telegram ID пользователя для allowlist |

Создание секретов перед первым Salt apply:
```bash
gopass insert api/openclaw-telegram   # вставить токен бота от @BotFather
```

`api/proxypilot-local` уже используется другими инструментами — ничего делать не нужно.

## Доступ к Web UI

1. Открыть `http://127.0.0.1:18789/`
2. Ввести токен аутентификации gateway (однократно, сохраняется в localStorage браузера)
3. Получить токен: `grep -o '"token":"[^"]*"' ~/.openclaw/openclaw.json | head -1`

Или открыть с токеном в URL (автоматическая аутентификация):
```bash
handlr open "http://127.0.0.1:18789/?token=$(python3 -c "import json; print(json.load(open('$HOME/.openclaw/openclaw.json'))['gateway']['auth']['token'])")"
```

## Команды CLI

```bash
openclaw status              # статус gateway + аудит безопасности
openclaw status --deep       # полная проверка (тесты каналов, моделей)
openclaw doctor              # диагностика конфигурации
openclaw doctor --fix        # автоматическое исправление проблем
openclaw models list         # доступные модели
openclaw logs --follow       # логи gateway в реальном времени
openclaw config get gateway  # просмотр секции gateway конфига
```

## Управление сервисом

```bash
systemctl --user status openclaw-gateway     # статус
systemctl --user restart openclaw-gateway    # перезапуск
systemctl --user stop openclaw-gateway       # остановка
journalctl --user -u openclaw-gateway -f     # логи в реальном времени
```

## Модели

| Модель | Провайдер | Роль |
|---|---|---|
| `proxypilot/claude-sonnet-4-6` | ProxyPilot (Claude OAuth) | Основная |
| `proxypilot/claude-opus-4-6` | ProxyPilot (Claude OAuth) | Запасная |

## Telegram-бот

- Бот: `@negserg_openclaw_bot`
- Политика DM: `allowlist` (только разрешённые пользователи)
- Разрешённые: числовой ID из `gopass show -o api/openclaw-telegram-uid`
- Политика групп: `disabled`
- Изоляция сессий: `per-channel-peer` (каждый отправитель получает свою сессию)

## Управление конфигурацией

OpenClaw перезаписывает `~/.openclaw/openclaw.json` при запуске (добавляет метаданные, значения по умолчанию, переупорядочивает ключи).
Salt использует `replace: False` — конфиг создаётся только при первоначальном развёртывании.

Для принудительного пересоздания после изменения Jinja-шаблона:
```bash
rm ~/.openclaw/openclaw.json
just   # Salt пересоздаст конфиг из шаблона
systemctl --user restart openclaw-gateway
```

## Защита systemd

Unit-файл `openclaw-gateway.service` усилен директивами безопасности, снижающими поверхность атаки. Оценка безопасности: **2.9 OK** (было 8.2 EXPOSED).

Основные директивы:
- `CapabilityBoundingSet=` — сброс всех Linux capabilities
- `SystemCallFilter=@system-service` — ограничение допустимых системных вызовов
- `ProtectSystem=strict` — файловая система только для чтения (кроме `WorkingDirectory`)
- `ProtectKernel{Tunables,Modules,Logs}=yes` — блокировка изменений ядра
- `NoNewPrivileges=true`, `RestrictSUIDSGID=yes` — предотвращение повышения привилегий
- `PrivateTmp=yes`, `KeyringMode=private` — изоляция временных файлов и связок ключей
- `MemoryMax=2G` — ограничение потребления памяти (OOM-kill при превышении)
- `StartLimitBurst=5` / `StartLimitIntervalSec=300` — защита от циклических перезапусков

**Не включены** (ограничения V8/Node.js):
- `MemoryDenyWriteExecute=yes` — V8 JIT требует W+X страницы
- `PrivateDevices=yes` — mpv требует `/dev/dri` для GPU-видеовывода

Проверка оценки безопасности:
```bash
systemd-analyze --user security openclaw-gateway.service
```

## Проверки здоровья (Health Checks)

OpenClaw предоставляет структурированную проверку здоровья через CLI:
```bash
openclaw gateway health --json --timeout 5000
```

Возвращает JSON с `.ok` (общее здоровье), `.channels.telegram.probe.ok` (подключение Telegram), количество сессий и статус агентов.

**Интеграция с salt-monitor**: Демон мониторинга (`salt-monitor`) опрашивает эту команду каждые 15 секунд через `health_cmd` + `health_parse` (jq-выражение). При 2 последовательных неудачных проверках автоматически перезапускает сервис (до 3 раз за 5-минутное окно). При исчерпании попыток алерт повышается до critical.

Проверка здоровья вручную:
```bash
openclaw gateway health --json | jq '{ok, channels: .channels.telegram.probe.ok}'
openclaw gateway status --json   # подробный статус с сессиями
```

## Защита от злоупотреблений

OpenClaw работает с двухагентной конфигурацией:

| Агент | Уровень доступа |
|---|---|
| **Main (Owner)** | Полный доступ к инструментам (`profile: "full"`) |
| **Guest** | Минимальный — запрещены: `exec`, `browser`, `gateway`, `cron`, `write`, `edit`; файловая система ограничена рабочей директорией |

Дополнительные меры:
- **Политика DM**: `allowlist` — взаимодействовать могут только пользователи из белого списка
- **Политика групп**: `disabled` — бот игнорирует групповые чаты
- **Изоляция сессий**: `per-channel-peer` — каждый отправитель получает свою сессию
- **Параллелизм**: `maxConcurrent: 4` (по умолчанию OpenClaw) ограничивает одновременные ходы агентов
- **Привязка агентов**: Гостевые пользователи привязаны по Telegram peer ID — не могут получить доступ к Main-агенту

## Решение проблем

**Предупреждения о несовпадении версий**: убедитесь, что нет системной установки openclaw (`which -a openclaw` должен показывать только `~/.local/bin/openclaw`).

**Ошибки аутентификации в Web UI**: перезапустите gateway для сброса rate limit, затем перезагрузите страницу с параметром `?token=...`.

**Telegram не подключается**: проверьте `gopass show -o api/openclaw-telegram` — должен вернуть валидный токен бота. Проверка: `openclaw status --deep`.

**ProxyPilot недоступен**: убедитесь, что `systemctl --user is-active proxypilot` возвращает `active`. Unit gateway имеет `Wants=proxypilot.service`. При недоступности ProxyPilot бот возвращает ошибку пользователю в течение ~15 секунд.

**MemoryMax OOM**: если сервис убит по OOM, проверьте `journalctl --user -u openclaw-gateway | grep -i oom`. Лимит 2G покрывает нормальную работу; постоянные OOM могут указывать на утечку — сообщите разработчикам.

**StartLimitBurst исчерпан**: если сервис не запускается (`start-limit-hit`), подождите 5 минут или сбросьте: `systemctl --user reset-failed openclaw-gateway.service`.

**Повреждение конфига**: Санитайзер `ExecStartPre` проверяет синтаксис JSON перед запуском. При невалидном JSON сервис не запустится, в логах будет `openclaw-sanitize: invalid JSON in config`. Исправьте JSON или пересоздайте: `rm ~/.openclaw/openclaw.json && just apply openclaw_agent`.
