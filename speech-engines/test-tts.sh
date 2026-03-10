#!/usr/bin/env bash
# Smoke test for TTS engines: Chatterbox (port 8000) and Piper (port 8001)
set -euo pipefail

source "$(dirname "$0")/common.sh"

PASS=0
FAIL=0
OUTPUT_DIR="/tmp/speech-test"
mkdir -p "$OUTPUT_DIR"

test_tts() {
    local name="$1" port="$2" model="$3" text="$4" lang="$5" voice="${6:-default}"
    local outfile="$OUTPUT_DIR/${name}_${lang}.mp3"

    log "Testing $name ($lang)..."

    # Health check
    if ! curl -sf "http://127.0.0.1:${port}/v1/models" >/dev/null 2>&1; then
        warn "FAIL: $name not responding on port $port"
        ((FAIL++))
        return
    fi

    # Generate speech
    local http_code
    http_code=$(curl -sf -w "%{http_code}" \
        "http://127.0.0.1:${port}/v1/audio/speech" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${model}\",\"input\":\"${text}\",\"voice\":\"${voice}\"}" \
        -o "$outfile" 2>/dev/null || echo "000")

    if [[ "$http_code" == "200" ]] && [[ -f "$outfile" ]] && [[ -s "$outfile" ]]; then
        local size
        size=$(du -h "$outfile" | cut -f1)
        local filetype
        filetype=$(file -b "$outfile" | head -c 40)
        log "PASS: $name ($lang) -> $outfile ($size, $filetype)"
        ((PASS++))
    else
        warn "FAIL: $name ($lang) HTTP $http_code, file: $(ls -la "$outfile" 2>/dev/null || echo 'missing')"
        ((FAIL++))
    fi
}

log "=== TTS Smoke Tests ==="

# Chatterbox tests (voice must be a predefined voice file name)
test_tts "chatterbox" 8000 "chatterbox" "Hello, this is a test of the Chatterbox speech engine." "en" "Emily.wav"
test_tts "chatterbox" 8000 "chatterbox" "Привет, это тест системы синтеза речи Чаттербокс." "ru" "Emily.wav"

# Piper tests (voice is the model stem name)
test_tts "piper" 8001 "piper" "Hello, this is a test of the Piper fallback engine." "en" "en_US-lessac-medium"
test_tts "piper" 8001 "piper" "Привет, это тест системы Пайпер." "ru" "ru_RU-irina-medium"

log "=== Results: $PASS passed, $FAIL failed ==="
log "Audio files in: $OUTPUT_DIR/"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
