"""PipeWire audio capture via pw-record subprocess."""

import subprocess
import threading
from dataclasses import dataclass
from typing import Optional

import numpy as np

from .buffer import RingBuffer

SAMPLE_RATE = 16000
SAMPLE_FORMAT = "f32"  # 32-bit float
CHANNELS = 1

_AUDIO_CLASSES = ("Audio/Source", "Audio/Sink", "Stream/Output/Audio")


@dataclass
class AudioSource:
    """A PipeWire audio source."""

    node_id: str
    name: str
    source_type: str  # "input" or "monitor"


def list_sources() -> list[AudioSource]:
    """List available PipeWire audio sources using pw-cli."""
    try:
        result = subprocess.run(
            ["pw-cli", "list-objects"],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except FileNotFoundError:
        raise RuntimeError("pw-cli not found. Is PipeWire installed?")

    sources = []
    current_id = None
    current_name = None
    current_class = None

    for line in result.stdout.splitlines():
        line = line.strip()
        if line.startswith("id "):
            # Save previous if valid
            if current_id and current_name and current_class in _AUDIO_CLASSES:
                stype = "input" if current_class == "Audio/Source" else "monitor"
                sources.append(AudioSource(current_id, current_name, stype))
            # Parse new object
            parts = line.split(",")
            current_id = parts[0].split()[-1] if parts else None
            current_name = None
            current_class = None
        elif "node.name" in line and "=" in line:
            current_name = line.split("=", 1)[1].strip().strip('"')
        elif "media.class" in line and "=" in line:
            current_class = line.split("=", 1)[1].strip().strip('"')

    # Don't forget last
    if current_id and current_name and current_class in _AUDIO_CLASSES:
        stype = "input" if current_class == "Audio/Source" else "monitor"
        sources.append(AudioSource(current_id, current_name, stype))

    return sources


def format_sources_table(sources: list[AudioSource]) -> str:
    """Format sources as a table for --list-sources output."""
    lines = [f"{'ID':<6}{'Name':<42}{'Type'}"]
    for s in sources:
        lines.append(f"{s.node_id:<6}{s.name:<42}{s.source_type}")
    return "\n".join(lines)


class PwRecordCapture:
    """Captures audio from PipeWire via pw-record subprocess.

    Reads raw f32 PCM from pw-record stdout into a RingBuffer.
    """

    def __init__(
        self,
        ring_buffer: RingBuffer,
        target: Optional[str] = None,
        label: str = "mic",
    ):
        self.ring_buffer = ring_buffer
        self.target = target
        self.label = label
        self._process: Optional[subprocess.Popen] = None
        self._thread: Optional[threading.Thread] = None
        self._running = False
        self._error: Optional[str] = None

    def start(self) -> None:
        """Start pw-record subprocess and reader thread."""
        cmd = [
            "pw-record",
            "--rate",
            str(SAMPLE_RATE),
            "--channels",
            str(CHANNELS),
            "--format",
            SAMPLE_FORMAT,
        ]
        if self.target:
            cmd.extend(["--target", self.target])
        cmd.append("-")  # output to stdout

        try:
            self._process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except FileNotFoundError:
            raise RuntimeError("pw-record not found. Is PipeWire installed?")

        self._running = True
        self._thread = threading.Thread(
            target=self._reader_loop,
            name=f"pw-record-{self.label}",
            daemon=True,
        )
        self._thread.start()

    def _reader_loop(self) -> None:
        """Read raw f32 PCM from pw-record stdout into ring buffer."""
        assert self._process and self._process.stdout
        chunk_samples = 1600  # 100ms at 16kHz
        chunk_bytes = chunk_samples * 4  # f32 = 4 bytes

        try:
            while self._running:
                data = self._process.stdout.read(chunk_bytes)
                if not data:
                    break
                # Convert raw bytes to float32 numpy array
                n_samples = len(data) // 4
                if n_samples > 0:
                    samples = np.frombuffer(data[: n_samples * 4], dtype=np.float32)
                    self.ring_buffer.write(samples)
        except Exception as e:
            self._error = str(e)

    def stop(self) -> None:
        """Stop the capture."""
        self._running = False
        if self._process:
            try:
                self._process.terminate()
                self._process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self._process.kill()
                self._process.wait()
            self._process = None
        if self._thread:
            self._thread.join(timeout=2)
            self._thread = None

    @property
    def error(self) -> Optional[str]:
        return self._error

    @property
    def is_running(self) -> bool:
        if self._process is None:
            return False
        return self._process.poll() is None and self._running
