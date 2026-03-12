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
     - id: ltx-video-2b
       enabled: true  # fastest, AMD-tested
   ```

3. Apply:

   ```bash
   just apply video_ai
   ```

4. Generate video:

   ```bash
   gen-video "a cat walking on the moon at sunset"
   ```

## Available Models

| Model | VRAM | Speed (est.) | Quality | Modes |
|-------|------|-------------|---------|-------|
| LTX-Video 2B | 12 GB | ~1 min | Fair | t2v, i2v, v2v |
| HunyuanVideo 1.5 FP8 | 14 GB | ~5 min | Excellent | t2v, i2v |
| Wan2.1 14B Q5 | 11 GB | ~20 min | Very good | t2v |
| Wan2.1 1.3B | 8 GB | ~8 min | Decent | t2v |
| CogVideoX-5B | 16 GB | ~10 min | Fair | t2v, i2v |
| Wan2.1 I2V 14B Q5 | 11 GB | ~20 min | Very good | i2v |

Speed estimates assume AMD RX 7900 XTX with ROCm 6.4. Actual times vary by prompt complexity and resolution.

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

- Use a smaller model (LTX-Video 2B at 12GB is the lightest)
- Reduce resolution: `-r 480p` instead of 720p
- Ensure Ollama and other GPU services are stopped before generation

### Slow GGUF loading

Known issue with some ROCm versions. Try:

- Upgrading to latest ROCm 6.x
- Using non-GGUF models (LTX-Video 2B fp16, CogVideoX bf16)

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
