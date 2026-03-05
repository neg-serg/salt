# TidalCycles: настройка среды для live coding

Среда TidalCycles для live coding музыкальных паттернов из Neovim.
Управляется Salt-состоянием (`tidal.sls`) с feature-флагом — по умолчанию отключено.

## Архитектура

```
Neovim (.tidal файл)
  → tidal.nvim отправляет код → GHCi REPL (haskell-tidal + BootTidal.hs)
    → OSC по UDP :57120 → SuperCollider (scsynth + SuperDirt)
      → PipeWire (JACK-совместимость) → колонки / DAW
```

## Компоненты

| Компонент | Пакет | Версия | Источник |
|---|---|---|---|
| SuperCollider (аудио-движок) | `supercollider` | 3.14.x | pacman |
| SC3 Plugins (доп. UGen-ы) | `sc3-plugins` | 3.13.x | pacman |
| GHC (компилятор/REPL Haskell) | `ghc` | 9.6.x | pacman |
| Библиотека Tidal | `haskell-tidal` | 1.9.5 | pacman |
| Tidal Link (Ableton Link) | `haskell-tidal-link` | 1.0.x | pacman (авто-зависимость) |
| SuperDirt (синтезаторы + сэмплы) | Quark | v1.7.4 | Codeberg |
| Dirt-Samples (~396MB) | Зависимость Quark | — | Codeberg |
| Плагин для Neovim | `grddavies/tidal.nvim` | latest | lazy.nvim |

## Быстрый старт

### 1. Включить feature-флаг

В `states/data/hosts.yaml` установить `tidal: true` для своего хоста:

```yaml
hosts:
  your-host:
    features:
      tidal: true
```

### 2. Применить Salt-состояние

```bash
just
# или напрямую:
salt-call state.apply tidal
```

Первый запуск устанавливает пакеты и скачивает SuperDirt + Dirt-Samples (~400MB).
Занимает 1-2 минуты в зависимости от скорости сети.

### 3. Запустить TidalCycles

```bash
tidal-start
```

Открывает Neovim со scratch-файлом `.tidal` в `~/music/tidal/scratch.tidal`.

### 4. Запустить аудио-стек (внутри Neovim)

```
:TidalLaunch
```

Запускает sclang (SuperCollider) и ghci (Tidal REPL) в терминальных сплитах Neovim.
Дождитесь `*** SuperDirt started ***` в выводе sclang перед выполнением паттернов.

### 5. Написать и выполнить паттерн

```haskell
d1 $ sound "bd sn"
```

Поставьте курсор на строку и нажмите `Shift+Enter` для выполнения.

## Горячие клавиши (tidal.nvim, по умолчанию)

| Клавиша | Режим | Действие |
|---|---|---|
| `Shift+Enter` | Normal/Insert | Выполнить текущую строку |
| `Shift+Enter` | Visual | Выполнить выделение |
| `Alt+Enter` | Normal/Insert/Visual | Выполнить текущий блок |
| `<leader>Enter` | Normal | Выполнить узел treesitter |
| `<leader>d` | Normal | Заглушить текущий канал |
| `<leader>Esc` | Normal | Hush — заглушить все каналы |

## Команды Neovim

| Команда | Действие |
|---|---|
| `:TidalLaunch` | Запустить sclang + ghci (весь стек) |
| `:TidalQuit` | Остановить оба процесса |

## Расположение файлов

| Файл | Назначение |
|---|---|
| `~/.config/SuperCollider/startup.scd` | Авто-запуск SuperDirt при старте sclang (управляется Salt) |
| `/usr/share/haskell-tidal/BootTidal.hs` | Скрипт инициализации Tidal (управляется pacman) |
| `~/.local/share/SuperCollider/downloaded-quarks/` | SuperDirt quark + Dirt-Samples |
| `~/music/tidal/scratch.tidal` | Scratch-файл по умолчанию (создаётся `tidal-start`) |

## Детали Salt-состояния

**Файл состояния:** `states/tidal.sls`
**Feature-флаг:** `host.features.tidal` (boolean)
**По умолчанию:** `false`

Состояния:
1. `install_supercollider` — установка через pacman
2. `install_sc3_plugins` — установка через pacman
3. `install_ghc` — установка через pacman
4. `install_haskell_tidal` — установка через pacman (тянет haskell-tidal-link)
5. `superdirt_quark_install` — headless-скрипт sclang с `QT_QPA_PLATFORM=offscreen`
6. `superdirt_startup_config` — деплой `startup.scd`

Идемпотентность:
- Установка пакетов: `unless: rg -qx 'pkg' {{ pkg_list }}`
- SuperDirt quark: `creates: ~/.local/share/SuperCollider/downloaded-quarks/SuperDirt`

## Решение проблем

### Нет звука после :TidalLaunch

1. Проверьте терминальный сплит sclang — ищите `*** SuperDirt started ***`
2. Если SuperDirt не запустился, проверьте PipeWire: `pw-cli ls Node | grep -i jack`
3. Убедитесь, что `pipewire-jack` установлен (должен быть через `audio.sls`)

### sclang падает при запуске

SuperCollider требует работающий PipeWire/JACK-сервер. Проверьте:

```bash
pw-jack jack_lsp
```

Если нет вывода, перезапустите PipeWire: `systemctl --user restart pipewire wireplumber`

### Ошибка установки Quark при Salt apply

Установка SuperDirt требует сетевого доступа к Codeberg. Если за прокси или файрволом:
- Состояние повторяет попытки 3 раза с интервалом 10 секунд
- Таймаут — 1200 секунд (20 минут)
- Проверьте доступность: `curl -sSI https://codeberg.org`

### Паттерн выполняется, но нет звука

Проверьте порт OSC — Tidal отправляет на UDP 57120, SuperDirt слушает там:

```bash
ss -ulnp | grep 57120
```

Если на 57120 никто не слушает, SuperDirt не запустился. Перезапустите sclang: `:TidalQuit`, затем `:TidalLaunch`.
