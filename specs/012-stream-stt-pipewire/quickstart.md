# Quickstart: Streaming STT через PipeWire

**Branch**: `012-stream-stt-pipewire` | **Date**: 2026-03-10

## Prerequisites

- PipeWire работает (стандарт для CachyOS)
- whisper.cpp собран с HIPBLAS (feature 3)
- Модель `ggml-large-v3-turbo.bin` в `speech-engines/voices/`
- Python 3.12

---

## 1. Базовое распознавание с микрофона

```bash
stream-stt
```

Говорить в микрофон. Промежуточный текст обновляется в реальном времени, финальный результат фиксируется после паузы.

**Expected**: Текст появляется в терминале в течение 3 секунд после паузы.

---

## 2. Распознавание аудио из приложения

```bash
# Посмотреть доступные источники
stream-stt --list-sources

# Захватить аудио из Firefox
stream-stt --source Firefox.monitor
```

**Expected**: Транскрипция соответствует воспроизводимому в приложении аудио.

---

## 3. Двойной захват (звонок)

```bash
stream-stt --source rme-mic --source2 Firefox.monitor --label me --label2 them
```

**Expected**:
```
[me] Привет, как дела?
[them] Hello, I'm doing great.
```

---

## 4. JSON-вывод для автоматизации

```bash
stream-stt --format json | tee transcript.jsonl
```

**Expected**: Каждая строка — валидный JSON:
```json
{"text":"Привет","type":"final","source":"mic","lang":"ru","ts":3.456}
```

---

## 5. Pipe-интеграция

```bash
# Только финальные результаты, без partial
stream-stt --no-partial --format json | jq -r '.text'
```

**Expected**: Чистый текст в stdout, по одной фразе на строку, без задержки буферизации.

---

## Quick Reference

| Сценарий | Команда |
|----------|---------|
| Микрофон (по умолчанию) | `stream-stt` |
| Конкретный источник | `stream-stt -s <name>` |
| Двойной захват | `stream-stt -s mic -s2 app.monitor` |
| Список источников | `stream-stt --list-sources` |
| JSON-вывод | `stream-stt -f json` |
| Без промежуточных | `stream-stt --no-partial` |
| Русский язык | `stream-stt --language ru` |
| Подробный вывод | `stream-stt -v` |
