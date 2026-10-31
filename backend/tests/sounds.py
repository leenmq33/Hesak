# Fake sounds + small runners used by the tests  (were: helpers in notebook Cells 5 + 6)
import numpy as np

from hesak.config import SR, BROWSER_CHUNK
from hesak.audio import SharedRingBuffer
from hesak.events import EventBus, Handoff
from hesak.listening import EnvironmentPath, ConversationPath

_rng = np.random.default_rng(5)


def room(sec, std=0.001):                      # quiet room ≈ -60 dBFS
    return (std * _rng.standard_normal(int(sec * SR))).astype(np.float32)


def knock(amp=0.3):                            # 3 sharp bursts, 0.3 s apart (0.7 s)
    y = np.zeros(int(0.7 * SR), dtype=np.float32)
    b = int(0.1 * SR)
    env = np.exp(-np.arange(b) / (0.015 * SR))
    for k in range(3):
        s = int(k * 0.3 * SR)
        y[s:s + b] += (amp * _rng.standard_normal(b) * env).astype(np.float32)
    return y


def beeping_alarm(sec, amp=0.2):               # 3.1 kHz, 0.2 s on / 0.2 s off
    t = np.arange(int(sec * SR)) / SR
    return (amp * np.sin(2 * np.pi * 3100 * t) * ((t % 0.4) < 0.2)).astype(np.float32)


def speechlike(sec, f0=160.0, amp=0.1):        # harmonic, syllable-modulated "voice"
    t = np.arange(int(sec * SR)) / SR
    x = sum(np.sin(2 * np.pi * f0 * k * t) / k for k in range(1, 8))
    return (amp * x / np.max(np.abs(x)) * (0.6 + 0.4 * np.sin(2 * np.pi * 4 * t))).astype(np.float32)


def place(base, ev, t0):
    out = base.copy()
    i = int(t0 * SR)
    out[i:i + len(ev)] += ev[:len(out) - i]
    return out


# Plays a fake sound through the Home path, step by step (no thread → same result every time).
def run_env(signal):
    tr, tb, th = SharedRingBuffer(capacity_seconds=60.0), EventBus(), Handoff("yamnet-test", maxsize=500)
    p = EnvironmentPath(tr, tb, th)
    p.start(threaded=False)
    for i in range(0, len(signal), BROWSER_CHUNK):
        tr.write(signal[i:i + BROWSER_CHUNK])
        p.step()
    p.stop()
    ev = tb.get_since(0)[0]
    return (p, [e for e in ev if e["type"] == "activity_ended"],
            [e for e in ev if e["type"] == "env_request"], th)


# Plays a fake sound through the WHOLE chain: ring → Gate → Silero → mailboxes.
def run_conv(signal, vad_factory, stop_at_end=True, conv_on=True):
    tr, tb = SharedRingBuffer(capacity_seconds=60.0), EventBus()
    yb, wb = Handoff("yamnet-test", maxsize=200), Handoff("whisper-test", maxsize=100)
    env = EnvironmentPath(tr, tb, yb)
    c = ConversationPath(tr, tb, wb, vad_factory)
    env.attach_conversation(c)
    env.start(threaded=False)
    if conv_on:
        c.start(conversation_id=1)
    for i in range(0, len(signal), BROWSER_CHUNK):
        tr.write(signal[i:i + BROWSER_CHUNK])
        env.step()
    if stop_at_end:
        c.stop()
    env.stop()
    evs = tb.get_since(0)[0]
    return (c, [e for e in evs if e["type"] == "stt_request"], wb, env,
            [e for e in evs if e["type"] == "env_request"])


def reasons(reqs):
    return [r["details"]["reason"] for r in reqs]