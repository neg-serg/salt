# Tasks: Streaming STT через PipeWire

**Feature**: `012-stream-stt-pipewire` | **Date**: 2026-03-10 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## Phase 1: Setup

- [x] T001 Create package structure: `stream-stt/pyproject.toml`, `stream-stt/stream_stt/__init__.py`
- [x] T002 Configure `pyproject.toml` with dependencies (numpy), CLI entry point `stream-stt`, Python 3.12 in `stream-stt/pyproject.toml`
- [x] T003 Create test fixtures directory and test config in `stream-stt/tests/__init__.py` and `stream-stt/tests/fixtures/`

## Phase 2: Foundational

- [x] T004 Implement ring buffer for sliding window audio in `stream-stt/stream_stt/buffer.py`
- [x] T005 [P] Implement ctypes bindings to libwhisper.so (init, full, segments, free, params, callbacks) in `stream-stt/stream_stt/whisper_binding.py`
- [x] T006 [P] Implement PipeWire audio capture via pw-record subprocess (start, read PCM, stop, list-targets) in `stream-stt/stream_stt/audio.py`
- [x] T007 Implement VAD configuration helpers (Silero VAD params for whisper_full) in `stream-stt/stream_stt/vad.py`
- [x] T008 Implement output formatters (text with partial overwrite, JSONL with flush) in `stream-stt/stream_stt/output.py`

## Phase 3: User Story 1 — Непрерывное распознавание с микрофона (P1)

**Goal**: Пользователь запускает `stream-stt`, говорит в микрофон, видит текст в реальном времени.

**Independent Test**: Запустить утилиту, произнести фразы, проверить что текст появляется <3с после паузы.

- [x] T009 [US1] Implement streaming pipeline: capture thread → ring buffer → inference loop → output in `stream-stt/stream_stt/pipeline.py`
- [x] T010 [US1] Implement CLI entry point with argparse (--model, --language, --step, --length, --vad-threshold, --no-partial, --verbose, --help) in `stream-stt/stream_stt/cli.py`
- [x] T011 [US1] Wire signal handling (SIGINT/SIGTERM → graceful shutdown, flush pending, exit 0) in `stream-stt/stream_stt/cli.py`
- [x] T012 [US1] Implement partial result display with `\r` overwrite for TTY and suppression for pipe in `stream-stt/stream_stt/output.py`
- [x] T013 [US1] Auto-detect whisper model path (search `speech-engines/voices/ggml-large-v3-turbo.bin`) in `stream-stt/stream_stt/whisper_binding.py`

## Phase 4: User Story 2 — Распознавание аудио из приложений (P2)

**Goal**: Захват аудио из приложения через PipeWire monitor + двойной захват (mic + app).

**Independent Test**: Запустить аудио в Firefox, указать `--source Firefox.monitor`, проверить транскрипцию.

- [x] T014 [US2] Implement `--list-sources` via pw-record --list-targets with formatted table output in `stream-stt/stream_stt/audio.py`
- [x] T015 [US2] Add `--source` flag: resolve node name/ID, pass as --target to pw-record in `stream-stt/stream_stt/audio.py` and `stream-stt/stream_stt/cli.py`
- [x] T016 [US2] Implement dual capture: `--source2`, `--label`, `--label2` flags with second pw-record thread in `stream-stt/stream_stt/pipeline.py`
- [x] T017 [US2] Add source label prefixing `[label]` to text output (omit prefix when single source) in `stream-stt/stream_stt/output.py`

## Phase 5: User Story 3 — Вывод транскрипции для интеграции (P3)

**Goal**: JSON-вывод и pipe-совместимость для автоматизации.

**Independent Test**: `stream-stt --format json | head -1 | python -m json.tool` — валидный JSON.

- [x] T018 [US3] Implement `--format json` JSONL output (text, type, source, lang, ts fields) with immediate flush in `stream-stt/stream_stt/output.py`
- [x] T019 [US3] Implement pipe detection (isatty) — suppress partial in non-TTY, no `[label]` prefix without `--source2` in `stream-stt/stream_stt/output.py`
- [x] T020 [US3] Add `--no-partial` flag to disable intermediate results entirely in `stream-stt/stream_stt/pipeline.py` and `stream-stt/stream_stt/cli.py`

## Phase 6: Polish & Cross-Cutting

- [x] T021 Add error handling: exit code 1 (bad args), 2 (PipeWire errors), 3 (whisper errors) in `stream-stt/stream_stt/cli.py`
- [x] T022 [P] Add stderr status messages (model loading, capture start, shutdown summary) in `stream-stt/stream_stt/pipeline.py`
- [x] T023 [P] Add `--verbose` debug output (VAD events, inference timing, token count) in `stream-stt/stream_stt/pipeline.py`
- [x] T024 Add memory management: limit ring buffer to 30s, prevent unbounded growth over 30+ min sessions in `stream-stt/stream_stt/buffer.py`
- [x] T025 Write unit tests for ring buffer (wrap, overlap, window extraction) in `stream-stt/tests/test_buffer.py`
- [x] T026 [P] Write unit tests for output formatters (text, JSON, partial suppression) in `stream-stt/tests/test_output.py`

## Dependencies

```text
T001 → T002 → T003 (setup chain)
T003 → T004, T005, T006, T007, T008 (foundational, T005/T006 parallel)
T004 + T005 + T006 + T007 + T008 → T009 (pipeline needs all components)
T009 → T010 → T011 (US1 chain)
T009 → T012, T013 (US1, parallel with T010)
T010 → T014, T015 (US2 extends CLI)
T009 → T016 → T017 (US2 dual capture)
T010 → T018, T019, T020 (US3 extends output)
All US phases → T021..T026 (polish)
```

## Parallel Execution Examples

### Phase 2 (Foundational)
```
T004 ─────────────┐
T005 (whisper) ───┤──→ T009 (pipeline)
T006 (audio) ─────┤
T007 (vad) ───────┤
T008 (output) ────┘
```

### Phase 6 (Polish)
```
T022 (stderr) ───┐
T023 (verbose) ──┤──→ done
T025 (tests) ────┤
T026 (tests) ────┘
```

## Implementation Strategy

1. **MVP (Phase 1-3)**: Single mic source → text output with partial results. Validates the full pipeline end-to-end.
2. **Multi-source (Phase 4)**: Adds PipeWire source selection and dual capture. Builds on working pipeline.
3. **Integration output (Phase 5)**: JSON format and pipe compatibility. Extends existing output formatters.
4. **Hardening (Phase 6)**: Error handling, verbose mode, tests, memory limits.
