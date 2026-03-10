# Research: Streaming STT через PipeWire

**Branch**: `012-stream-stt-pipewire` | **Date**: 2026-03-10

## R1: Audio Capture from PipeWire

**Decision**: Use `pw-record` subprocesses for all audio capture modes.

**Rationale**: `pw-record` outputs raw PCM to stdout (via `-` filename), supports `--target` for any PipeWire node including `.monitor` suffixes for sink capture, and requires no additional Python dependencies. Dual capture is two subprocesses, mixed with numpy.

**Alternatives considered**:
- **sounddevice** (Python, via PortAudio): Monitor sources may not appear in `query_devices()` — known PipeWire/PortAudio issue. Would add a dependency.
- **Direct PipeWire Python bindings**: No mature library exists.
- **GStreamer pipewiresrc**: Heavyweight, adds GObject dependency chain.

**Usage patterns**:
```bash
# Mic (default source)
pw-record --rate 16000 --channels 1 --format f32 -

# App output (monitor of a sink)
pw-record --rate 16000 --channels 1 --format f32 --target <sink-name>.monitor -

# List available targets
pw-record --list-targets
```

## R2: VAD (Voice Activity Detection)

**Decision**: Use whisper.cpp built-in Silero VAD (ggml format, v6.2.0).

**Rationale**: whisper.cpp v1.8.3 (already installed) natively supports Silero VAD via `--vad` flag and `vad_params` in C API. The ggml VAD model is already present at `speech-engines/whisper.cpp/models/for-tests-silero-v6.2.0-ggml.bin`. Zero additional dependencies.

**Alternatives considered**:
- **silero-vad-lite** (pip): Self-contained ONNX, <1ms/chunk. Could be used as Python-side pre-filter to skip sending silence to GPU. Optional optimization.
- **silero-vad** (pip): Same model but requires PyTorch or onnxruntime dependency.
- **webrtcvad**: Only 50% TPR at 5% FPR — unacceptable accuracy.
- **Energy-based VAD**: Simple but poor discrimination of speech vs non-speech noise.

## R3: Whisper Inference Approach

**Decision**: Python ctypes bindings to existing `libwhisper.so` (HIPBLAS-enabled).

**Rationale**: The existing build at `speech-engines/whisper.cpp/build/src/libwhisper.so.1.8.3` is compiled with HIPBLAS/ROCm support (confirmed: links against `libamdhip64.so.7`, `libhipblas.so.3`, `librocblas.so.5`). No Python binding package supports HIPBLAS. ctypes gives direct access to the C API with GPU acceleration.

**Key API surface** (~15 functions from `whisper.h`):
- `whisper_init_from_file_with_params()` — load model
- `whisper_full()` — run inference on audio buffer
- `whisper_full_n_segments()` / `whisper_full_get_segment_text()` — get results
- `whisper_full_default_params()` — get default parameters
- `new_segment_callback` — callback fired per segment (for partial results)
- `whisper_free()` — cleanup

**Alternatives considered**:
- **pywhispercpp** (v1.4.1): No HIPBLAS/ROCm support — would lose GPU acceleration.
- **whisper-cli subprocess**: No streaming — requires temp files per chunk, no partial results.
- **faster-whisper + ROCm**: CTranslate2 lacks native ROCm. Community forks are fragile.
- **whisper-stream binary**: Requires SDL2, can't use PipeWire nodes/monitors, no dual-source.

## R4: Partial/Intermediate Results

**Decision**: Sliding window approach (ported from whisper.cpp `stream.cpp` example).

**How it works**:
1. Maintain a rolling audio ring buffer
2. Every `step_ms` (default 3000ms), take latest `length_ms` (default 10000ms) of audio
3. Keep `keep_ms` (200ms) overlap for context continuity
4. Call `whisper_full()` on the window
5. Use `new_segment_callback` for partial results during inference
6. After VAD detects end-of-speech, emit the final result

**Parameters** (from stream.cpp):
- `step_ms`: 3000ms — audio step size (how often to run inference)
- `length_ms`: 10000ms — audio window length
- `keep_ms`: 200ms — overlap from previous step
- `vad_thold`: 0.60 — VAD silence threshold

## R5: Architecture

**Decision**: Python CLI with threading (not asyncio).

```
         Python CLI Process
┌──────────────────────────────────────┐
│  Thread 1: pw-record (mic) → buffer  │
│  Thread 2: pw-record (app) → buffer  │  (optional)
│  Thread 3: Inference loop            │
│    └─ sliding window → whisper_full  │
│    └─ new_segment_callback → output  │
│  Main:    CLI, signal handling       │
└──────────────────────────────────────┘
```

**Why threading**: `pw-record` stdout reads are blocking I/O. `whisper_full()` is a blocking C call that releases the GIL. numpy mixing also releases GIL. No benefit from async.

## R6: Key Files on System

| Component | Path |
|-----------|------|
| libwhisper.so | `speech-engines/whisper.cpp/build/src/libwhisper.so.1.8.3` |
| whisper.h (API) | `speech-engines/whisper.cpp/include/whisper.h` |
| Whisper model | `speech-engines/voices/ggml-large-v3-turbo.bin` |
| Silero VAD model | `speech-engines/whisper.cpp/models/for-tests-silero-v6.2.0-ggml.bin` |
| stream.cpp reference | `speech-engines/whisper.cpp/examples/stream/stream.cpp` |
| whisper-cli | `~/.local/bin/whisper-cli` |

## Recommended Stack

```
pw-record (subprocess)     →  raw f32 PCM 16kHz mono
  ↓
Ring buffer (numpy)        →  sliding window
  ↓
libwhisper.so (ctypes)     →  HIPBLAS GPU inference + Silero VAD
  ↓
stdout (text / JSONL)      →  partial + final results
```

Dependencies: numpy (already in venvs), no new heavy deps.
