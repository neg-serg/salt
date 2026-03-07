# ProxyPilot: руководство по настройке

## Обзор

ProxyPilot -- локальный прокси для AI API, маршрутизирующий запросы от инструментов
разработки (Claude Code, OpenCode, Codex) к провайдерам через OAuth-токены.
Работает как systemd user-сервис на `127.0.0.1:8317`.

## Архитектура

```
claude (прямой)                  claude-proxy (обёртка)
    │                                │
    │ ANTHROPIC_BASE_URL не задан    │ ANTHROPIC_BASE_URL=127.0.0.1:8317
    │ CLAUDE_CONFIG_DIR не задан     │ CLAUDE_CONFIG_DIR=~/.claude-proxy
    ▼                                ▼
┌───────────┐                 ┌─────────────────────┐
│ Anthropic │                 │  ProxyPilot         │  ← systemd user-сервис
│ API       │                 │  127.0.0.1:8317     │
└───────────┘                 └──────────┬──────────┘
                                         │
                              ┌──────────┴──────────┐
                              ▼                     ▼
                        ┌──────────┐         ┌───────────┐
                        │ Claude   │         │ Gemini /  │
                        │ OAuth    │         │ Antigrav. │
                        └──────────┘         └───────────┘
                        ~/.cli-proxy-api/    ~/.cli-proxy-api/
```

## Компоненты

| Компонент | Путь / описание |
|-----------|-----------------|
| Бинарник | `~/.local/bin/proxypilot` (релиз с GitHub) |
| Версия | Закреплена в `states/data/versions.yaml` |
| Конфиг (chezmoi) | `dotfiles/dot_config/proxypilot/config.yaml.tmpl` |
| Конфиг (Salt) | `states/configs/proxypilot.yaml.j2` |
| Задеплоенный конфиг | `~/.config/proxypilot/config.yaml` |
| Unit-файл сервиса | `states/units/user/proxypilot.service` |
| OAuth-токены | `~/.cli-proxy-api/` (создаётся ProxyPilot автоматически) |
| Обёртка | `~/.local/bin/claude-proxy` (zsh-скрипт) |
| Конфиг-директория прокси | `~/.claude-proxy/` (изолирована от `~/.claude/`) |
| Порт | `127.0.0.1:8317` |
| Grafana-дашборд | `states/configs/grafana-dashboard-proxypilot.json` |

## Изоляция окружения

Прямой CLI `claude` и обёртка `claude-proxy` полностью изолированы:

| | `claude` (прямой) | `claude-proxy` (через ProxyPilot) |
|---|---|---|
| Директория конфига | `~/.claude/` | `~/.claude-proxy/` |
| Credentials | `~/.claude/.credentials.json` | OAuth-токены ProxyPilot |
| История | `~/.claude/history.jsonl` | `~/.claude-proxy/history.jsonl` |
| Настройки | `~/.claude/settings.json` | `~/.claude-proxy/settings.json` |
| `ANTHROPIC_BASE_URL` | не задан (api.anthropic.com) | `http://127.0.0.1:8317` |
| `ANTHROPIC_API_KEY` | не задан (из credentials) | API-ключ ProxyPilot |
| `CLAUDE_CONFIG_DIR` | не задан (`~/.claude/`) | `~/.claude-proxy` |

Обёртка использует `exec env` для установки переменных **только для дочернего процесса**.
Глобальных экспортов нет ни в `.zshenv`, ни в `environment.d`, ни в systemd user env.

### Гарантии безопасности

- `ANTHROPIC_BASE_URL` **никогда** не экспортируется глобально
- `ANTHROPIC_API_KEY` **никогда** не экспортируется глобально
- Unit-файл ProxyPilot **не содержит** директив `Environment=`
- `--setup-claude` / `--setup-all` **никогда** не запускаются автоматически
- Даже если запустить `--setup-claude`, он изменит `~/.claude-proxy/settings.json`
  (директорию конфига прокси), а не `~/.claude/settings.json`

## OAuth-провайдеры

ProxyPilot аутентифицируется у провайдеров через OAuth-токены в `~/.cli-proxy-api/`:

| Провайдер | Команда входа | Файл токена | Статус |
|-----------|---------------|-------------|--------|
| Claude | `--claude-login` | `claude-<email>.json` | Работает (v0.3.0-dev-0.40+) |
| Gemini | `--login` | `gemini-<email>-all.json` | Заблокирован ToS (403) |
| Antigravity | `--antigravity-login` | `antigravity-<email>.json` | Заблокирован ToS (403) |

### Claude OAuth

Исправлен в v0.3.0-dev-0.40. Нативный OAuth-поток Anthropic (не Google Cloud).

```bash
proxypilot -config ~/.config/proxypilot/config.yaml -claude-login
```

Открывает браузер, завершает OAuth, сохраняет токен. Ручных действий не требуется.

### Блокировка Google Cloud ToS

Аккаунт Google Cloud заблокирован за нарушение ToS API Cloud Code.
Токены Gemini и Antigravity аутентифицируются, но все API-запросы возвращают
`403 PERMISSION_DENIED` с причиной `TOS_VIOLATION`.

Затронуты:
- Маршрутизация всех моделей Gemini через ProxyPilot
- Маршрутизация всех моделей Antigravity через ProxyPilot
- Плагин `opencode-antigravity-auth` для OpenCode

Форма апелляции: https://forms.gle/hGzM9MEUv2azZsrb9

## Структура конфига

Конфиг (`~/.config/proxypilot/config.yaml`) деплоится Salt через `opencode.sls`,
а не chezmoi (chezmoi только создаёт родительскую директорию).

Ключевые секции:

```yaml
# Аутентификация -- клиенты используют этот ключ для обращения к прокси
api-keys:
  - "<из gopass api/proxypilot-local>"

# Алиасы моделей -- маппинг клиентских имён на провайдеров
# alias = что шлёт клиент, name = ID модели у провайдера
oauth-model-alias:
  antigravity:
    - name: "gemini-2.5-pro"        # Модели Gemini
      alias: "gemini-2.5-pro"
    - name: "claude-sonnet-4-6"     # Claude через Antigravity (запасной маршрут)
      alias: "claude-sonnet-4-6"
```

Два шаблона должны быть синхронизированы:
- `dotfiles/dot_config/proxypilot/config.yaml.tmpl` -- шаблон chezmoi (с codex-алиасами)
- `states/configs/proxypilot.yaml.j2` -- шаблон Salt Jinja (без codex-алиасов)

## Секреты

| Секрет | Путь в gopass | Используется |
|--------|---------------|--------------|
| Клиентский API-ключ | `api/proxypilot-local` | Claude Code, OpenCode, OpenClaw |
| Ключ управления | `api/proxypilot-management` | Доступ к веб-дашборду |

Клиентский API-ключ также экспортируется как `PROXYPILOT_API_KEY` и `OPENAI_API_KEY`
в `~/.config/zsh/10-secrets.zsh` (для shell-инструментов и Codex CLI).

## Использование

### Прямой Claude (по умолчанию)

```bash
claude  # идёт на api.anthropic.com, использует ~/.claude/
```

### Claude через прокси

```bash
claude-proxy  # идёт через ProxyPilot, использует ~/.claude-proxy/
```

Требуется установленный `PROXYPILOT_API_KEY` (загружается из `10-secrets.zsh`).

### Управление сервисом

```bash
systemctl --user status proxypilot
systemctl --user restart proxypilot
journalctl --user -u proxypilot -f  # живые логи
```

### Повторная аутентификация

```bash
# Сначала остановить сервис, чтобы избежать конфликтов токенов
systemctl --user stop proxypilot

# Claude (Anthropic OAuth)
proxypilot -config ~/.config/proxypilot/config.yaml -claude-login

# Gemini (Google OAuth) -- сейчас заблокирован ToS
proxypilot -config ~/.config/proxypilot/config.yaml -login

# Antigravity -- сейчас заблокирован ToS
proxypilot -config ~/.config/proxypilot/config.yaml -antigravity-login

systemctl --user start proxypilot
```

### Проверка статуса

```bash
proxypilot -config ~/.config/proxypilot/config.yaml -list-accounts
proxypilot -config ~/.config/proxypilot/config.yaml -list-models
proxypilot -config ~/.config/proxypilot/config.yaml -detect-agents
```

## Обновление

1. Проверить новые релизы: `gh release list --repo Finesssee/ProxyPilot --limit 5`
2. Обновить версию в `states/data/versions.yaml`
3. Скачать новый бинарник, получить хеш: `sha256sum proxypilot-linux-amd64`
4. Обновить хеш в `states/data/installers.yaml`
5. Запустить `just` для проверки рендеринга Salt

## История версий

| Версия | Ключевые изменения |
|--------|--------------------|
| v0.3.0-dev-0.39 | Паника `tui` flag при любых командах `--*-login` |
| v0.3.0-dev-0.40 | Исправлена паника `tui`, Claude OAuth работает, поддержка Gemini 3.1/GPT-5.4 |

## Опасные команды

Эти команды **модифицируют конфиги агентов** и не должны запускаться,
если вы не хотите целенаправленно перенаправить агент через ProxyPilot:

```bash
# НЕ ЗАПУСКАТЬ без явного намерения:
proxypilot --setup-claude    # модифицирует ~/.claude/settings.json
proxypilot --setup-all       # модифицирует конфиги ВСЕХ обнаруженных агентов
```

Эти команды инжектят `ANTHROPIC_BASE_URL` в настройки агента, перенаправляя
весь трафик через ProxyPilot. Используйте обёртку `claude-proxy` вместо этого.
