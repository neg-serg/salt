"""Minimal OpenAI-compatible STT server wrapping whisper-cli (whisper.cpp).

Exposes:
  POST /v1/audio/transcriptions  — transcribe audio to text
  GET  /v1/models                — list available models (health check)

Usage:
  python whisper-server.py --port 8002 --model ./voices/ggml-large-v3-turbo.bin
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse

app = FastAPI(title="Whisper STT (OpenAI-compatible)")

MODEL_PATH: Path = Path()
WHISPER_BIN: str = "whisper-cli"
LD_LIBRARY_PATH: str = ""


def run_whisper(audio_path: str, language: str = "auto") -> str:
    env = os.environ.copy()
    if LD_LIBRARY_PATH:
        env["LD_LIBRARY_PATH"] = LD_LIBRARY_PATH + ":" + env.get("LD_LIBRARY_PATH", "")

    # Convert to WAV if needed
    tmpwav = None
    input_path = audio_path
    if not audio_path.endswith(".wav"):
        tmpwav = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        tmpwav.close()
        subprocess.run(
            [
                "ffmpeg",
                "-i",
                audio_path,
                "-ar",
                "16000",
                "-ac",
                "1",
                tmpwav.name,
                "-y",
                "-loglevel",
                "quiet",
            ],
            check=True,
        )
        input_path = tmpwav.name

    try:
        result = subprocess.run(
            [
                WHISPER_BIN,
                "-m",
                str(MODEL_PATH),
                "-f",
                input_path,
                "-l",
                language,
                "--no-prints",
            ],
            capture_output=True,
            text=True,
            timeout=120,
            env=env,
        )
        if result.returncode != 0:
            raise RuntimeError(f"whisper-cli error: {result.stderr[:500]}")
        # Strip timestamps like "[00:00:00.000 --> 00:00:02.000]  "
        lines = []
        for line in result.stdout.splitlines():
            if line.strip():
                # Remove timestamp prefix if present
                if "-->" in line:
                    text = line.split("]", 1)[-1].strip()
                    if text:
                        lines.append(text)
                else:
                    lines.append(line.strip())
        return " ".join(lines)
    finally:
        if tmpwav and Path(tmpwav.name).exists():
            Path(tmpwav.name).unlink()


@app.get("/v1/models")
def list_models():
    return {
        "object": "list",
        "data": [{"id": MODEL_PATH.stem, "object": "model", "owned_by": "local"}],
    }


@app.post("/v1/audio/transcriptions")
async def transcribe(
    file: UploadFile = File(...),
    model: str = Form(default="whisper"),
    language: str = Form(default="auto"),
    response_format: str = Form(default="json"),
):
    # Save uploaded file to temp
    suffix = Path(file.filename).suffix if file.filename else ".ogg"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name

    try:
        text = run_whisper(tmp_path, language=language)
    except Exception as e:
        raise HTTPException(500, detail=str(e))
    finally:
        Path(tmp_path).unlink(missing_ok=True)

    if response_format == "text":
        return text
    return JSONResponse({"text": text})


def main():
    global MODEL_PATH, WHISPER_BIN, LD_LIBRARY_PATH

    parser = argparse.ArgumentParser(description="Whisper STT OpenAI-compatible server")
    parser.add_argument("--port", type=int, default=8002)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument(
        "--model",
        type=Path,
        default=Path(__file__).parent / "voices" / "ggml-large-v3-turbo.bin",
    )
    parser.add_argument("--whisper-bin", default="whisper-cli")
    parser.add_argument("--ld-library-path", default="")
    args = parser.parse_args()

    MODEL_PATH = args.model
    WHISPER_BIN = args.whisper_bin
    LD_LIBRARY_PATH = args.ld_library_path

    if not MODEL_PATH.exists():
        print(f"ERROR: Model not found: {MODEL_PATH}", file=sys.stderr)
        sys.exit(1)

    print(f"Model: {MODEL_PATH}")
    print(f"Listening on {args.host}:{args.port}")

    import uvicorn

    uvicorn.run(app, host=args.host, port=args.port)


if __name__ == "__main__":
    main()
