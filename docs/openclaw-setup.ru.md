# OpenClaw: руководство по настройке

## Обзор

OpenClaw — локальный AI-агент gateway, маршрутизирующий все запросы через ProxyPilot.
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
           │ OpenAI-совместимый API
           ▼
┌─────────────────────────┐
│  ProxyPilot             │  ← маршрутизация к Claude через OAuth
│  http://127.0.0.1:8317  │
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

Все модели маршрутизируются через ProxyPilot (`http://127.0.0.1:8317/v1`):

| Модель | Роль |
|---|---|
| `proxypilot/claude-opus-4-6` | Основная (по умолчанию для всех агентов) |
| `proxypilot/claude-sonnet-4-6` | Запасная |

## Telegram-бот

- Бот: `@negserg_openclaw_bot`
- Политика DM: `open` (принимает сообщения от всех)
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

## Решение проблем

**Предупреждения о несовпадении версий**: убедитесь, что нет системной установки openclaw (`which -a openclaw` должен показывать только `~/.local/bin/openclaw`).

**Ошибки аутентификации в Web UI**: перезапустите gateway для сброса rate limit, затем перезагрузите страницу с параметром `?token=...`.

**Telegram не подключается**: проверьте `gopass show -o api/openclaw-telegram` — должен вернуть валидный токен бота. Проверка: `openclaw status --deep`.

**ProxyPilot недоступен**: убедитесь, что `systemctl --user is-active proxypilot` возвращает `active`. Unit gateway имеет `Requires=proxypilot.service`.
