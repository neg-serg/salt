# ProxyPilot: Бесплатные модели для аварийного fallback

## Обзор

Система аварийного fallback с бесплатными AI-моделями на случай недоступности платных провайдеров (Anthropic, Google Gemini). Используются 3 облачных провайдера + локальный Ollama как последнее средство.

## Архитектура

- Секция `openai-compatibility` в конфигурации ProxyPilot маршрутизирует запросы к бесплатным провайдерам
- Пулинг алиасов: общие алиасы `fallback-*` обеспечивают round-robin между провайдерами
- Только аварийный режим: бесплатные провайдеры доступны исключительно через алиасы `fallback-*`
- Каскад: Groq → Cerebras → OpenRouter → Ollama (локальный)

## Провайдеры

| Приоритет | Провайдер | Модели | Алиас | Лимиты |
|-----------|-----------|--------|-------|--------|
| 1 | Groq | llama-3.3-70b-versatile | fallback-large | 1K запросов/день |
| 1 | Groq | qwen/qwen3-32b | fallback-medium | 1K запросов/день |
| 2 | Cerebras | qwen-3-235b-a22b-instruct | fallback-large | 1M токенов/день |
| 2 | Cerebras | llama3.1-8b | fallback-small | 1M токенов/день |
| 3 | OpenRouter | qwen/qwen3-coder-480b-a35b:free | fallback-code | 200 запросов/день |
| 3 | OpenRouter | openrouter/auto | fallback-large | 200 запросов/день |
| 4 | Ollama | qwen3.5:27b | fallback-large | Локальный GPU |
| 4 | Ollama | qwen2.5-coder:7b | fallback-code | Локальный GPU |
| 4 | Ollama | qwen3:14b | fallback-medium | Локальный GPU |

Исключённые провайдеры:

- Mistral -- блокирует регистрацию из России
- SambaNova -- нет доступа из России

## Покрытие алиасов

| Алиас | Провайдеры | Модели |
|-------|------------|--------|
| fallback-large | Groq, Cerebras, OpenRouter, Ollama | 4 модели, 4 провайдера |
| fallback-code | OpenRouter, Ollama | 2 модели, 2 провайдера |
| fallback-medium | Groq, Ollama | 2 модели, 2 провайдера |
| fallback-small | Cerebras | 1 модель, 1 провайдер |

## Секреты (gopass)

| Путь | Провайдер | URL регистрации |
|------|-----------|-----------------|
| `api/groq` | Groq | https://console.groq.com |
| `api/cerebras` | Cerebras | https://cloud.cerebras.ai |
| `api/openrouter` | OpenRouter | https://openrouter.ai/keys |

## Добавление провайдера

1. Добавить запись в `states/data/free_providers.yaml`
2. Сохранить API-ключ: `gopass insert api/<имя>`
3. Запустить `scripts/bootstrap-free-providers.sh` для инъекции ключей
4. Запустить `just` для деплоя

Изменяются только 2 файла (файл данных + gopass секрет) -- код менять не нужно.

## Удаление провайдера

1. Удалить запись из `states/data/free_providers.yaml`
2. Запустить `just` для деплоя
3. Опционально: `gopass rm api/<имя>`

## Первоначальная настройка

```bash
# 1. Зарегистрироваться и получить API-ключи
# 2. Сохранить ключи в gopass
gopass insert api/groq
gopass insert api/cerebras
gopass insert api/openrouter

# 3. Внедрить ключи в конфигурацию ProxyPilot
scripts/bootstrap-free-providers.sh

# 4. Деплой через Salt
just

# 5. Перезапустить ProxyPilot
systemctl --user restart proxypilot

# 6. Проверка
curl http://127.0.0.1:8317/v1/chat/completions \
  -H "Authorization: Bearer $(gopass show -o api/proxypilot-local)" \
  -H "Content-Type: application/json" \
  -d '{"model":"fallback-large","messages":[{"role":"user","content":"Привет"}],"max_tokens":10}'
```

## Устранение неполадок

### Провайдер не отвечает

- Проверить наличие ключа: `scripts/bootstrap-free-providers.sh --check`
- Проверить логи ProxyPilot: `journalctl --user -u proxypilot -f`
- Повторно внедрить ключи: `scripts/bootstrap-free-providers.sh`

### Ключи пропадают после `just`

gopass требует GPG-агент пользователя (Yubikey), который недоступен в контексте Salt (root/sudo). AWK-фолбэк считывает ключи из уже развёрнутого конфига. Если ключи пропали:

1. Запустить `scripts/bootstrap-free-providers.sh` для повторной инъекции из gopass
2. Последующие запуски `just` будут поддерживать ключи через AWK

### Провайдер убрал модель

Обновить имя модели в `states/data/free_providers.yaml` и запустить `just`.

## Мониторинг

Grafana дашборд `http://127.0.0.1:3000` → ProxyPilot → строка «Fallback Providers»:

- **Fallback Activation** -- количество запросов к бесплатным провайдерам
- **Provider Error Rates** -- ошибки 4xx/5xx по провайдерам во времени
- **Ollama Fallback** -- количество запросов к локальному Ollama

## Файлы конфигурации

| Файл | Назначение |
|------|------------|
| `states/data/free_providers.yaml` | Определения провайдеров (data-driven) |
| `states/configs/proxypilot.yaml.j2` | Шаблон конфигурации ProxyPilot |
| `states/opencode.sls` | Salt-состояние (импорт данных, разрешение ключей) |
| `scripts/bootstrap-free-providers.sh` | Скрипт первоначальной инъекции ключей |
| `states/configs/grafana-dashboard-proxypilot.json` | Grafana дашборд |
