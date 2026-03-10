#!/usr/bin/env bash
# Smoke test for STT: whisper-cli transcription
set -euo pipefail

source "$(dirname "$0")/common.sh"

MODEL="$VOICES_DIR/ggml-large-v3-turbo.bin"
TEST_AUDIO="/tmp/speech-test/chatterbox_en.mp3"

log "=== STT Smoke Tests ==="

# Check whisper-cli exists
if ! command -v whisper-cli &>/dev/null; then
    error "whisper-cli not found on PATH. Run setup-whisper-cpp.sh first."
fi
log "whisper-cli: $(which whisper-cli)"

# Check model exists
if [[ ! -f "$MODEL" ]]; then
    error "Model not found: $MODEL. Run setup-whisper-cpp.sh first."
fi
log "Model: $MODEL ($(du -h "$MODEL" | cut -f1))"

# Use TTS test output if available, otherwise generate a test file
if [[ ! -f "$TEST_AUDIO" ]]; then
    warn "No test audio found at $TEST_AUDIO"
    warn "Run test-tts.sh first to generate test audio, or provide a WAV file."

    # Generate a simple test WAV with a tone
    log "Generating synthetic test WAV..."
    python3 -c "
import wave, struct, math
frames = []
for i in range(16000):  # 1 second at 16kHz
    v = int(16000 * math.sin(2 * math.pi * 440 * i / 16000))
    frames.append(struct.pack('<h', v))
with wave.open('/tmp/whisper_stt_test.wav', 'w') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(16000)
    w.writeframes(b''.join(frames))
print('Generated 1s 440Hz tone')
" 2>/dev/null
    TEST_AUDIO="/tmp/whisper_stt_test.wav"
fi

# Run transcription
log "Transcribing: $TEST_AUDIO"
RESULT=$(whisper-cli -m "$MODEL" -f "$TEST_AUDIO" -l auto --no-prints 2>/dev/null || true)

if [[ -n "$RESULT" ]]; then
    log "PASS: Transcription result:"
    echo "  $RESULT"
else
    # whisper-cli may output to stderr or use different flags
    log "Trying alternative invocation..."
    RESULT=$(whisper-cli -m "$MODEL" -f "$TEST_AUDIO" -l auto 2>&1 | grep -v "^whisper_" | grep -v "^\[" || true)
    if [[ -n "$RESULT" ]]; then
        log "PASS: Transcription result:"
        echo "  $RESULT"
    else
        warn "FAIL: No transcription output. Check whisper-cli installation."
        exit 1
    fi
fi

log "=== STT test complete ==="
