# Speech Engines

Локальный стек речевых движков: синтез речи (TTS) и распознавание речи (STT) на AMD RX 7900 XTX через ROCm.

## Обзор

| Движок | Тип | Устройство | VRAM | Порт | Языки |
|--------|-----|-----------|------|------|-------|
| **Chatterbox** | TTS (основной) | ROCm GPU | ~8GB | 8000 | EN, RU |
| **Piper** | TTS (запасной) | CPU | 0 | 8001 | EN, RU |
| **whisper.cpp** | STT | HIPBLAS GPU | ~4GB | CLI | EN, RU, авто |
| **Edge TTS** | TTS (OpenClaw) | Облако | 0 | — | Мультиязычный |

Общее потребление VRAM: ~12GB из 24GB (остаётся для LLM или других задач).

## Требования

- AMD GPU с ROCm (проверено на RX 7900 XTX, gfx1100)
- ROCm SDK (`pacman -S rocm-hip-sdk rocm-opencl-sdk`)
- Python 3.12 (PyTorch ROCm не поддерживает 3.13+)
- cmake, git

## Установка

```bash
cd speech-engines/

# 1. Проверить ROCm-окружение
./check-rocm.sh

# 2. Установить движки (по порядку)
./setup-chatterbox.sh    # Основной TTS (GPU, ~8GB VRAM)
./setup-piper.sh         # Запасной TTS (CPU, 0 VRAM)
./setup-whisper-cpp.sh   # Локальный STT (GPU, ~4GB VRAM)

# 3. Установить systemd-сервисы
cp systemd/*.service ~/.config/systemd/user/
systemctl --user daemon-reload
```

Каждый скрипт создаёт отдельный venv, скачивает модели в `voices/`, и проверяет работоспособность.

## Управление сервисами

### Запуск и остановка

```bash
# Всё разом
./start-speech-stack.sh   # Запуск + ожидание готовности + статус
./stop-speech-stack.sh    # Остановка + отчёт об освобождённой VRAM

# По отдельности
systemctl --user start chatterbox-tts
systemctl --user stop chatterbox-tts
systemctl --user start piper-tts
systemctl --user stop piper-tts
```

### Статус и логи

```bash
systemctl --user status chatterbox-tts piper-tts
journalctl --user -u chatterbox-tts -f     # Логи в реальном времени
journalctl --user -u piper-tts -n 50       # Последние 50 строк
```

### VRAM

```bash
rocm-smi --showmeminfo vram    # Общая и занятая VRAM
rocm-smi                       # Температура, нагрузка, память
```

## Использование

### Синтез речи (TTS)

Оба TTS-движка предоставляют OpenAI-совместимый API на `/v1/audio/speech`.

**Chatterbox** (GPU, высокое качество, 3-5 сек):

```bash
curl http://127.0.0.1:8000/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{
    "model": "chatterbox",
    "input": "Привет, это тест синтеза речи.",
    "voice": "Emily.wav"
  }' -o output.wav

mpv output.wav
```

Доступные голоса Chatterbox (28 штук): `Emily.wav`, `Alice.wav`, `Brian.wav` и др. Полный список:

```bash
curl -s http://127.0.0.1:8000/ | python3 -c "
import sys, json
# Список доступен через UI API
" 2>/dev/null
# Или посмотреть файлы:
ls speech-engines/chatterbox-server/voices/
```

**Piper** (CPU, быстрый, <1 сек):

```bash
# Английский голос
curl http://127.0.0.1:8001/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{
    "model": "piper",
    "input": "This is Piper, the CPU fallback engine.",
    "voice": "en_US-lessac-medium"
  }' -o output.wav

# Русский голос
curl http://127.0.0.1:8001/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{
    "model": "piper",
    "input": "Это Пайпер, запасной движок на процессоре.",
    "voice": "ru_RU-irina-medium"
  }' -o output_ru.wav
```

Список доступных голосов Piper:

```bash
curl -s http://127.0.0.1:8001/v1/models | python3 -m json.tool
```

### Распознавание речи (STT)

whisper-cli — командная утилита, не сервер. Принимает WAV/MP3, выводит текст:

```bash
# Автоопределение языка
whisper-cli \
  -m ~/src/1st-level/@rag/speech-engines/voices/ggml-large-v3-turbo.bin \
  -f audio.wav \
  -l auto \
  --no-prints

# Принудительно русский
whisper-cli \
  -m ~/src/1st-level/@rag/speech-engines/voices/ggml-large-v3-turbo.bin \
  -f audio.wav \
  -l ru \
  --no-prints
```

Формат вывода — таймкоды + текст:

```
[00:00:00.000 --> 00:00:02.800]   Hello, testing chatterbox speech synthesis.
```

### Полный цикл: текст → речь → текст

```bash
# 1. Синтезировать речь
curl -s http://127.0.0.1:8001/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"model":"piper","input":"Тестируем полный цикл речи.","voice":"ru_RU-irina-medium"}' \
  -o /tmp/roundtrip.wav

# 2. Распознать обратно
whisper-cli \
  -m ~/src/1st-level/@rag/speech-engines/voices/ggml-large-v3-turbo.bin \
  -f /tmp/roundtrip.wav -l auto --no-prints
# → [00:00:00.000 --> 00:00:01.960]   Тестируем полный цикл речи.
```

## Интеграция с OpenClaw

### Что подключено

- **STT**: whisper-cli как CLI-модель, Groq Whisper как облачный фолбэк
- **TTS**: Edge TTS (бесплатный, мультиязычный) — OpenClaw не поддерживает подключение произвольных локальных TTS-эндпоинтов

### Как работает

Голосовые сообщения в Telegram → OpenClaw вызывает whisper-cli → транскрипт идёт в LLM → ответ озвучивается через Edge TTS → голосовой ответ в Telegram.

### Настройка TTS-режима

В Telegram-чате с ботом:

```
/tts always     — всегда отвечать голосом
/tts inbound    — отвечать голосом, если пришло голосовое
/tts off        — выключить голосовые ответы
/tts status     — текущий режим
```

### Конфигурация (openclaw.json)

TTS:

```json
"messages": {
  "tts": {
    "auto": "inbound",
    "provider": "edge",
    "edge": {
      "voice": "en-US-AndrewMultilingualNeural"
    }
  }
}
```

STT:

```json
"tools": {
  "media": {
    "audio": {
      "enabled": true,
      "models": [
        {
          "type": "cli",
          "command": "whisper-cli",
          "args": ["-m", "path/to/ggml-large-v3-turbo.bin", "-f", "{{MediaPath}}", "-l", "auto", "--no-prints"],
          "timeoutSeconds": 30
        },
        {
          "provider": "groq",
          "model": "whisper-large-v3-turbo"
        }
      ]
    }
  }
}
```

Конфигурация применяется через Salt: `cd ~/src/salt && just apply openclaw_agent`.

## Тестирование

```bash
./test-tts.sh    # Тестирует Chatterbox (EN/RU) и Piper (EN/RU)
./test-stt.sh    # Тестирует whisper-cli на сгенерированном аудио
```

## Файловая структура

```
speech-engines/
├── check-rocm.sh              # Проверка ROCm-окружения
├── common.sh                  # Общие функции для скриптов
├── setup-chatterbox.sh        # Установка Chatterbox TTS
├── setup-piper.sh             # Установка Piper TTS
├── setup-whisper-cpp.sh       # Сборка whisper.cpp с HIPBLAS
├── piper-server.py            # OpenAI-совместимый HTTP-сервер для Piper
├── start-speech-stack.sh      # Запуск всех сервисов
├── stop-speech-stack.sh       # Остановка всех сервисов
├── test-tts.sh                # Тесты TTS
├── test-stt.sh                # Тесты STT
├── config/
│   ├── chatterbox.env         # Переменные окружения для Chatterbox
│   ├── openclaw-speech.json   # Сниппет конфигурации OpenClaw
│   └── README.md              # Инструкция по интеграции
├── systemd/
│   ├── chatterbox-tts.service # systemd user unit для Chatterbox
│   └── piper-tts.service      # systemd user unit для Piper
├── voices/                    # Модели (gitignored, скачиваются скриптами)
│   ├── ggml-large-v3-turbo.bin       # Whisper large-v3-turbo (1.6GB)
│   ├── en_US-lessac-medium.onnx      # Piper EN голос (61MB)
│   ├── ru_RU-irina-medium.onnx       # Piper RU голос (61MB)
│   └── ...
├── .venv-chatterbox/          # venv Chatterbox (gitignored)
├── .venv-piper/               # venv Piper (gitignored)
├── chatterbox-server/         # Клон Chatterbox-TTS-Server (gitignored)
└── whisper.cpp/               # Клон whisper.cpp (gitignored)
```

## Решение проблем

**Chatterbox не стартует / OOM**:
Проверить VRAM: `rocm-smi --showmeminfo vram`. Нужно ~8GB свободных. Остановить другие GPU-нагрузки.

**whisper-cli not found**:
Убедиться, что `~/.local/bin` в PATH. Перезапустить `setup-whisper-cpp.sh`.

**Piper: FileNotFoundError: piper**:
Перезапустить `systemctl --user restart piper-tts`. Скрипт piper-server.py сам находит `piper` в своём venv.

**Python version mismatch**:
PyTorch ROCm требует Python 3.12. Установить: `uv python install 3.12`.

**ROCm не видит GPU**:
Проверить: `rocm-smi`. Если пусто — `rocminfo | grep gfx`. Нужна группа `video` или `render`: `sudo usermod -aG render,video $USER`.

**Chatterbox voice 404**:
Нельзя использовать `"voice": "default"`. Нужно указывать реальное имя голоса: `"Emily.wav"`, `"Alice.wav"` и т.д.

**Долгий первый запрос Chatterbox**:
Первый запрос после старта загружает модель в GPU — может занять 10-30 сек. Последующие запросы: 3-5 сек.
