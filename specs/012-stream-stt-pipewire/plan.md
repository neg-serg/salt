# Implementation Plan: Streaming STT через PipeWire

**Branch**: `012-stream-stt-pipewire` | **Date**: 2026-03-10 | **Spec**: [spec.md](spec.md)

## Summary

CLI-утилита для непрерывного распознавания речи из PipeWire-аудиопотоков. Захват аудио через `pw-record` субпроцессы, VAD и inference через `libwhisper.so` (ctypes, HIPBLAS GPU), промежуточные и финальные результаты в stdout (текст или JSONL).

## Technical Context

**Language/Version**: Python 3.12
**Primary Dependencies**: numpy, ctypes (stdlib), subprocess (stdlib)
**Storage**: N/A (streaming tool, no persistent state)
**Testing**: pytest + recorded WAV fixtures
**Target Platform**: Linux (CachyOS/Arch), PipeWire, AMD ROCm
**Project Type**: CLI utility (new package `stream-stt` in monorepo)
**Performance Goals**: Partial results during speech, final result <3s after pause
**Constraints**: ~4GB VRAM for whisper inference, <200MB RSS
**Scale/Scope**: Single-user CLI tool, continuous operation 30+ min

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Monorepo Cohesion | PASS | New `stream-stt/` package with own `pyproject.toml`. Does not use LanceDB/embeddings — shares only repo structure. |
| II. Content Agnosticism | N/A | Not a content indexing tool. |
| III. Local-First Execution | PASS | All processing local: PipeWire audio, whisper.cpp HIPBLAS, no cloud. |
| IV. CLI as Primary Interface | PASS | CLI entry point, text-in/text-out, JSON output, composable via pipes. |
| V. Incremental Processing | N/A | Streaming tool, no indexing. |
| VI. Hybrid Search | N/A | Not a search tool. |

No violations. Principles I, III, IV directly apply and are satisfied.

## Project Structure

### Documentation (this feature)

```text
specs/012-stream-stt-pipewire/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── cli.md
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
stream-stt/
├── pyproject.toml
├── stream_stt/
│   ├── __init__.py
│   ├── cli.py              # CLI entry point (argparse)
│   ├── audio.py             # PipeWire audio capture (pw-record wrapper)
│   ├── whisper_binding.py   # ctypes bindings to libwhisper.so
│   ├── vad.py               # VAD configuration and helpers
│   ├── pipeline.py          # Streaming pipeline: capture → buffer → inference → output
│   ├── buffer.py            # Ring buffer for sliding window audio
│   └── output.py            # Text and JSONL formatters
└── tests/
    ├── test_buffer.py
    ├── test_audio.py
    ├── test_whisper_binding.py
    └── fixtures/
        └── test_speech.wav  # Short recorded test clip
```

**Structure Decision**: Flat package at repo root (`stream-stt/`), following monorepo convention. Independent `pyproject.toml` with `stream-stt` CLI entry point.

## Complexity Tracking

No violations — no complexity justifications needed.
