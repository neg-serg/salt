# Добавление нового хоста

## Быстрый старт

1. Выбрать hostname (по соглашению используем [названия городов Morrowind](https://en.uesp.net/wiki/Morrowind:Places))
2. Добавить запись в словарь `hosts` в `states/host_config.jinja`
3. Переопределять только то, что отличается от `defaults` — всё остальное наследуется через рекурсивное слияние

## Минимальный пример

Новая десктопная рабочая станция со всеми значениями по умолчанию:

```jinja
'suran': {
    'display':        '2560x1440@144',
    'primary_output': 'DP-1',
    'hostname':       'suran',
},
```

Наследуется: AMD CPU, не ноутбук, все функции по умолчанию (steam, mpd, ollama и т.д.), стандартные пути монтирования, часовой пояс, локаль.

## Пример для ноутбука

```jinja
'balmora': {
    'is_laptop':      True,
    'cpu_vendor':     'intel',
    'kvm_module':     'kvm_intel',
    'display':        '2560x1600@165',
    'primary_output': 'eDP-1',
    'hostname':       'balmora',
    'features': {
        'network': {
            'wifi': True,
        },
        'steam':    False,
        'ollama':   False,
    },
},
```

Ключевые отличия: Intel CPU меняет `kvm_module`, включен WiFi, тяжёлые функции отключены для экономии батареи.

## Пример для сервера

```jinja
'caldera': {
    'display':        '1920x1080@60',
    'primary_output': 'HDMI-A-1',
    'hostname':       'caldera',
    'features': {
        'monitoring': {
            'loki':     True,
            'promtail': True,
            'grafana':  True,
        },
        'dns': {
            'unbound':      True,
            'adguardhome':  True,
        },
        'services': {
            'samba':    True,
            'jellyfin': True,
            'duckdns':  True,
        },
        'steam':    False,
        'mpd':      False,
        'kanata':   False,
    },
},
```

Включен полный стек мониторинга, DNS и медиа-сервисы. Десктопные функции отключены.

## Как работает слияние

```
defaults  ←──  hosts['your_host']  ←──  derived fields
         recurse merge            post-merge update
```

- `salt['slsutil.merge'](defaults, host_config, strategy='recurse')` — глубокое слияние словарей, значения хоста приоритетнее
- Переопределяются только указанные ключи; вложенные словари сливаются рекурсивно (например, `'dns': {'unbound': True}` не затирает `avahi`)
- После слияния вычисляются производные поля: `runtime_dir`, `pkg_list`, `project_dir`

## Алиасы хостов

Если машина стартует с другим hostname (например `cachyos` после свежей установки), добавьте алиас:

```jinja
{% set aliases = {
    'cachyos': 'telfir',
    'archlinux': 'balmora',
} %}
```

Алиас разрешается перед слиянием, поэтому правильная конфигурация хоста применяется даже до того, как Salt установит `hostname`.

## Доступные флаги функций

| Путь | Тип | По умолчанию | Назначение |
|------|------|---------|---------|
| `features.monitoring.sysstat` | bool | True | Отчёты об активности системы |
| `features.monitoring.vnstat` | bool | True | Мониторинг сетевого трафика |
| `features.monitoring.netdata` | bool | True | Дашборд метрик реального времени |
| `features.monitoring.loki` | bool | False | Агрегация логов |
| `features.monitoring.promtail` | bool | False | Отправщик логов для Loki |
| `features.monitoring.grafana` | bool | False | Визуализация метрик |
| `features.fancontrol` | bool | False | Управление скоростью вентиляторов |
| `features.kernel.variant` | str | 'lto' | Вариант ядра |
| `features.dns.unbound` | bool | False | Локальный DNS-резолвер |
| `features.dns.adguardhome` | bool | False | DNS-блокировка рекламы |
| `features.dns.avahi` | bool | True | mDNS/DNS-SD |
| `features.services.samba` | bool | False | SMB-шаринг файлов |
| `features.services.jellyfin` | bool | False | Медиа-сервер |
| `features.services.bitcoind` | bool | False | Нода Bitcoin |
| `features.services.duckdns` | bool | False | Динамический DNS |
| `features.services.transmission` | bool | False | Торрент-клиент |
| `features.network.vm_bridge` | bool | False | Libvirt-бридж |
| `features.network.xray` | bool | False | Xray-прокси |
| `features.network.singbox` | bool | False | sing-box прокси |
| `features.network.wifi` | bool | False | Беспроводная сеть |
| `features.user_services.mail` | bool | True | Сервис синхронизации почты |
| `features.user_services.vdirsyncer` | bool | True | Синхронизация CalDAV/CardDAV |
| `features.amnezia` | bool | True | AmneziaVPN |
| `features.steam` | bool | True | Steam + игровой стек |
| `features.mpd` | bool | True | Music Player Daemon |
| `features.ollama` | bool | True | Локальная LLM |
| `features.floorp` | bool | True | Оставить Floorp как управляемый вторичный браузер |
| `features.llama_embed` | bool | True | Сервер эмбеддингов llama.cpp |
| `features.kanata` | bool | True | Переназначение клавиш |

## Доступные поля хоста

| Поле | Тип | По умолчанию | Назначение |
|-------|------|---------|---------|
| `user` | str | 'neg' | Основной пользователь |
| `home` | str | `'/home/' + user` | Домашняя директория |
| `uid` | int | 1000 | ID пользователя |
| `mnt_zero` | str | '/mnt/zero' | Первая точка монтирования |
| `mnt_one` | str | '/mnt/one' | Вторая точка монтирования |
| `is_laptop` | bool | False | Режим ноутбука |
| `cursor_theme` | str | 'Alkano-aio' | Тема курсора |
| `cursor_size` | int | 23 | Размер курсора в px |
| `cpu_vendor` | str | 'amd' | Производитель CPU (`amd` или `intel`) |
| `kvm_module` | str | 'kvm_amd' | Модуль ядра KVM |
| `display` | str | '' | Строка разрешения (`WxH@Hz`) |
| `primary_output` | str | '' | Имя видеовыхода |
| `greetd_vt` | int | 1 | Виртуальный терминал для greetd |
| `greetd_scale` | int | 1 | Масштаб экрана входа |
| `timezone` | str | 'Europe/Moscow' | Часовой пояс системы |
| `locale` | str | 'en_US.UTF-8' | Локаль системы |
| `floorp_profile` | str | '' | Имя директории профиля Floorp |
| `zen_profile` | str | '' | Имя директории профиля Zen Browser |
| `hostname` | str | grains host | Желаемый hostname |
| `extra_kargs` | list | [] | Доп. параметры загрузки ядра |
| `extra_modules` | list | [] | Доп. модули ядра для загрузки |

## Рекомендации по профилям браузеров

- Задавайте `zen_profile` для хостов, где `Zen Browser` является основным управляемым браузером.
- Оставляйте `features.floorp: true` и `floorp_profile` только если `Floorp` должен оставаться управляемым вторичным браузером.
- Общие browser launcher'ы должны предпочитать `Zen Browser`, а путь запуска `Floorp` должен быть отдельным и вторичным.

## Чеклист

- [ ] Запись добавлена в словарь `hosts` в `host_config.jinja`
- [ ] Поле `hostname` совпадает с ключом словаря
- [ ] `cpu_vendor` / `kvm_module` соответствуют оборудованию
- [ ] `display` и `primary_output` совпадают с реальным монитором (проверить: `hyprctl monitors`)
- [ ] Флаги функций проверены — отключить ненужное
- [ ] Алиас добавлен, если машина стартует с другим hostname
- [ ] Протестировано с `salt-call --local state.show_top` на целевой машине
