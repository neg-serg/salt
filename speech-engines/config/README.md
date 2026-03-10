# Speech Engine Configuration

## OpenClaw Integration

The `openclaw-speech.json` file contains the TTS and STT configuration snippet for OpenClaw.

### How to apply

Merge the contents of `openclaw-speech.json` into your OpenClaw config at:

```
/home/neg/src/salt/states/configs/openclaw.json.j2
```

**Important**: In the Salt Jinja2 template, `{{MediaPath}}` must be escaped as `{{ '{{MediaPath}}' }}`.

**TTS section** — add or update under the `messages` key:

```json
"tts": {
  "auto": "inbound",
  "provider": "edge",
  "edge": {
    "voice": "en-US-AndrewMultilingualNeural"
  }
}
```

OpenClaw TTS supports `openai`, `elevenlabs`, and `edge` providers. Custom local TTS endpoints (Chatterbox, Piper) are **not directly supported** as OpenClaw providers — they can be used as standalone services via curl.

**STT section** — add `whisper-cli` as a CLI model entry in `tools.media.audio.models`:

```json
{
  "type": "cli",
  "command": "whisper-cli",
  "args": ["-m", "path/to/ggml-large-v3-turbo.bin", "-f", "{{MediaPath}}", "-l", "auto", "--no-prints"],
  "timeoutSeconds": 30
}
```

OpenClaw also auto-detects `whisper-cli` on PATH (uses `WHISPER_CPP_MODEL` env var or bundled tiny model).

### TTS modes

- `"off"` — TTS disabled (default)
- `"inbound"` — reply with voice when user sends voice
- `"always"` — always reply with voice
- `"tagged"` — only when model tags reply for voice

### Fallback chain

- **TTS**: Edge TTS (free, multilingual, no API key needed)
- **STT**: whisper-cli (local GPU, HIPBLAS) → Groq Whisper (cloud) → error

### Standalone TTS services

Chatterbox (port 8000) and Piper (port 8001) are available as standalone OpenAI-compatible TTS endpoints. Use via curl or any OpenAI-compatible client:

```bash
curl http://127.0.0.1:8000/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"model":"chatterbox","input":"Hello","voice":"Emily.wav"}' \
  -o output.wav
```
