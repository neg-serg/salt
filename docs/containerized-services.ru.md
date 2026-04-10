# Контейнеризованные сервисы (Podman Quadlet)

Документ описывает операционную модель сервисов, мигрированных с нативного
развёртывания (pacman/AUR) на digest-закреплённые Podman Quadlet контейнеры
в рамках фичи 087-containerize-services.

## Зачем контейнеризовать

Пять сервисов inference- и observability-слоёв получают от контейнеризации
реальную ценность: **изоляцию runtime-а** от обновлений системных пакетов,
**явные и обратимые обновления** через bump digest'а, и **воспроизводимое
развёртывание** на чистом хосте. Bridge-сервисы (Telegram / OpenCode)
структурно поддержаны, но их digest'ы отложены до появления first-party
upstream-образов.

Сервисы, которые **остаются нативными** и не должны контейнеризоваться:

- Аудио-стек (Pipewire, WirePlumber) — завязан на D-Bus сессии и прямой
  доступ к ALSA/JACK
- VPN и туннелирование (Tailscale, AmneziaVPN, Zapret2, Hiddify) — kernel
  capabilities, TUN-устройства, raw sockets, iptables/ipset
- DNS (Unbound, AdGuardHome) — тесно связан с хостовым resolver'ом
- MPD — интеграция с MPRIS2 через D-Bus
- NanoClaw — сам по себе запускает rootless Podman как основную функцию
- Bitcoin Core, Jellyfin, Transmission — операционная сложность
  перевешивает пользу от контейнеризации

См. `specs/087-containerize-services/spec.md` §Out of scope для полного
списка и обоснования исключений.

## Статус по сервисам

| Сервис | Уровень | Режим cutover'а | Quadlet unit | Feature toggle |
|--------|---------|------------------|--------------|----------------|
| `ollama` | US1 inference | in-place | `ollama.service` | `features.containers.ollama` |
| `llama_embed` | US1 inference | in-place | `llama_embed.service` | `features.containers.llama_embed` |
| `loki` | US2 observability | blue/green | `loki-container.service` | `features.containers.loki` |
| `promtail` | US2 observability | hard cutover | `promtail-container.service` | `features.containers.promtail` |
| `grafana` | US2 observability | hard cutover | `grafana-container.service` | `features.containers.grafana` |
| `telethon_bridge` | US3 bridge | in-place (deferred) | `telethon-bridge.service` | `features.containers.telethon_bridge` |
| `opencode_serve` | US3 bridge | in-place (deferred) | `opencode-serve.service` | `features.containers.opencode_serve` |
| `opencode_telegram_bot` | US3 bridge | in-place (deferred) | `opencode-telegram-bot.service` | `features.containers.opencode_telegram_bot` |
| `telecode` | US3 bridge | in-place (deferred) | `telecode.service` | `features.containers.telecode` |

"Deferred" означает: feature toggle подключён, Quadlet unit шаблон существует,
ветка в state-файле готова — но digest в `states/data/container_images.yaml`
null, поэтому поднятие toggle в true эмитит только видимое `_container_deferred`
no-op состояние, а сервис продолжает работать в нативной форме.

## Структура данных

- `states/data/service_catalog.yaml` — single source of truth для каждого
  сервиса: port, health endpoint, scope, package set и (для
  контейнеризуемых) bind mounts, GPU requirement, cutover mode, cutover
  date, ключ `container_image`.
- `states/data/container_images.yaml` — реестр digest'ов. Каждый top-level
  ключ — ссылка `container_image` из каталога, с полями `registry`,
  `image`, `variant`, `digest`, `approved_at`, `note`. Tag-ссылки
  запрещены (FR-014). Non-null digest ДОЛЖЕН соответствовать
  `sha256:<64 hex chars>`.
- `states/data/hosts.yaml` — toggle'ы `defaults.features.containers.*`.
  Каждый булев — rollback-рычаг сервиса: `false` = нативный, `true` =
  контейнеризованный. Переключение в `true` ДОЛЖНО быть в одном коммите
  с установкой `service_catalog.yaml[<сервис>].cutover_date` на
  сегодняшнюю дату.

## Процедура cutover'а

Полный end-to-end smoke-тест с таймингом, верификацией и rollback-учением
см. в `specs/087-containerize-services/quickstart.md`. Краткая форма:

1. **Проверить prerequisites**: Podman ≥5.0, наличие GPU-устройств (только
   inference), наполненность model cache.
2. **Захватить нативный baseline**: 5-run trimmed-median протокол cold-start'а
   из `quickstart.md` §Step 1. Записать в
   `specs/087-containerize-services/research.md` §Decision 6 таблицу.
3. **Поднять toggle**: установить `features.containers.<сервис>: true` в
   `states/data/hosts.yaml` и `cutover_date: <сегодня>` в
   `states/data/service_catalog.yaml` в entry сервиса.
4. **Резолвить digest**: запустить `podman pull <registry>/<image>:<variant>`,
   затем `podman image inspect --format '{{.Id}}'` чтобы получить sha256.
   Записать в `container_images.yaml[<сервис>].digest` и установить
   `approved_at` на сегодня. Коммит — отдельный single-purpose.
5. **Apply**: `sudo salt-call --local state.apply <сервис>`.
6. **Проверить**: Quadlet файл существует, сгенерированный systemd unit
   active, health endpoint возвращает 200, downstream-клиенты работают
   без изменений конфигурации.
7. **Измерить**: запустить тот же cold-start протокол против
   контейнеризованной формы. Должно быть в пределах 150% от baseline
   (SC-007).

## Rollback (по режиму cutover'а)

### In-place rollback (Ollama, llama_embed, bridges)

1. Переключить `features.containers.<сервис>: false` в `hosts.yaml`.
2. `sudo salt-call --local state.apply <сервис>`.
3. Проверить: Quadlet файл в `/etc/containers/systemd/<name>.container`
   (или `~/.config/containers/systemd/` для user-scope) удалён, нативный
   сервис работает на том же порту, состояние (model cache, credentials)
   сохранено через bind-mount.

Цель: меньше 5 минут wall-clock (SC-003).

### Blue/green rollback (Loki)

Нативный Loki продолжает работать на порту 3101 во время rollback-окна
именно для того, чтобы этот случай был тривиальным:

1. Переключить `features.containers.loki: false` в `hosts.yaml`.
2. `sudo salt-call --local state.apply monitoring_loki`.
3. Salt возвращает нативный Loki с порта 3101 обратно на 3100 (обновляя
   `loki_config` и перезапуская native service) и удаляет контейнеризованный
   `loki-container.service` через `file.absent` на Quadlet unit файле.
4. Временный Grafana datasource `loki-native-archive.yaml` удаляется
   в том же apply.
5. Проверить: `curl http://127.0.0.1:3100/ready` возвращает 200, в Grafana
   Explore виден только primary Loki datasource (без archive), на диске
   нет stale Quadlet файла.

### Promtail и Grafana (hard cutover)

Promtail и Grafana используют hard cutover (одна форма активна в момент
времени), так что их rollback — такой же single-command flip как in-place.

## Окно отката (7 дней)

У каждого контейнеризованного сервиса в каталоге есть поле `cutover_date`.
Через 7 дней после этой даты состояние `<сервис>_native_teardown`
(`pkg.removed`) становится eligible для срабатывания. Это scheduled
reminder, не автоматическое действие: оператор должен запустить
`state.apply` после закрытия окна чтобы фактически удалить нативный пакет.

Teardown для Loki сложнее чем просто `pkg.removed`: он должен атомарно
удалить port-3101 config override И временный archive Grafana datasource.
См. `tasks.md` T054 для полного чеклиста.

## Workflow обновления digest'а

Обновление контейнеризованного сервиса до более свежего upstream-образа —
single two-line commit в `states/data/container_images.yaml`:

1. `podman pull <registry>/<image>:<variant>` (pull нового тега).
2. `podman image inspect --format '{{.Id}}'` чтобы получить sha256.
3. Обновить `digest` и `approved_at` в entry сервиса.
4. Commit с сообщением `[<сервис>] bump container digest to <первые 12
   символов>`.
5. `sudo salt-call --local state.apply <сервис>` — guard `podman image
   exists` пропускает pull если digest уже локальный, затем перезапускает
   сервис через `watch:` chain.

Откат к предыдущему digest'у — симметричная операция: `git revert`
bump-коммит, apply.

## Операционный FAQ

**Где на диске Quadlet unit файл?**

- System-scope: `/etc/containers/systemd/<name>.container`
- User-scope: `~/.config/containers/systemd/<name>.container`

Quadlet генерирует соответствующий systemd unit в
`/run/systemd/system/<name>.service` (system) или
`~/.config/systemd/user/<name>.service` (user, в момент daemon-reload).

**Почему Loki использует `loki-container.service`, а Ollama — `ollama.service`?**

Loki нуждается в одновременном существовании нативной и контейнеризованной
форм во время rollback-окна (нативная на 3101 для исторических запросов,
контейнер на 3100 для новых записей). Разные systemd unit имена избегают
теневого перекрытия `/run` vs `/usr/lib`. Hard-cutover сервисы (Ollama,
Promtail, Grafana, bridges) не имеют этого требования и переиспользуют
нативное имя unit'а через дефолтный нейминг Quadlet'а.

**Как проверить health контейнера?**

```bash
systemctl status <unit>.service        # взгляд systemd
sudo podman ps --format '...'          # взгляд Podman
curl http://127.0.0.1:<port><health_path>   # HTTP probe
```

Для контейнеризованных сервисов с `Notify=healthy`, `systemctl status`
репортит active только ПОСЛЕ того как внутренний HealthCmd контейнера
прошёл — так что "active" уже означает healthy.

**Куда идут логи контейнера?**

В systemd journal как обычно. `journalctl -u <unit>.service` работает
и для нативной, и для контейнеризованной формы без изменений.

**Почему `systemctl status ollama` показывает "inactive (dead)" после state.apply?**

У Ollama и llama_embed в каталоге стоит `manual_start: true` — ни одна из
форм не автостартует при загрузке, потому что GPU разделяется с desktop
compositor'ом. Quadlet unit установлен и готов, но нужно явно
`sudo systemctl start ollama` перед использованием. Это штатное состояние,
не баг.

## Режимы отказов

| Симптом | Вероятная причина | Действие |
|---------|-------------------|----------|
| `salt-call` render error про отсутствующий digest | null digest для P1/P2 сервиса | Заполнить digest через bump workflow, повторить |
| Render error про формат digest'а | digest не соответствует `sha256:<64 hex>` | Исправить значение digest'а (нарушение FR-014) |
| Контейнер запущен, но healthcheck падает | GPU passthrough сломан или неверный HealthCmd путь | `podman logs <name>`, проверить device nodes в rendered unit файле |
| `systemctl status` репортит "no such unit" | daemon-reload не триггернулся или неверное имя Quadlet файла | `sudo systemctl daemon-reload`, проверить существование файла в `/etc/containers/systemd/` |
| Cold-start больше 150% от baseline | первый image pull, холодный page cache | Перезамерить после warm-up; разбираться если стабильно больше |

Для всего, чего нет в таблице: захватить
`sudo salt-call --local state.apply <сервис> -l debug 2>&1 | tail -200`
плюс `sudo journalctl -u <unit>.service --since '5 min ago'` и открыть
issue с обоими вложениями.

## Ссылки

- `specs/087-containerize-services/spec.md` — спецификация фичи
- `specs/087-containerize-services/plan.md` — план реализации
- `specs/087-containerize-services/research.md` — Phase 0 решения (Podman
  Quadlet, GPU passthrough, формат реестра digest'ов, отсрочка NanoClaw,
  окно отката, baseline-протокол, P3 upstream-image gate)
- `specs/087-containerize-services/quickstart.md` — операторский smoke-тест
- `specs/087-containerize-services/contracts/` — сигнатура макроса, схема
  каталога, контракт Quadlet unit шаблона
- `states/_macros_service.jinja` — исходник макроса `container_service`
