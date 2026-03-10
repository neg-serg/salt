"""Streaming pipeline: capture → buffer → inference → output.

Ported from whisper.cpp stream.cpp sliding window approach.
"""

import sys
import time
from typing import Optional

import numpy as np

from .audio import SAMPLE_RATE, PwRecordCapture
from .buffer import RingBuffer
from .output import OutputFormatter, TranscriptionResult, create_formatter
from .vad import energy_vad
from .whisper_binding import WhisperContext, suppress_whisper_logs


class StreamingPipeline:
    """Main streaming STT pipeline.

    Architecture:
    - Thread 1: pw-record (source 1) → ring buffer 1
    - Thread 2: pw-record (source 2) → ring buffer 2 (optional)
    - Main thread: inference loop (sliding window → whisper_full → output)
    """

    def __init__(
        self,
        model_path: Optional[str] = None,
        language: str = "auto",
        source: Optional[str] = None,
        source2: Optional[str] = None,
        label: str = "mic",
        label2: str = "app",
        step_ms: int = 3000,
        length_ms: int = 10000,
        vad_threshold: float = 0.6,
        no_partial: bool = False,
        output_format: str = "text",
        verbose: bool = False,
    ):
        self.model_path = model_path
        self.language = language
        self.source = source
        self.source2 = source2
        self.label = label
        self.label2 = label2
        self.step_ms = step_ms
        self.length_ms = length_ms
        self.keep_ms = 200  # overlap from previous step
        self.vad_threshold = vad_threshold
        self.no_partial = no_partial
        self.output_format = output_format
        self.verbose = verbose

        self._running = False
        self._whisper: Optional[WhisperContext] = None
        self._captures: list[PwRecordCapture] = []
        self._buffers: list[RingBuffer] = []
        self._labels: list[str] = []
        self._formatter: Optional[OutputFormatter] = None
        self._start_time: float = 0.0
        self._prev_samples: dict[str, np.ndarray] = {}

    def _log(self, msg: str) -> None:
        """Print debug/status message to stderr."""
        print(msg, file=sys.stderr, flush=True)

    def _debug(self, msg: str) -> None:
        """Print verbose debug message to stderr."""
        if self.verbose:
            print(f"[debug] {msg}", file=sys.stderr, flush=True)

    def run(self) -> None:
        """Run the streaming pipeline until stopped."""
        self._start_time = time.monotonic()

        # Suppress ggml logs unless verbose
        if not self.verbose:
            suppress_whisper_logs()

        # Load whisper model
        self._log(f"Loading model: {self.model_path or '(auto-detect)'}")
        t0 = time.monotonic()
        self._whisper = WhisperContext(model_path=self.model_path)
        load_time = time.monotonic() - t0
        self._log(f"Model loaded ({load_time:.1f}s)")

        # Setup captures
        dual = self.source2 is not None
        self._formatter = create_formatter(
            fmt=self.output_format,
            dual_source=dual,
            no_partial=self.no_partial,
        )

        # Primary source
        buf1 = RingBuffer(max_seconds=30.0, sample_rate=SAMPLE_RATE)
        cap1 = PwRecordCapture(buf1, target=self.source, label=self.label)
        self._buffers.append(buf1)
        self._captures.append(cap1)
        self._labels.append(self.label)

        # Secondary source (optional)
        if dual:
            buf2 = RingBuffer(max_seconds=30.0, sample_rate=SAMPLE_RATE)
            cap2 = PwRecordCapture(buf2, target=self.source2, label=self.label2)
            self._buffers.append(buf2)
            self._captures.append(cap2)
            self._labels.append(self.label2)

        # Start captures
        for cap in self._captures:
            cap.start()
            src = cap.target or "default"
            self._log(f"Capturing from: {src} [{cap.label}] ({SAMPLE_RATE} Hz)")

        self._running = True

        try:
            self._inference_loop()
        finally:
            self.stop()

    def _inference_loop(self) -> None:
        """Main inference loop: sliding window approach."""
        n_samples_step = int(self.step_ms * SAMPLE_RATE / 1000)
        n_samples_len = int(self.length_ms * SAMPLE_RATE / 1000)
        n_samples_keep = int(self.keep_ms * SAMPLE_RATE / 1000)

        n_iter = 0

        while self._running:
            # Wait for enough audio
            time.sleep(self.step_ms / 1000.0)

            if not self._running:
                break

            # Process each source
            for i, (buf, label) in enumerate(zip(self._buffers, self._labels)):
                # Check capture health
                if not self._captures[i].is_running:
                    err = self._captures[i].error
                    if err:
                        self._log(f"Capture [{label}] error: {err}")
                    continue

                avail = buf.available
                if avail < n_samples_step:
                    self._debug(f"[{label}] not enough audio: {avail}/{n_samples_step}")
                    continue

                # Get current window
                pcm_new = buf.read_last(n_samples_step)

                # Quick energy VAD check to skip silence
                if not energy_vad(pcm_new, SAMPLE_RATE, threshold=self.vad_threshold):
                    self._debug(f"[{label}] VAD: silence")
                    # Clear any partial state
                    continue

                self._debug(f"[{label}] VAD: speech detected")

                # Build sliding window with overlap
                prev = self._prev_samples.get(label, np.zeros(0, dtype=np.float32))
                n_take = min(len(prev), max(0, n_samples_keep + n_samples_len - len(pcm_new)))
                if n_take > 0:
                    pcm = np.concatenate([prev[-n_take:], pcm_new])
                else:
                    pcm = pcm_new

                # Save for next iteration overlap
                self._prev_samples[label] = pcm

                # Run inference
                t_inf = time.monotonic()
                try:
                    segments = self._whisper.transcribe(
                        pcm,
                        language=self.language,
                        no_context=True,
                        single_segment=True,
                        use_vad=False,  # We do VAD ourselves
                    )
                except RuntimeError as e:
                    self._log(f"Inference error: {e}")
                    continue

                inf_ms = (time.monotonic() - t_inf) * 1000
                self._debug(f"[{label}] inference: {inf_ms:.0f}ms, {len(segments)} segments")

                ts = time.monotonic() - self._start_time

                # Emit results
                for seg in segments:
                    if not seg["text"]:
                        continue
                    result = TranscriptionResult(
                        text=seg["text"],
                        result_type="final",
                        source_label=label,
                        lang=seg.get("lang", "unknown"),
                        timestamp=ts,
                    )
                    self._formatter.emit(result)

            n_iter += 1

    def stop(self) -> None:
        """Stop the pipeline gracefully."""
        self._running = False
        for cap in self._captures:
            cap.stop()

        duration = time.monotonic() - self._start_time if self._start_time else 0
        mins = int(duration // 60)
        secs = int(duration % 60)
        self._log(f"Stopped. Duration: {mins}m {secs}s")

        if self._whisper:
            self._whisper.close()
            self._whisper = None
