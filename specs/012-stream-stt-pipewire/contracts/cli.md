# CLI Contract: stream-stt

**Branch**: `012-stream-stt-pipewire` | **Date**: 2026-03-10

## Command

```
stream-stt [OPTIONS]
```

## Options

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--source SOURCE` | `-s` | (default mic) | PipeWire source: node name, node ID, or "default" |
| `--source2 SOURCE` | `-s2` | (none) | Second PipeWire source for dual capture |
| `--label LABEL` | `-l` | "mic" | Label for primary source in output |
| `--label2 LABEL` | `-l2` | "app" | Label for second source in output |
| `--format FORMAT` | `-f` | "text" | Output format: `text` or `json` |
| `--model PATH` | `-m` | (auto-detect) | Path to whisper ggml model file |
| `--language LANG` | | "auto" | Language code (`en`, `ru`, `auto`) |
| `--list-sources` | | | List available PipeWire audio sources and exit |
| `--step MS` | | 3000 | Inference step interval in milliseconds |
| `--length MS` | | 10000 | Audio window length in milliseconds |
| `--vad-threshold FLOAT` | | 0.6 | VAD silence detection threshold (0.0–1.0) |
| `--no-partial` | | | Disable partial/intermediate results |
| `--verbose` | `-v` | | Print debug info to stderr |
| `--help` | `-h` | | Show help and exit |

## Output Formats

### Text (default)

Terminal output with partial result overwriting (via `\r`):

```
[mic] Пр...                          ← partial (overwrites in place)
[mic] Привет, как дела?              ← final (new line)
[app] Hello, I'm doing great.       ← final from second source
```

When piped (not a TTY), partial results are suppressed — only final results emitted:

```
[mic] Привет, как дела?
[app] Hello, I'm doing great.
```

Without `--source2`, the `[label]` prefix is omitted:

```
Привет, как дела?
```

### JSON (`--format json`)

One JSON object per line (JSONL), flushed immediately:

```json
{"text":"Пр...","type":"partial","source":"mic","lang":"ru","ts":1.234}
{"text":"Привет, как дела?","type":"final","source":"mic","lang":"ru","ts":4.567}
{"text":"Hello, I'm doing great.","type":"final","source":"app","lang":"en","ts":6.789}
```

| Field | Type | Description |
|-------|------|-------------|
| `text` | string | Transcribed text |
| `type` | string | `"partial"` or `"final"` |
| `source` | string | Source label |
| `lang` | string | Detected language ISO code |
| `ts` | float | Seconds since session start |

## List Sources (`--list-sources`)

```
ID    Name                              Type
45    rme-mic                           input
78    alsa_output.usb-RME_ADI-2_4.monitor  monitor
92    Firefox                           monitor
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Normal exit (Ctrl+C) |
| 1 | Configuration error (bad args, model not found) |
| 2 | PipeWire error (source not found, connection failed) |
| 3 | Whisper error (model load failed, GPU unavailable) |

## Signals

- **SIGINT (Ctrl+C)**: Graceful shutdown — stop capture, flush pending results, exit 0
- **SIGTERM**: Same as SIGINT

## Stderr

Progress and errors go to stderr:

```
Loading model: speech-engines/voices/ggml-large-v3-turbo.bin
Model loaded (4.2s), VRAM: 3.8GB
Capturing from: rme-mic (16000 Hz)
^C
Stopped. Duration: 5m 23s, segments: 47
```

With `--verbose`, adds per-segment timing:

```
[debug] VAD: speech start at 12.345s
[debug] inference: 245ms, 12 tokens
[debug] VAD: speech end at 15.678s → final
```
