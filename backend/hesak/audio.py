# ============================================================
# HESAK backend — audio.py : the shared ring buffer + microphone input  (was: notebook Cells 2 + 4)
# ------------------------------------------------------------
#   phone / page audio (PCM16) → MicInput → SharedRingBuffer → every path reads with its OWN cursor
# All positions are ABSOLUTE sample numbers since the last reset.
# ============================================================
import base64
import threading
import time
from math import gcd

import numpy as np

from .config import SR, RING_SECONDS

try:
    from scipy.signal import resample_poly as _resample_poly
except ImportError:                                  # works without SciPy (lower quality)
    _resample_poly = None


# A circular tape that holds the last 30 s of audio. When full, it writes over the oldest part.
# ONE writer (the mic). MANY readers, each with its own cursor — reading never removes audio.
class SharedRingBuffer:
    def __init__(self, capacity_seconds=RING_SECONDS, sample_rate=SR):
        self.sample_rate = sample_rate
        self.capacity = int(capacity_seconds * sample_rate)    # 30 s × 16000 = 480,000
        self._buf = np.zeros(self.capacity, dtype=np.float32)
        self._lock = threading.Lock()                          # no half-written reads
        self.total_written = 0      # absolute index of the next sample
        self.generation = 0         # +1 on every reset (= session number)

    # The oldest sample still in the tape (anything before it was overwritten).
    @property
    def oldest_index(self):
        return max(0, self.total_written - self.capacity)

    # Called ONLY by the microphone. Writes at the end and wraps around.
    def write(self, samples):
        samples = np.asarray(samples, dtype=np.float32).ravel()
        n = len(samples)
        if n == 0:
            return
        skip = max(0, n - self.capacity)                       # > 30 s at once → keep the last 30 s
        samples = samples[skip:]
        m = len(samples)
        with self._lock:
            pos = (self.total_written + skip) % self.capacity
            first = min(m, self.capacity - pos)
            self._buf[pos:pos + first] = samples[:first]
            if first < m:
                self._buf[:m - first] = samples[first:]
            self.total_written += n

    # Copy a range out; if it wraps past the end, copy it in two pieces.
    def _copy(self, start, end):
        m = end - start
        out = np.empty(m, dtype=np.float32)
        if m <= 0:
            return out[:0]
        pos = start % self.capacity
        first = min(m, self.capacity - pos)
        out[:first] = self._buf[pos:pos + first]
        if first < m:
            out[first:] = self._buf[:m - first]
        return out

    # Cut an exact clip by sample numbers (used to build Whisper requests).
    def read(self, start, end):
        with self._lock:
            if start > end:
                raise ValueError(f"start {start} > end {end}")
            if start < self.oldest_index:
                # Refuse rather than return the wrong audio (wrong audio is worse than none).
                raise ValueError(f"samples {start}..{self.oldest_index} already overwritten")
            if end > self.total_written:
                raise ValueError(f"end {end} > written {self.total_written}")
            return self._copy(start, end)

    # Streaming read for a path: 'give me everything new since my cursor'.
    def read_from(self, cursor, reader_generation, max_samples=None):
        with self._lock:
            if reader_generation != self.generation:           # new session → start from 0
                cursor = 0
            dropped = 0
            if cursor < self.oldest_index:                     # fell > 30 s behind → skip ahead
                dropped = self.oldest_index - cursor
                cursor = self.oldest_index
            end = self.total_written
            if max_samples is not None:
                end = min(end, cursor + max_samples)
            return cursor, self._copy(cursor, end), dropped, self.generation

    # New session: clear the tape, clock back to 0, session number +1.
    def reset(self):
        with self._lock:
            self._buf.fill(0.0)
            self.total_written = 0
            self.generation += 1


# One reader per path. It remembers where it stopped reading.
class BufferReader:
    def __init__(self, ring_buffer, name, start_at=None):
        self.ring = ring_buffer
        self.name = name
        self._gen = ring_buffer.generation
        self.cursor = ring_buffer.total_written if start_at is None else int(start_at)
        self.dropped_total = 0

    # Returns (start sample, new audio, how many samples were missed).
    def read_new(self, max_samples=None):
        start, audio, dropped, gen = self.ring.read_from(self.cursor, self._gen, max_samples)
        self._gen = gen
        self.cursor = start + len(audio)
        self.dropped_total += dropped
        return start, audio, dropped


# ---- Decoding ----
# Raw PCM16 bytes (little-endian, what the phone's `record` package sends) → float32 at 16 kHz.
def decode_pcm16(data, sample_rate):
    sample_rate = int(sample_rate)
    audio = np.frombuffer(data, dtype="<i2").astype(np.float32) / 32768.0
    if sample_rate == SR:
        return audio
    if _resample_poly is not None:                                 # good quality (filters first)
        g = gcd(SR, sample_rate)
        return _resample_poly(audio, SR // g, sample_rate // g).astype(np.float32)
    n_out = int(round(len(audio) * SR / sample_rate))               # fallback: linear
    return np.interp(np.linspace(0, len(audio) - 1, n_out), np.arange(len(audio)), audio).astype(np.float32)


# Base64 text holding PCM16 (what the Colab test page sends) → float32 at 16 kHz.
def decode_browser_chunk(base64_audio, sample_rate):
    return decode_pcm16(base64.b64decode(base64_audio), sample_rate)


# TESTS ONLY: does exactly what the page / phone does, so we can test without a microphone.
def encode_pcm16(float_samples):
    s = np.clip(np.asarray(float_samples, dtype=np.float64), -1.0, 1.0)
    s = np.where(s < 0, s * 0x8000, s * 0x7FFF)
    return np.trunc(s).astype("<i2").tobytes()


def encode_like_browser(float_samples):
    return base64.b64encode(encode_pcm16(float_samples)).decode("ascii")


# The ONLY writer of the ring. Never crashes: a bad chunk is counted and skipped.
class MicInput:
    def __init__(self, ring_buffer):
        self.ring = ring_buffer
        self.reset_stats()

    def reset_stats(self):
        self.chunks = 0
        self.rate_in = None
        self.last_chunk_wall = 0.0      # no chunk for > 1 s → the mic is shown as stopped
        self.errors = 0
        self.last_error = None

    def _write(self, decode, data, sample_rate):
        try:
            self.ring.write(decode(data, sample_rate))
            self.chunks += 1
            self.rate_in = int(sample_rate)
            self.last_chunk_wall = time.time()
        except Exception as e:
            self.errors += 1
            self.last_error = repr(e)

    # Base64 text (test page / JSON API).
    def write(self, base64_audio, sample_rate):
        self._write(decode_browser_chunk, base64_audio, sample_rate)

    # Raw bytes (phone over WebSocket — no Base64, 25% less data).
    def write_bytes(self, pcm16_bytes, sample_rate):
        self._write(decode_pcm16, pcm16_bytes, sample_rate)