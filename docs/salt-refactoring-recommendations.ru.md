# Рекомендации по рефакторингу Salt

**Дата**: 2026-03-18  
**Область**: repository-specific предложения по рефакторингу Salt, которые улучшают сопровождаемость и при этом не ухудшают no-op `just apply`.

## Цель

Это не общий style guide по Salt. Это прицельный аудит текущего дерева Salt-состояний, макросов, data-файлов и вспомогательных скриптов именно в этом репозитории.

Критерий включения жёсткий:

- предложение должно улучшать сопровождаемость именно этого репозитория
- оно должно сохранять или улучшать производительность no-op apply
- оно не должно конфликтовать с локальной конституцией (`.specify/memory/constitution.md`)
- оно не должно заменять явный читаемый Salt на метапрограммирование ради косметики

## База доказательств

Рекомендации ниже основаны на:

- `CLAUDE.md`
- `.specify/memory/constitution.md`
- `docs/salt-best-practices.md`
- `states/system_description.sls`
- `states/_imports.jinja`
- `states/_macros_*.jinja`
- domain states в `states/*.sls`
- declarative data в `states/data/*.yaml`
- validation/profiling tooling, включая `scripts/render-matrix.py` и `scripts/state-profiler.py`

## Формат рекомендации

Каждый пункт использует одну и ту же структуру:

- `Problem`: что сейчас сложно сопровождать
- `Recommendation`: что менять
- `Why here`: почему это уместно именно в этом репозитории
- `Performance impact`: `positive`, `neutral`, `uncertain` или `negative`
- `Validation`: что прогонять после внедрения

## Guardrails по производительности

Классифицируй изменение как `safe now` только если ожидается нейтральное или положительное влияние на render/compile/no-op apply.

Перемещай изменение в `requires validation`, если оно:

- меняет include-структуру
- меняет количество состояний, которые рендерятся для хоста
- заменяет явные блоки состояния на циклы/макросы, которые сложнее читать
- меняет поведение `cmd.run` / `cmd.script` или их guards

Помечай изменение как `avoid for now`, если оно с высокой вероятностью:

- расширит include-граф
- добавит Jinja-индирекцию ради чисто косметической выгоды
- заменит читаемую Salt-логику на generic YAML schema или meta-template
- усложнит отладку без снижения реального дублирования

## Safe Now

### REC-001: заменить захардкоженные `/run/user/1000` на `host.runtime_dir`

**Scope**: `states/desktop.sls`, `states/openclaw_agent.sls`, `states/units/user/salt-monitor.service`

**Problem**: Несколько user-service и Hyprland-related путей всё ещё захардкожены в `/run/user/1000`, хотя остальной репозиторий уже использует `host.runtime_dir`.

**Recommendation**: Везде заменить жёстко заданный runtime path на `host.runtime_dir`.

**Why here**: В репозитории уже есть одна каноническая модель runtime path на хост. Её и надо использовать как единственный источник правды.

**Performance impact**: `neutral`

**Validation**:

- `just validate`
- проверить отрендеренные значения окружения для затронутых user services

---

### REC-002: ввести маленький `ensure_linger`-макрос для повторяющегося lingering

**Scope**: `states/openclaw_agent.sls`, `states/telethon_bridge.sls`, `states/nanoclaw.sls`, `states/_macros_service.jinja`

**Problem**: Один и тот же блок `loginctl enable-linger {{ user }}` + guard на `Linger=yes` повторяется три раза.

**Recommendation**: Добавить узкий helper `ensure_linger(name, user)` в `states/_macros_service.jinja` и использовать его в трёх текущих местах.

**Why here**: Это реальный повторяющийся operational pattern с одинаковой семантикой, а не одноразовая абстракция.

**Performance impact**: `neutral`

**Validation**:

- `just validate`
- убедиться, что state IDs остаются читаемыми и уникальными

---

### REC-003: централизовать fallback-логику получения ProxyPilot credentials

**Scope**: `states/openclaw_agent.sls`, `states/telethon_bridge.sls`, `states/nanoclaw.sls`, `states/opencode.sls`

**Problem**: Один и тот же паттерн получения ProxyPilot API key появляется в нескольких состояниях, но с небольшими отличиями в gopass/fallback логике.

**Recommendation**: Сделать один общий helper для схемы "взять ProxyPilot key из gopass, иначе распарсить локальный config" и переиспользовать его в состояниях AI-агентов.

**Why here**: Эти состояния уже operationally связаны между собой и используют одни и те же предположения.

**Performance impact**: `neutral`

**Validation**:

- `just validate`
- проверить, что fallback command text после рефакторинга не поменял поведение

---

### REC-004: вынести общие Telegram allowlist constants в declarative data

**Scope**: `states/openclaw_agent.sls`, `states/telethon_bridge.sls`, новый entry в `states/data/*.yaml`

**Problem**: Одни и те же Telegram UID constants повторяются inline в нескольких состояниях.

**Recommendation**: Вынести эти константы в dedicated data file или в уже существующий подходящий YAML и подключать через `import_yaml`.

**Why here**: Это конфигурационные данные, а не логика. Репозиторий уже использует YAML для пакетов, сервисов, feature matrix и model allowlists.

**Performance impact**: `neutral`

**Validation**:

- `just validate`
- убедиться, что обе итоговые конфигурации содержат те же allowlist values

---

### REC-005: сделать `user_services.sls` более data-driven для feature-tagged unit groups

**Scope**: `states/user_services.sls`, `states/data/user_services.yaml`

**Problem**: `user_services.sls` содержит несколько параллельных hardcoded lists вроде `mail_unit_ids`, `mail_enable`, `mail_timers`, `vdirsyncer_*`, хотя сами unit files уже описаны в YAML.

**Recommendation**: Расширить `states/data/user_services.yaml` optional feature tags, например `mail` или `vdirsyncer`, и фильтровать по ним из data-файла вместо поддержки отдельных Jinja-списков.

**Why here**: Это уменьшит drift между списками, не вытаскивая при этом core logic из SLS.

**Performance impact**: `neutral`

**Validation**:

- `just validate`
- `just render-matrix`
- сравнить отрендеренные enable/disable lists до и после

---

### REC-006: держать rationale и recommendation IDs в этом отчёте, а не размазывать их по коду

**Scope**: будущие follow-up refactor changes в `states/*.sls`

**Problem**: Обсуждения про рефакторинг часто утекaют в код в виде временных комментариев и labels, которые потом остаются навсегда.

**Recommendation**: Держать rationale в этом отчёте и в будущих feature specs/tasks. В код добавлять комментарии только там, где они объясняют неочевидное runtime behavior.

**Why here**: Конституция прямо не любит лишний comment churn, а в текущем репозитории комментарии в целом уже экономные и полезные.

**Performance impact**: `neutral`

**Validation**:

- при будущих follow-up diff review проверять отсутствие лишнего роста комментариев

## Requires Validation

### REC-007: вынести повторяющийся hyprpm command pattern в узкий helper

**Scope**: `states/desktop.sls`, возможно `states/_macros_service.jinja`

**Problem**: Поток работы с Hyprland plugins повторяет одну и ту же среду, runtime-dir guard, retry block и signature handling в нескольких `cmd.run`.

**Recommendation**: Рассмотреть узкий helper для операций `hyprpm add/enable`, но только если он сохраняет читаемость текущих `unless` и `require`.

**Why here**: Повторение реально есть, но эта зона operationally хрупкая и уже неплохо задокументирована.

**Performance impact**: `uncertain`

**Validation**:

- `just validate`
- dry-run затронутого состояния
- проверить, что semantics guards не изменились

---

### REC-008: уплотнить flow clone/install/build/version в `nanoclaw.sls`

**Scope**: `states/nanoclaw.sls`

**Problem**: Сейчас NanoClaw использует четыре отдельных command-state для clone, install, build и version pinning.

**Recommendation**: Рассмотреть более компактный versioned install pattern, но только если state останется отлаживаемым и не потеряет явность guards.

**Why here**: Этот state заметно более procedural, чем остальная часть репозитория, и выбивается из macro-first style.

**Performance impact**: `uncertain`

**Validation**:

- `just validate`
- dry-run на feature-enabled host
- сравнить no-op behavior до и после

---

### REC-009: сделать helper для паттерна "config file + reload/restart companion"

**Scope**: `states/network.sls`, `states/monitoring_loki.sls`, возможно `states/_macros_service.jinja`

**Problem**: Некоторые паттерны состоят из `file.managed` рядом с reload/restart action, но каждое место выражает это чуть по-разному.

**Recommendation**: Рассматривать tiny helper только для случаев с действительно одинаковым reload behavior. Не пытаться засунуть разные случаи в один macro.

**Why here**: В репозитории уже есть `ensure_running`, `unit_override`, `user_service_file`; узкое дополнение может быть полезным.

**Performance impact**: `uncertain`

**Validation**:

- `just validate`
- сравнить requisites и `onchanges` wiring для каждого мигрированного места

## Avoid For Now

### REC-010: не заменять явный feature-gated include list на meta-generated loop

**Scope**: `states/system_description.sls`

**Problem**: Include list выглядит повторяющимся, поэтому хочется генерировать его из data table.

**Recommendation**: Не переводить include graph в Jinja-loop поверх YAML metadata.

**Why here**: Текущий файл — один из самых быстрых способов визуально аудировать highstate topology. Loop сэкономит строки, но сделает compile path менее явным и менее удобным для отладки.

**Performance impact**: `negative`

**Validation**: Не рекомендуется к внедрению.

---

### REC-011: не пытаться засунуть все custom service blocks в generic YAML schemas

**Scope**: `states/services.sls`, `states/network.sls`, `states/desktop.sls`, `states/data/*.yaml`

**Problem**: После data-driven `simple_service` возникает соблазн кодировать в YAML вообще все custom services.

**Recommendation**: Остановиться на действительно uniform patterns вроде `simple_service`. Samba, Transmission, Hyprpm и похожие блоки оставлять inline, если у них есть bespoke dependency или operational logic.

**Why here**: Конституция предпочитает minimal change и запрещает абстракцию для one-off операций.

**Performance impact**: `negative`

**Validation**: Не рекомендуется к внедрению.

---

### REC-012: не macro-изировать каждый `file.absent` legacy cleanup block

**Scope**: `states/dns.sls`, `states/network.sls`, `states/services.sls`, `states/monitoring_loki.sls`, `states/kanata.sls`, `states/installers.sls`

**Problem**: Несколько one-shot cleanup blocks выглядят как лёгкая добыча для макроса.

**Recommendation**: Не вводить generic cleanup macro, пока не появится существенно больший и действительно одинаковый повторяющийся паттерн.

**Why here**: Сейчас эти cleanup blocks явные, дешёвые для чтения и часто семантически привязаны к одному state.

**Performance impact**: `negative`

**Validation**: Не рекомендуется к внедрению.

## Keep As-Is

### KEEP-001: сохранить тонкий `_imports.jinja` proxy

**Scope**: `states/_imports.jinja`

**Current pattern**: `_imports.jinja` только re-export'ит shared values из `_macros_common.jinja` и не несёт business logic.

**Why it is correct**: Это даёт единый import surface и при этом не скрывает происхождение данных.

**Risk of changing it**: Если напихать туда больше логики, proxy превратится в скрытый control layer.

**Performance impact of keeping it**: `positive`

---

### KEEP-002: сохранить явную границу между simple data-driven services и custom inline services

**Scope**: `states/services.sls`, `states/data/services.yaml`

**Current pattern**: Uniform services идут через `simple_service`, а Samba, Transmission, DuckDNS и Bitcoind остаются inline.

**Why it is correct**: Это правильная граница между data-driven и bespoke logic именно для этого репозитория.

**Risk of changing it**: Слишком общая схема сделает complex services сложнее для понимания и проще для поломки.

**Performance impact of keeping it**: `positive`

---

### KEEP-003: сохранить `replace: False` seed-only deployment для self-mutating configs

**Scope**: `states/openclaw_agent.sls`, `states/nanoclaw.sls`

**Current pattern**: Salt seed'ит initial config и дальше не борется с инструментами, которые переписывают своё состояние при старте.

**Why it is correct**: Это уже соответствует конституции и предотвращает шум в no-op apply.

**Risk of changing it**: Если перейти к always-replace semantics, появится churn и риск затереть runtime-managed values.

**Performance impact of keeping it**: `positive`

---

### KEEP-004: сохранить conditional skip для Promtail, когда Loki выключен

**Scope**: `states/monitoring_loki.sls`

**Current pattern**: Promtail gated одновременно по `promtail` и `loki`.

**Why it is correct**: Это убирает класс runtime log spam и делает monitoring graph согласованным.

**Risk of changing it**: Возвращение Promtail без Loki снова приведёт к шумному failure mode.

**Performance impact of keeping it**: `positive`

## Порядок внедрения

Внедрять в таком порядке:

1. `REC-001`
2. `REC-002`
3. `REC-003`
4. `REC-004`
5. `REC-005`
6. потом отдельно решить, стоят ли вообще внедрения `REC-007` - `REC-009`

`REC-010` - `REC-012` не планировать, если только ограничения репозитория не изменятся.

## Checklist валидации для follow-up рефакторингов

Для каждого принятого изменения:

```bash
just validate
just render-matrix
```

Если изменение трогает include structure, render branching или sequencing команд, дополнительно снять timing evidence из свежего apply log:

```bash
just profile
```
