# Video AI Setup Guide

Local video generation using AI models on AMD RX 7900 XTX (24GB VRAM).

## Prerequisites

- AMD RX 7900 XTX (24GB VRAM, gfx1100)
- ROCm 6.3-6.4 (CachyOS ships compatible packages)
- `/mnt/one` mounted with ~100 GB free space for full model roster
- ffmpeg (installed by default on CachyOS)

## Quick Start

1. Enable the feature and desired models in `states/data/hosts.yaml`:

   ```yaml
   features:
     video_ai: true
   ```

2. Enable models in `states/data/video_ai.yaml`:

   ```yaml
   models:
     - id: ltx-23-distilled-fp8
       enabled: true  # best quality, 4-8 step distilled
   ```

3. Apply:

   ```bash
   just apply video_ai
   ```

4. Generate video:

   ```bash
   gen-video "a cat walking on the moon at sunset"
   ```

## Active Models

| Model | VRAM | Speed (est.) | Quality | Modes |
|-------|------|-------------|---------|-------|
| **LTX-2.3 22B Distilled FP8** (default) | 22 GB | ~2 min | Excellent | t2v, i2v |
| Wan2.1 14B GGUF Q5 | 11 GB | ~20 min | Very good | t2v |
| Chroma1-HD (image) | 20 GB | ~30 sec | Excellent | t2i, i2i |

Speed estimates assume AMD RX 7900 XT with ROCm 6.3+. Actual times vary by prompt complexity and resolution.

## Rejected Models (do not re-add)

| Model | Reason | Date |
|-------|--------|------|
| LTX-Video 2B | Quality far below 22B; 720p max, visible artifacts | 2026-03 |
| LTX-2.3 22B Dev FP8 | 29 GB, exceeds 24 GB VRAM even with --lowvram | 2026-03 |
| LTX-2.3 22B GGUF Q4 | GGUF pipeline broken on RDNA3; OOM with VAE+text_projection | 2026-03 |

See `states/data/video_ai.yaml` header comments for full rejection details.

## CLI Usage

```bash
# Text-to-video (default model)
gen-video "ocean waves at golden hour"

# Specific model
gen-video -m hunyuanvideo-15 "cyberpunk city in rain"

# Image-to-video
gen-video -i ~/pic/reference.png "animate this scene"

# Higher resolution
gen-video -r 720p "forest landscape with mist"

# H.264 output for sharing
gen-video --compat "sunset timelapse"

# List installed models
gen-video --list

# Dry run (show what would execute)
gen-video --dry-run "test prompt"
```

## Output

- Videos saved to `/mnt/one/video-ai/output/`
- Format: MP4 with H.265/HEVC encoding (hardware-accelerated via VAAPI)
- Use `--compat` flag for H.264 when sharing to browsers/Telegram desktop

## Troubleshooting

### ComfyUI fails to start

Check that ROCm is functional:

```bash
/mnt/one/video-ai/comfyui/venv/bin/python -c "import torch; print(torch.cuda.is_available())"
```

If False, ensure ROCm packages are installed and the GPU is detected:

```bash
rocminfo | grep gfx
```

### Out of VRAM

- Use Wan2.1 14B Q5 (11 GB) instead of LTX-2.3 (22 GB)
- Reduce resolution: `-r 480p` instead of 720p
- Ensure Ollama and other GPU services are stopped before generation
- ComfyUI `--lowvram` offloads to RAM but is slower

### VAAPI encoding fails

Falls back to software encoding automatically. To check VAAPI support:

```bash
vainfo 2>&1 | grep -i hevc
```

## Architecture

- **Salt state**: `states/video_ai.sls` — declarative model management
- **Data file**: `states/data/video_ai.yaml` — model registry
- **Bootstrap**: `states/scripts/video-ai-setup.sh` — ComfyUI + ROCm venv
- **Generation**: `/mnt/one/video-ai/generate.sh` — ComfyUI API runner
- **CLI wrapper**: `~/.local/bin/gen-video` — user-facing command
- **Workflows**: `/mnt/one/video-ai/workflows/*.json` — ComfyUI API workflows
- **Models**: `/mnt/one/video-ai/models/<model-id>/` — downloaded checkpoints
- **Output**: `/mnt/one/video-ai/output/` — generated MP4 videos
