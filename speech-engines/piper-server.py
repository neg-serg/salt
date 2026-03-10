"""Minimal OpenAI-compatible TTS server wrapping Piper TTS (CPU).

Exposes:
  POST /v1/audio/speech  — generate speech from text
  GET  /v1/models        — list available voices (health check)

Usage:
  python piper-server.py --port 8001 --voices-dir ./voices
"""

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel

app = FastAPI(title="Piper TTS (OpenAI-compatible)")

VOICES_DIR: Path = Path("voices")
VOICES: dict[str, Path] = {}
# Resolve piper binary: prefer the one in the same venv as this Python
_venv_piper = Path(sys.executable).parent / "piper"
PIPER_BIN: str = str(_venv_piper) if _venv_piper.exists() else (shutil.which("piper") or "piper")


class SpeechRequest(BaseModel):
    model: str = "piper"
    input: str
    voice: str = "default"
    response_format: str = "wav"
    speed: float = 1.0


def discover_voices(voices_dir: Path) -> dict[str, Path]:
    """Find all .onnx voice models in the voices directory."""
    voices = {}
    for onnx in sorted(voices_dir.glob("*.onnx")):
        name = onnx.stem  # e.g. "en_US-lessac-medium"
        voices[name] = onnx
    return voices


@app.get("/v1/models")
def list_models():
    return {
        "object": "list",
        "data": [{"id": name, "object": "model", "owned_by": "local"} for name in VOICES],
    }


@app.post("/v1/audio/speech")
def create_speech(req: SpeechRequest):
    if not req.input.strip():
        raise HTTPException(400, detail="Input text is required")

    # Select voice
    voice = req.voice
    if voice == "default":
        # Pick first available voice
        if not VOICES:
            raise HTTPException(503, detail="No voice models found")
        voice = next(iter(VOICES))

    if voice not in VOICES:
        # Try partial match
        matches = [k for k in VOICES if voice in k]
        if matches:
            voice = matches[0]
        else:
            raise HTTPException(
                400,
                detail=f"Voice '{voice}' not found. Available: {list(VOICES.keys())}",
            )

    model_path = VOICES[voice]

    # Generate audio via piper CLI
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        out_path = f.name

    try:
        result = subprocess.run(
            [
                PIPER_BIN,
                "--model",
                str(model_path),
                "--output_file",
                out_path,
                "--length_scale",
                str(1.0 / req.speed),
            ],
            input=req.input.encode(),
            capture_output=True,
            timeout=30,
        )
        if result.returncode != 0:
            raise HTTPException(500, detail=f"Piper error: {result.stderr.decode()[:500]}")

        audio_data = Path(out_path).read_bytes()
    finally:
        Path(out_path).unlink(missing_ok=True)

    if not audio_data:
        raise HTTPException(500, detail="No audio generated")

    content_type = "audio/wav"
    if req.response_format == "mp3":
        # Convert to mp3 if ffmpeg available
        try:
            proc = subprocess.run(
                ["ffmpeg", "-i", "-", "-f", "mp3", "-"],
                input=audio_data,
                capture_output=True,
                timeout=10,
            )
            if proc.returncode == 0:
                audio_data = proc.stdout
                content_type = "audio/mpeg"
        except FileNotFoundError:
            pass  # Return WAV if no ffmpeg

    return Response(content=audio_data, media_type=content_type)


def main():
    import uvicorn

    parser = argparse.ArgumentParser(description="Piper TTS OpenAI-compatible server")
    parser.add_argument("--port", type=int, default=8001)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument(
        "--voices-dir",
        type=Path,
        default=Path(__file__).parent / "voices",
    )
    args = parser.parse_args()

    global VOICES_DIR, VOICES
    VOICES_DIR = args.voices_dir
    VOICES = discover_voices(VOICES_DIR)

    if not VOICES:
        print(f"WARNING: No .onnx voice models found in {VOICES_DIR}")
    else:
        print(f"Found {len(VOICES)} voice(s): {list(VOICES.keys())}")

    uvicorn.run(app, host=args.host, port=args.port)


if __name__ == "__main__":
    main()
