# Настройка Telethon Bridge

## Обзор

Автономный AI-агент, соединяющий Telegram (MTProto userbot) с ProxyPilot для
AI-диалогов. В отличие от бот-интеграций, использует сессию обычного аккаунта
Telegram (Telethon), что снимает ограничения BotFather. Развертывается как
systemd user service через Salt.

## Архитектура

```
Telegram (MTProto)
        |
        v
+---------------------------+
|  telethon-bridge           |  <- systemd user service
|  http://127.0.0.1:8319     |     health endpoint
+------------+--------------+
             |
             v
+---------------------------+
|  ProxyPilot               |  <- OpenAI-совместимый прокси
|  http://127.0.0.1:8317    |     Claude OAuth, DeepSeek, Groq и др.
+---------------------------+
```

## Требования

- Запущенный ProxyPilot (порт 8317)
- Настроенный gopass с GPG/Yubikey
- API-ключи Telegram с [my.telegram.org](https://my.telegram.org) (api_id + api_hash)

## Шаги установки

### 1. Создание секретов в gopass

```bash
gopass insert api/telegram-telethon-id    # Числовой API ID
gopass insert api/telegram-telethon-hash  # API hash (hex-строка)
```

`api/proxypilot-local` уже используется другими инструментами -- ничего делать не нужно.

### 2. Развертывание через Salt

```bash
just apply telethon_bridge
```

Развертывает скрипт, конфигурацию и systemd unit. Сервис не запустится
автоматически -- сначала необходимо инициализировать файл сессии.

### 3. Инициализация сессии

```bash
telethon-bridge-init
```

Запросит номер телефона, код подтверждения, опционально 2FA. Сессия сохраняется
в `~/.telethon-bridge/telethon.session`.

Этот шаг интерактивный и выполняется однократно (или после аннулирования сессии).

### 4. Запуск сервиса

```bash
systemctl --user start telethon-bridge
systemctl --user status telethon-bridge
```

Unit содержит `ConditionPathExists=%h/.telethon-bridge/telethon.session` --
сервис откажется запускаться без валидного файла сессии.

## Справка по конфигурации

| Секция | Описание |
|---|---|
| `telegram` | API-ключи, путь к сессии, настройки подключения |
| `ai` | Эндпоинт ProxyPilot, выбор модели, системный промпт |
| `profiles` | Именованные пресеты промптов/моделей (например, `default`, `concise`) |
| `allowlist` | ID пользователей/чатов Telegram с разрешением на взаимодействие |
| `channels` | Переопределения поведения для отдельных каналов |
| `groups` | Настройки групповых чатов (вкл./выкл., триггер по упоминанию) |
| `automation` | Правила автоответа, запланированные сообщения |
| `service` | Адрес привязки health endpoint, уровень логирования |

## Проверка здоровья

```bash
curl -s http://127.0.0.1:8319/health | jq
```

Возвращает JSON со статусом подключения, временем работы и информацией об активной сессии.

## Команды владельца

Команды отправляются как Telegram-сообщения в любом отслеживаемом чате:

| Команда | Описание |
|---|---|
| `/clear` | Очистить историю диалога |
| `/export <chat_id> [limit]` | Экспортировать историю чата в JSON |

## Управление сервисом

```bash
systemctl --user status telethon-bridge      # статус
systemctl --user restart telethon-bridge     # перезапуск
systemctl --user stop telethon-bridge        # остановка
journalctl --user -u telethon-bridge -f      # логи в реальном времени
```

## Устранение неполадок

**Сессия аннулирована**: Telegram может отозвать сессии после смены пароля или
длительного бездействия. Повторите `telethon-bridge-init` для создания новой сессии,
затем перезапустите сервис.

**FloodWait**: Сервис автоматически ждет требуемое время. Проверьте логи на наличие
`FloodWaitError` и период ожидания:
```bash
journalctl --user -u telethon-bridge -f
```

**ProxyPilot недоступен**: Сообщения получают ответ с ошибкой, сервис продолжает
работать. Восстанавливается автоматически при возвращении ProxyPilot.

**Сервис не запускается**: Проверьте `ConditionPathExists` -- файл сессии должен
существовать:
```bash
ls -la ~/.telethon-bridge/telethon.session
```
Если отсутствует, выполните `telethon-bridge-init`. Если файл есть, но сервис
все равно не запускается, проверьте логи на ошибки аутентификации.

**Просмотр логов**:
```bash
journalctl --user -u telethon-bridge -f
journalctl --user -u telethon-bridge --since "10 min ago"
```
