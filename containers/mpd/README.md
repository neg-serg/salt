# MPD Container

Music Player Daemon в контейнере Podman с интеграцией systemd через Quadlet.

## Быстрый старт

```bash
# Сборка образа
./run.sh build

# Запуск контейнера
./run.sh run

# Проверка статуса
mpc status

# Остановка
./run.sh stop
```

## Systemd интеграция (Quadlet)

```bash
# Копировать quadlet файл
mkdir -p ~/.config/containers/systemd
cp mpd.container ~/.config/containers/systemd/

# Перезагрузить systemd
systemctl --user daemon-reload

# Запустить сервис
systemctl --user start mpd

# Включить автозапуск
systemctl --user enable mpd

# Проверить статус
systemctl --user status mpd
```

## Конфигурация

По умолчанию контейнер использует:

| Параметр | Значение | Описание |
|----------|----------|----------|
| Музыка | `~/music` | Директория с музыкой (read-only) |
| Плейлисты | `~/.config/mpd/playlists` | Пользовательские плейлисты |
| База данных | `~/.local/share/mpd` | Кэш и state |
| Порт | 6600 | MPD протокол |
| FIFO | `/tmp/mpd.fifo` | Для визуализаторов (cava, ncmpcpp) |

## Переменные окружения

Можно переопределить директории через переменные:

```bash
MUSIC_DIR=/path/to/music ./run.sh run
MPD_DATA_DIR=/path/to/data ./run.sh run
```

## Клиенты

После запуска можно использовать любой MPD клиент:

```bash
# CLI
mpc status
mpc play
mpc add /

# TUI
ncmpcpp
rmpc

# GUI
cantata
```

## Аудио

Контейнер использует PipeWire через PulseAudio совместимость.
Сокет PipeWire/Pulse монтируется в контейнер.
