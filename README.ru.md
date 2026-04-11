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
# Применить всё (system_description → все стейты)
just apply

# Применить один стейт
just apply desktop
just apply nanoclaw

# Применить группу стейтов (подмножество связанных)
just group core
just group desktop
just group ai

# Пробный запуск (без изменений)
just test
just test group/network
```

### Группы стейтов

Группы позволяют накатить связанный кусок системы без прогона всех ~200
стейтов.  Удобно для починки одной сломанной области или пошагового
развёртывания с нуля.

| Группа | Что включает | Время |
|--------|-------------|-------|
| `core` | users, zsh, mounts, kernel, hardware, systemd_resources | ~0.6 с |
| `network` | dns, network | ~0.1 с |
| `desktop` | audio, desktop (hyprland, portals, packages), fonts | ~0.7 с |
| `packages` | pacman packages, все installers, custom PKGBUILDs | ~0.6 с |
| `services` | system services, monitoring, user systemd units | ~0.5 с |
| `ai` | ollama, llama_embed, nanoclaw, opencode, image_gen (по feature flags) | ~0.4 с |

Группы лежат в `states/group/*.sls` — это обычные `include:` списки без
новой логики. Отдельные стейты тоже работают: `just apply mpd`, `just apply steam` и т.д.

## Документация

- [Добавление хоста](docs/adding-host.ru.md) — подключение новой машины
- [Развёртывание](docs/deploy-cachyos.ru.md) — установка CachyOS с нуля
- [Секреты](docs/secrets-scheme.ru.md) — интеграция gopass/Yubikey
- [Настройка gopass](docs/gopass-setup.ru.md) — пошаговое заведение секретов
- [Recovery gopass age](docs/gopass-age-recovery.ru.md) — перенос `age`-backed store на другой компьютер
