"""Ring buffer for sliding window audio capture."""

import numpy as np


class RingBuffer:
    """Fixed-size ring buffer for float32 PCM audio samples.

    Stores up to `max_seconds` of audio at given sample rate.
    Supports extracting the latest N samples as a contiguous array.
    """

    def __init__(self, max_seconds: float = 30.0, sample_rate: int = 16000):
        self.sample_rate = sample_rate
        self.max_samples = int(max_seconds * sample_rate)
        self._buf = np.zeros(self.max_samples, dtype=np.float32)
        self._write_pos = 0
        self._total_written = 0

    @property
    def available(self) -> int:
        """Number of valid samples currently in the buffer."""
        return min(self._total_written, self.max_samples)

    def write(self, data: np.ndarray) -> None:
        """Append float32 samples to the ring buffer."""
        n = len(data)
        if n == 0:
            return

        if n >= self.max_samples:
            # Data larger than buffer — keep only the tail
            self._buf[:] = data[-self.max_samples :]
            self._write_pos = 0
            self._total_written += n
            return

        end = self._write_pos + n
        if end <= self.max_samples:
            self._buf[self._write_pos : end] = data
        else:
            first = self.max_samples - self._write_pos
            self._buf[self._write_pos :] = data[:first]
            self._buf[: n - first] = data[first:]

        self._write_pos = end % self.max_samples
        self._total_written += n

    def read_last(self, n_samples: int) -> np.ndarray:
        """Return the last n_samples as a contiguous float32 array.

        If fewer samples are available, returns all available samples.
        """
        avail = self.available
        n = min(n_samples, avail)
        if n == 0:
            return np.zeros(0, dtype=np.float32)

        start = (self._write_pos - n) % self.max_samples
        if start + n <= self.max_samples:
            return self._buf[start : start + n].copy()
        else:
            first = self.max_samples - start
            return np.concatenate([self._buf[start:], self._buf[: n - first]])

    def clear(self) -> None:
        """Reset the buffer."""
        self._write_pos = 0
        self._total_written = 0
