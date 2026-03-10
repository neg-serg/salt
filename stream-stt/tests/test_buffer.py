"""Tests for RingBuffer."""

import numpy as np
from stream_stt.buffer import RingBuffer


class TestRingBuffer:
    def test_empty_buffer(self):
        buf = RingBuffer(max_seconds=1.0, sample_rate=16000)
        assert buf.available == 0
        result = buf.read_last(100)
        assert len(result) == 0

    def test_simple_write_read(self):
        buf = RingBuffer(max_seconds=1.0, sample_rate=100)
        data = np.arange(50, dtype=np.float32)
        buf.write(data)
        assert buf.available == 50
        result = buf.read_last(50)
        np.testing.assert_array_equal(result, data)

    def test_read_last_partial(self):
        buf = RingBuffer(max_seconds=1.0, sample_rate=100)
        data = np.arange(50, dtype=np.float32)
        buf.write(data)
        result = buf.read_last(20)
        np.testing.assert_array_equal(result, data[30:])

    def test_read_more_than_available(self):
        buf = RingBuffer(max_seconds=1.0, sample_rate=100)
        data = np.arange(30, dtype=np.float32)
        buf.write(data)
        result = buf.read_last(100)
        np.testing.assert_array_equal(result, data)

    def test_wrap_around(self):
        buf = RingBuffer(max_seconds=0.1, sample_rate=100)  # 10 samples max
        # Write 7 samples
        buf.write(np.arange(7, dtype=np.float32))
        # Write 5 more — wraps around
        buf.write(np.arange(100, 105, dtype=np.float32))
        assert buf.available == 10
        result = buf.read_last(10)
        expected = np.array([2, 3, 4, 5, 6, 100, 101, 102, 103, 104], dtype=np.float32)
        np.testing.assert_array_equal(result, expected)

    def test_overflow_keeps_tail(self):
        buf = RingBuffer(max_seconds=0.1, sample_rate=100)  # 10 samples max
        big_data = np.arange(25, dtype=np.float32)
        buf.write(big_data)
        assert buf.available == 10
        result = buf.read_last(10)
        np.testing.assert_array_equal(result, big_data[-10:])

    def test_multiple_small_writes(self):
        buf = RingBuffer(max_seconds=1.0, sample_rate=100)
        for i in range(10):
            buf.write(np.array([float(i)], dtype=np.float32))
        assert buf.available == 10
        result = buf.read_last(10)
        expected = np.arange(10, dtype=np.float32)
        np.testing.assert_array_equal(result, expected)

    def test_clear(self):
        buf = RingBuffer(max_seconds=1.0, sample_rate=100)
        buf.write(np.arange(50, dtype=np.float32))
        buf.clear()
        assert buf.available == 0
        assert len(buf.read_last(10)) == 0

    def test_empty_write(self):
        buf = RingBuffer(max_seconds=1.0, sample_rate=100)
        buf.write(np.array([], dtype=np.float32))
        assert buf.available == 0

    def test_sliding_window_overlap(self):
        """Simulate the sliding window pattern from stream.cpp."""
        buf = RingBuffer(max_seconds=1.0, sample_rate=100)
        # Simulate 3 steps of 30 samples each
        for step in range(3):
            chunk = np.full(30, step + 1, dtype=np.float32)
            buf.write(chunk)

        # Read window of 50 samples (overlaps previous steps)
        window = buf.read_last(50)
        assert len(window) == 50
        # Should contain tail of step 2 and all of step 3
        assert window[-1] == 3.0
        assert window[0] == 2.0
