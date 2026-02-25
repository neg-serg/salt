# Prompt: Расширение lint-jinja.py — кросс-файловая валидация

## Задача

Расширить `scripts/lint-jinja.py` тремя новыми проверками:
1. **require-resolve** — все `require:`/`watch:`/`onchanges:` ссылки указывают на существующие state ID
2. **unused-imports** — импортированные макросы реально используются в файле
3. **dangling-includes** — файлы в `include:` списке (system_description.sls) существуют на диске

## Архитектура текущего линтера

Файл: `scripts/lint-jinja.py`. Проверки:
- `check_jinja_syntax()` — рендерит все .jinja/.sls через Jinja2 с mock-контекстом
- `check_duplicate_state_ids()` — рендерит .sls, парсит YAML, ищет дубликаты ID
- `check_state_id_naming()` — regex по сырым .sls файлам, проверяет конвенции
- `check_host_config()` — валидирует ключи в host_config.jinja
- `check_yaml_configs()` — yaml.safe_load на data/*.yaml

Рендеринг использует `jinja2.Environment` с `SaltTagExtension` (обрабатывает `{% import_yaml %}`, `{% do %}`) и stub-контекстом `grains={"host": "lint-check"}`. Не все файлы рендерятся — файлы с Salt-only фичами (pillar и т.д.) молча скипаются.

## Подводные камни (КРИТИЧЕСКИ ВАЖНО)

### 1. Макросы генерируют state ID по паттернам

Макросы из `_macros_*.jinja` создают state ID с предсказуемыми префиксами:

| Макрос | Генерируемые ID |
|---|---|
| `pacman_install(name, ...)` | `install_{name}` |
| `paru_install(name, ...)` | `install_{name}` |
| `pkgbuild_install(name, ...)` | `{name}_pkgbuild`, `build_{name}` |
| `simple_service(name, ...)` | `install_{name}`, `{name}_enabled` |
| `service_with_unit(name, ...)` | `{name}_service`, `{name}_daemon_reload`, `{name}_enabled`/`{name}_disabled`, `{name}_reset_failed`, `{name}_running` |
| `ensure_running(name, ...)` | `{name}_reset_failed`, `{name}_running` |
| `system_daemon_user(name, ...)` | `{name}_user`, `{name}_data_dir` |
| `unit_override(name, ...)` | `{name}`, `{name}_reload` |
| `ensure_dir(name, ...)` | `{name}` |
| `udev_rule(name, ...)` | `{name}`, `{name}_reload` |
| `service_stopped(name, ...)` | `{name}` |
| `curl_bin(name, ...)` | `install_{name}` |
| `curl_extract_tar(name, ...)` | `install_{name}` |
| `curl_extract_zip(name, ...)` | `install_{name}` |
| `github_tar(name, ...)` | `install_{name}` |
| `github_release_system(name, ...)` | `install_{name}` |
| `pip_pkg(name, ...)` | `install_{name}` |
| `cargo_pkg(name, ...)` | `install_{name}` |
| `npm_pkg(name, ...)` | `install_{name}` |
| `firefox_extension(ext, ...)` | `floorp_ext_{slug}` |
| `user_service_file(name, ...)` | `{name}` |
| `user_service_enable(name, ...)` | `{name}` |
| `user_unit_override(name, ...)` | `{name}`, `{name}_daemon_reload` |
| `service_with_healthcheck(name, ...)` | `{name}` |
| `download_font_zip(name, ...)` | `install_{name}` |
| `git_clone_deploy(name, ...)` | `install_{name}`, `install_{name}_deploy` |

Все `name` проходят через `| replace('-', '_')` при генерации ID.

Линтер должен знать эти паттерны, чтобы при встрече `require: cmd: install_unbound` понять, что это валидная ссылка на `pacman_install('unbound', ...)` или `simple_service('unbound', ...)`.

### 2. Условные state ID

Многие стейты обёрнуты в `{% if host.features.dns.unbound %}...{% endif %}`. При lint-check рендеринге с mock-грainами feature-флаги могут быть False, и стейты не сгенерируются. Решения:
- **Подход A**: Рендерить с "all-features-on" mock-контекстом (требует знать структуру features)
- **Подход B**: Парсить require-ссылки из сырого текста (regex), не из рендеренного YAML
- **Подход C**: Рендерить несколько раз с разными конфигами хостов из `host_config.jinja`

Рекомендация: **подход B** для require-resolve (regex по сырым файлам), **подход A** для полноты (как дополнительный режим). Уже существующая функция `check_duplicate_state_ids()` использует рендеринг — её результат (`all_ids`) можно расширить, но не полагаться на него как единственный источник.

### 3. Кросс-файловые зависимости

`dns.sls` может ссылаться на state ID из `system_description.sls` (через `include:`). Пример: `require: cmd: pacman_db_warmup` определён в `desktop.sls`, но используется во всех файлах через макросы.

Решение: собрать **глобальный пул state ID** из всех .sls файлов, а не проверять каждый файл изолированно.

### 4. Sanitization при генерации ID

State ID проходят через `| replace('-', '_')`, а иногда через более сложные цепочки:
```
model | replace('.', '_') | replace(':', '_') | replace('-', '_')
ext_id | replace('{', '') | replace('}', '') | replace('-', '_') | replace('@', '_') | replace('.', '_')
```
Require-ссылки используют уже санитизированную форму. Линтер должен или парсить replace-цепочки, или просто проверять ID как есть (после рендеринга).

### 5. Данные из YAML влияют на state ID

Data-driven циклы (`{% for name, opts in tools.curl_bin.items() %}`) генерируют ID на основе содержимого `data/*.yaml`. Линтер уже загружает эти файлы через `_resolve_import_yaml()` — это нужно сохранить.

### 6. `require` формат — не только `cmd:`

Формат requisite: `- {type}: {state_id}`, где type = `cmd`, `file`, `service`, `user`, `mount`, `pkg`. Линтер должен парсить все типы.

### 7. Макро-вызовы внутри Jinja — не видны в YAML

`{{ pacman_install('foo', 'foo') }}` в сыром файле — это Jinja-выражение, а не YAML. Для unused-imports проверки нужно искать макро-имена в сыром тексте файла (regex), а не в рендеренном YAML.

### 8. False positives

Некоторые require-ссылки валидны, но не проверяемы:
- `require: mount: mount_zero` — из `mounts.sls`, может не рендериться
- `require: cmd: pacman_db_warmup` — из `desktop.sls`, глобальная зависимость
- Ссылки внутри макросов (e.g. `require: cmd: pacman_db_warmup` в `_macros_pkg.jinja`)

Нужен механизм **known-globals** — список state ID, которые считаются всегда доступными.

## Рекомендуемый план реализации

### Фаза 1: unused-imports (простая, regex-based)
- Для каждого .sls: распарсить `{% from '...' import foo, bar %}`
- Для каждого импортированного имени: проверить, встречается ли `foo(` или `foo ` в теле файла
- Исключить `_macros_common.jinja` импорты (они переимпортируются внутри макросов)
- Severity: warning (не error)

### Фаза 2: require-resolve (средняя сложность)
- Собрать глобальный пул state ID из всех рендеренных .sls (расширить `check_duplicate_state_ids`)
- Добавить known-globals: `pacman_db_warmup`, `mount_zero`, `mount_one`
- Для каждого рендеренного .sls: найти все `require:`/`watch:`/`onchanges:` блоки
- Для каждой ссылки `- {type}: {id}`: проверить, что `{id}` есть в глобальном пуле или known-globals
- Severity: error

### Фаза 3: dangling-includes (тривиальная)
- Прочитать `system_description.sls`, найти `include:` список
- Для каждого имени: проверить, что `states/{name}.sls` существует
- Severity: error

## Ключевые файлы

- `scripts/lint-jinja.py` — основной файл для модификации
- `states/_macros_*.jinja` — справка по генерируемым state ID (читать, не менять)
- `states/_imports.jinja` — определяет retry_attempts и т.д.
- `states/host_config.jinja` — feature-флаги для mock-контекста
- `states/data/*.yaml` — данные, влияющие на state ID
- `states/system_description.sls` — include-список

## Критерии приёмки

- `python3 scripts/lint-jinja.py` проходит на текущей кодовой базе с 0 ошибками
- Намеренно сломанный require (e.g. `require: cmd: nonexistent_state`) детектируется
- Неиспользованный import детектируется как warning
- Несуществующий include детектируется как error
- False positive rate = 0 на текущей кодовой базе (если нужен suppress-механизм — inline `# lint: ignore`)
