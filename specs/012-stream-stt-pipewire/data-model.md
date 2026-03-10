# Data Model: Streaming STT через PipeWire

**Branch**: `012-stream-stt-pipewire` | **Date**: 2026-03-10

## Entities

### AudioSource

Represents a PipeWire audio source that can be captured.

| Field | Type | Description |
|-------|------|-------------|
| node_id | integer | PipeWire node ID |
| name | string | Human-readable name (e.g., "rme-mic", "Firefox") |
| type | enum | `input` (microphone), `monitor` (app output sink monitor) |
| sample_rate | integer | Native sample rate (resampled to 16000 for whisper) |
| label | string | User-assigned label for output tagging (e.g., "mic", "app") |

**Discovery**: Via `pw-record --list-targets` or `pw-cli list-objects`.

### SpeechSegment

A contiguous fragment of detected speech from a single audio source.

| Field | Type | Description |
|-------|------|-------------|
| source_label | string | Label of the AudioSource this came from |
| start_time | float | Start time in seconds (relative to session start) |
| end_time | float | End time in seconds |
| audio_data | float32[] | Raw PCM samples, 16kHz mono |

**Lifecycle**: Created when VAD detects speech onset → grows as speech continues → finalized when VAD detects silence.

### TranscriptionResult

Result of whisper inference on a speech segment or sliding window.

| Field | Type | Description |
|-------|------|-------------|
| text | string | Transcribed text |
| language | string | Detected language code (e.g., "en", "ru") |
| timestamp | float | Wall-clock time when result was produced |
| source_label | string | Label of the AudioSource |
| result_type | enum | `partial` (intermediate, may change) or `final` (after pause) |
| confidence | float | Model confidence (0.0–1.0), if available |

**Lifecycle**: `partial` results emitted during sliding window inference → replaced by `final` result when VAD detects end of speech.

## Relationships

```
AudioSource (1) ──captures──→ (*) SpeechSegment
SpeechSegment (1) ──produces──→ (*) TranscriptionResult
                                    (1 final + 0..N partials)
```

## State Transitions

### Pipeline State

```
INIT → CAPTURING → PROCESSING → CAPTURING → ... → STOPPED
         ↑            │
         └────────────┘
```

- **INIT**: Model loading, PipeWire connection
- **CAPTURING**: Reading audio from pw-record, filling ring buffer
- **PROCESSING**: VAD detected speech, running whisper_full() on window
- **STOPPED**: Ctrl+C received, cleanup

### TranscriptionResult Lifecycle

```
(speech detected) → partial → partial → ... → final (silence detected)
```

Partial results overwrite each other in terminal display. Final result is printed on a new line.

## Data Volume

- Audio: 16000 samples/sec × 4 bytes = 64 KB/sec per source
- Ring buffer: 30 sec window = ~1.9 MB per source
- Inference: ~4 GB VRAM (model), ~200 MB RSS (Python process)
- Output: ~1-10 transcription results per minute (depends on speech density)
