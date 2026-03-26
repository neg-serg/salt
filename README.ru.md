# salt

Salt states + chezmoi dotfiles для конфигурации рабочей станции на CachyOS (Arch-based).

## Структура

| Путь | Назначение |
|---|---|
| `states/` | Salt state файлы (.sls) и Jinja макросы |
| `dotfiles/` | Исходная директория chezmoi |
| `scripts/` | Утилиты (apply, lint, daemon) |
| `build/` | Конфиги сборки пакетов (Iosevka, PKGBUILDs) |
| `docs/` | Руководства и справочники |

## Использование

```bash
# Применить Salt states + chezmoi dotfiles
scripts/salt-apply.sh

# Применить конкретный state
scripts/salt-apply.sh desktop

# Пробный запуск
scripts/salt-apply.sh --test
```

## Документация

- [Добавление хоста](docs/adding-host.ru.md) — подключение новой машины
- [Развёртывание](docs/deploy-cachyos.ru.md) — установка CachyOS с нуля
- [Секреты](docs/secrets-scheme.ru.md) — интеграция gopass/Yubikey
- [Настройка gopass](docs/gopass-setup.ru.md) — пошаговое заведение секретов
- [Recovery gopass age](docs/gopass-age-recovery.ru.md) — перенос `age`-backed store на другой компьютер
