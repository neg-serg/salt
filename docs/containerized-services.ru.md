# Контейнеризованные сервисы (Podman Quadlet)

Все контейнеризируемые сервисы работают исключительно как Podman Quadlet контейнеры.
Нет двойного режима, нет feature toggle'ов, нет нативного fallback'а.

## Контейнеризованные сервисы

| Сервис | Образ | Scope | Примечание |
|--------|-------|-------|------------|
| `ollama` | `docker.io/ollama/ollama:rocm` | system | ROCm GPU passthrough; ручной запуск |
| `llama_embed` | `ghcr.io/ggml-org/llama.cpp:server-vulkan` | system | Vulkan GPU passthrough; ручной запуск |
| `t5_summarization` | `ghcr.io/ggml-org/llama.cpp:server-vulkan` | system | Vulkan GPU passthrough; ручной запуск |
| `loki` | `docker.io/grafana/loki:3.x` | system | Агрегация логов |
| `promtail` | `docker.io/grafana/promtail:3.x` | system | Отправка логов в Loki |
| `grafana` | `docker.io/grafana/grafana-oss:11.x-oss` | system | Дашборды |
| `telethon_bridge` | `localhost/telethon-bridge` | user | Собирается локально; Telegram MTProto мост |
| `opencode_serve` | `localhost/opencode-serve` | user | Собирается локально; OpenCode HTTP API |
| `opencode_telegram_bot` | `localhost/opencode-telegram-bot` | user | Собирается локально; Telegram бот |
| `telecode` | `localhost/telecode` | user | Собирается локально; Go бинарник |

Сервисы, которые **остаются нативными**:

- Аудио-стек (PipeWire, WirePlumber) — D-Bus сессии и ALSA/JACK
- VPN и туннели (Tailscale, AmneziaVPN, Zapret2, Hiddify) — kernel capabilities, TUN, raw sockets
- DNS (Unbound, AdGuardHome) — привязка к хостовому resolver
- MPD — MPRIS2 D-Bus интеграция
- NanoClaw — сам запускает rootless Podman
- Bitcoin Core, Jellyfin, Transmission — сложность перевешивает пользу

## Структура данных

- `states/data/service_catalog.yaml` — port, health endpoint, scope, пакеты, bind mounts, GPU.
- `states/data/container_images.yaml` — реестр digest'ов. Удалённые образы (docker.io, ghcr.io) ОБЯЗАНЫ иметь non-null `digest`. Localhost-образы (собираемые вручную) имеют `digest: null`.
- `states/_macros_service.jinja` — макрос `container_service()`. Пропускает `podman pull` для образов с `localhost` registry.

## Сборка localhost образов

Bridge-сервисы используют `localhost` registry — образы нужно собрать вручную:

```bash
cd path/to/service/Dockerfile
podman build -t localhost/<имя-сервиса> .
```

После сборки запустить `salt-call state.apply` для деплоя Quadlet unit.

## Workflow обновления digest'а

Обновление — single two-line commit в `states/data/container_images.yaml`:

1. `podman pull <registry>/<image>:<variant>`.
2. `podman image inspect --format '{{.Id}}'` для sha256.
3. Обновить `digest` и `approved_at`.
4. Commit: `[<сервис>] bump container digest to <первые 12 символов>`.
5. `sudo salt-call --local state.apply <сервис>`.

Откат: `git revert` bump-коммита, apply.

## Операционный FAQ

**Где Quadlet unit файл?**

- System: `/etc/containers/systemd/<name>.container`
- User: `~/.config/containers/systemd/<name>.container`

**Как проверить health?**

```bash
systemctl status <unit>.service
sudo podman ps
curl http://127.0.0.1:<port><health_path>
```

**Куда идут логи?**

В systemd journal. `journalctl -u <unit>.service` работает как обычно.

**Почему `systemctl status ollama` показывает "inactive (dead)"?**

Ollama, llama_embed и t5_summarization имеют `manual_start: true` — GPU разделяется с десктопом. Quadlet unit установлен, но нужен явный `sudo systemctl start <service>`.

## Ссылки

- `states/_macros_service.jinja` — макрос `container_service`
- `states/data/service_catalog.yaml` — определения сервисов
- `states/data/container_images.yaml` — реестр digest'ов
