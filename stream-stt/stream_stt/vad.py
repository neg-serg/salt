"""VAD (Voice Activity Detection) configuration helpers.

Uses energy-based VAD as a Python-side pre-filter to avoid sending silence
to the GPU. whisper.cpp also has built-in Silero VAD which is used during
inference when available.
"""

import numpy as np


def energy_vad(
    samples: np.ndarray,
    sample_rate: int = 16000,
    window_ms: int = 1000,
    threshold: float = 0.6,
    freq_threshold: float = 100.0,
) -> bool:
    """Simple energy-based VAD check.

    Returns True if speech is likely present in the audio samples.
    Ported from whisper.cpp stream.cpp vad_simple().
    """
    if len(samples) == 0:
        return False

    n_window = int(sample_rate * window_ms / 1000)
    n_window = min(n_window, len(samples))

    # Use last n_window samples
    window = samples[-n_window:]

    # Compute energy
    energy = float(np.mean(np.abs(window)))

    # High-pass filter: check if significant energy above freq_threshold
    if freq_threshold > 0:
        # Simple spectral check using FFT
        fft = np.fft.rfft(window)
        freqs = np.fft.rfftfreq(len(window), 1.0 / sample_rate)
        # Energy above frequency threshold
        mask = freqs >= freq_threshold
        if mask.any():
            high_energy = float(np.mean(np.abs(fft[mask])))
            low_energy = float(np.mean(np.abs(fft[~mask]))) + 1e-10
            ratio = high_energy / (high_energy + low_energy)
        else:
            ratio = 0.0
    else:
        ratio = 1.0

    # Energy threshold (empirical: >0.0001 indicates non-silence)
    has_energy = energy > 0.0001

    return has_energy and ratio > (1.0 - threshold)
