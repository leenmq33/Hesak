# Tests for hesak/audio.py  (were: notebook Cell 2 TEST 1–5 and Cell 4 TEST 1–3)
import numpy as np
import pytest

from hesak.config import SR, BROWSER_CHUNK
from hesak.audio import (SharedRingBuffer, BufferReader, MicInput, decode_browser_chunk,
                         encode_like_browser, encode_pcm16)

# Test data: each sample's value = its own number, so any mix-up is easy to spot.
SRC = np.arange(BROWSER_CHUNK * 40, dtype=np.float32)


def filled_ring():
    r = SharedRingBuffer(capacity_seconds=5.0)
    a, b, slow = BufferReader(r, "a", 0), BufferReader(r, "b", 0), BufferReader(r, "slow", 0)
    got_a, got_b = [], []
    for i in range(40):
        r.write(SRC[i * BROWSER_CHUNK:(i + 1) * BROWSER_CHUNK])
        got_a.append(a.read_new()[1])
        if i % 3 == 2 or i == 39:
            got_b.append(b.read_new()[1])
    return r, a, slow, got_a, got_b


def test_two_readers_get_the_same_full_stream():                 # Cell 2 TEST 1
    _, _, _, got_a, got_b = filled_ring()
    assert np.array_equal(np.concatenate(got_a), SRC)
    assert np.array_equal(np.concatenate(got_b), SRC)


def test_random_access_last_second():                             # Cell 2 TEST 2
    r = filled_ring()[0]
    t = r.total_written
    assert np.array_equal(r.read(t - SR, t), SRC[t - SR:t])


def test_overwritten_audio_is_refused():                          # Cell 2 TEST 3
    r = filled_ring()[0]
    with pytest.raises(ValueError):
        r.read(0, 100)


def test_slow_reader_is_told_what_it_missed():                    # Cell 2 TEST 4
    _, _, slow, _, _ = filled_ring()
    s, x, dropped = slow.read_new()
    assert dropped == 83840
    assert np.array_equal(x, SRC[s:])


def test_reader_follows_a_reset():                                # Cell 2 TEST 5
    r, a, _, _, _ = filled_ring()
    r.reset()
    r.write(SRC[:BROWSER_CHUNK])
    s, x, _ = a.read_new()
    assert s == 0 and np.array_equal(x, SRC[:BROWSER_CHUNK])


def test_pcm16_round_trip():                                      # Cell 4 TEST 1
    x = np.random.default_rng(0).uniform(-1, 1, BROWSER_CHUNK)
    y = decode_browser_chunk(encode_like_browser(x), SR)
    assert len(y) == BROWSER_CHUNK
    assert np.max(np.abs(y - x)) < 1e-4


def test_48khz_is_converted_to_16khz():                           # Cell 4 TEST 2
    y = decode_browser_chunk(encode_like_browser(np.zeros(BROWSER_CHUNK * 3)), 48000)
    assert len(y) == BROWSER_CHUNK


def test_mic_writes_the_ring_base64_and_bytes():                  # Cell 4 TEST 3 (+ raw bytes, new)
    ring = SharedRingBuffer()
    mic = MicInput(ring)
    for _ in range(5):
        mic.write(encode_like_browser(np.zeros(BROWSER_CHUNK)), SR)
    for _ in range(5):
        mic.write_bytes(encode_pcm16(np.zeros(BROWSER_CHUNK)), SR)
    assert ring.total_written == 10 * BROWSER_CHUNK
    assert mic.errors == 0


def test_bad_chunk_is_counted_not_crashing():
    mic = MicInput(SharedRingBuffer())
    mic.write("not base64 !!!", SR)
    assert mic.errors == 1