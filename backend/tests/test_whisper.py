# Tests for hesak/whisper_stt.py — all with FakeWhisper (no model, no GPU)
# (were: notebook Cell 12 TEST 1–8 and Cell 14 TEST 11–16, 18–20)
import threading
import time

import numpy as np

from hesak.config import SR, BROWSER_CHUNK, STT_PRE_PAD_S
from hesak.audio import encode_like_browser
from hesak.events import EventBus, Handoff
from hesak.api import HesakAPI
from hesak.controller import build_system
from hesak.listening import EnergyTestVAD
from hesak.whisper_stt import FakeWhisper, WhisperWorker, FasterWhisperBackend, normalize_level
from sounds import room, place, speechlike, run_conv

TWO = place(place(room(12.0), speechlike(2.0), 2.0), speechlike(3.0), 6.0)


def ok(text):
    return {"text": text, "avg_logprob": -0.2, "no_speech_prob": 0.05}


def run_whisper(signal, backend):
    _, stt, inbox, _, _ = run_conv(signal, EnergyTestVAD)
    bus = EventBus()
    w = WhisperWorker(inbox, bus, lambda: backend)
    w.drain()
    return w, stt, [e for e in bus.get_since(0)[0] if e["type"] == "transcript"]


def request(i, cid=1, seconds=1):
    return {"id": i, "conversation_id": cid, "session": 1, "reason": "silence", "speech_start": 0,
            "speech_end": SR, "audio": np.zeros(SR * seconds, dtype=np.float32), "created_at": time.time()}


def wait_for(cond, timeout=5.0):
    t0 = time.time()
    while not cond() and time.time() - t0 < timeout:
        time.sleep(0.02)
    return cond()


# ---------- Cell 12 ----------
def test_one_transcript_per_sentence_in_order():                          # TEST 1
    _, stt, tr = run_whisper(TWO, FakeWhisper())
    assert [e["label"] for e in tr] == ["ok", "ok"]
    assert [e["details"]["request_id"] for e in tr] == [e["details"]["request_id"] for e in stt]


def test_transcript_times_are_the_speech_times():                         # TEST 2
    _, stt, tr = run_whisper(TWO, FakeWhisper())
    assert all(abs(t["start_s"] - (s["start_s"] + STT_PRE_PAD_S)) < 0.02 for t, s in zip(tr, stt))


def test_context_goes_to_the_next_sentence():                             # TEST 3
    fw = FakeWhisper()
    run_whisper(TWO, fw)
    assert [p for _, p in fw.calls] == [None, "<2.6s>"]


def test_filters_and_filtered_text_is_never_context():                    # TEST 4
    fw = FakeWhisper(script=[ok("اشتركوا في القناة"), {"text": "ممم", "avg_logprob": -1.5, "no_speech_prob": 0.9},
                             ok("  "), ok("السلام عليكم")])
    four = place(place(place(place(room(20.0), speechlike(1.5), 2.0), speechlike(1.5), 6.0),
                       speechlike(1.5), 10.0), speechlike(1.5), 14.0)
    _, _, tr = run_whisper(four, fw)
    assert [e["label"] for e in tr] == ["hallucination", "no_speech", "empty", "ok"]
    assert fw.calls[-1][1] is None


def test_a_crash_on_one_sentence_does_not_stop_the_next():                # TEST 5
    w, _, tr = run_whisper(TWO, FakeWhisper(script=[RuntimeError("model crashed"), ok("تمام")]))
    assert [e["label"] for e in tr] == ["error", "ok"] and w.stats["errors"] == 1


def test_conversations_do_not_share_context():                            # TEST 6
    fw, box = FakeWhisper(), Handoff("w", maxsize=10)
    for i, cid in enumerate([1, 2, 1]):
        box.put(request(i + 1, cid, i + 1))
    WhisperWorker(box, EventBus(), lambda: fw).drain()
    assert [p for _, p in fw.calls] == [None, None, "<1.0s>"]


def test_threaded_in_order_and_stops_cleanly():                           # TEST 7 + TEST 8
    before = {t.name for t in threading.enumerate()}
    bus, box = EventBus(), Handoff("w", maxsize=10)
    w = WhisperWorker(box, bus, lambda: FakeWhisper(delay_s=0.05))
    w.start()
    for i in range(5):
        box.put(request(i + 1))
        time.sleep(0.02)
    assert wait_for(lambda: w.stats["done"] == 5)
    w.stop()
    assert [e["details"]["request_id"] for e in bus.get_since(0)[0]] == [1, 2, 3, 4, 5]
    assert not [t for t in threading.enumerate() if t.name == "hesak-whisper" and t.name not in before]
    ev = HesakAPI._event(bus.get_since(0)[0][-1])
    assert ev["channel"] == "conversation" and ev["code"] == "ok" and ev["data"]["text"] == "<1.0s>"


# ---------- Cell 14 ----------
def feed_paced(ctl, signal, speed=4.0):
    for i in range(0, len(signal), BROWSER_CHUNK):
        ctl.on_audio(encode_like_browser(signal[i:i + BROWSER_CHUNK]), SR)
        time.sleep(BROWSER_CHUNK / SR / speed)


def test_live_words_then_final_text_then_clean_shutdown():               # TEST 11, 12, 13
    before = {t.name for t in threading.enumerate()}
    fw = FakeWhisper(delay_s=0.03)
    ctl = build_system(EnergyTestVAD, threaded=False, whisper_factory=lambda: fw, partials=True)
    ctl.env_start()
    ctl.conv_start()
    mark = ctl.bus.last_id
    feed_paced(ctl, place(room(9.0), speechlike(4.0), 4.0))
    assert wait_for(lambda: ctl.whisper.stats["done"] >= 1)
    ev = ctl.bus.get_since(mark)[0]
    parts = [e for e in ev if e["type"] == "transcript_partial"]
    fin = [e for e in ev if e["type"] == "transcript"]
    assert len(parts) >= 2 and len(fin) == 1 and parts[0]["start_s"] == fin[0]["start_s"]
    assert not [p for p in parts if p["id"] > fin[0]["id"] and p["start_s"] == fin[0]["start_s"]]

    d = HesakAPI(ctl).handle({"cmd": "sync", "args": {"since": mark}})["data"]          # TEST 12
    assert {"transcript", "transcript_partial"} <= {e["type"] for e in d["events"] if e["channel"] == "conversation"}
    assert d["status"]["pipeline"]["whisper_on"] and d["status"]["pipeline"]["whisper_done"] == 1

    ctl.conv_start()                                                                    # TEST 13
    feed_paced(ctl, place(room(3.0), speechlike(3.0), 1.0)[: int(2.5 * SR)])
    done0 = ctl.whisper.stats["done"]
    ctl.env_stop()
    assert wait_for(lambda: ctl.whisper.stats["done"] > done0)        # the cut sentence still gets its text
    ctl.shutdown()
    assert not [t for t in threading.enumerate() if t.name.startswith("hesak-") and t.name not in before]

def live_words(guesses):
    fw = FakeWhisper(script=[ok(t) for t in guesses])
    bus = EventBus()
    w = WhisperWorker(Handoff("t", maxsize=5), bus, lambda: fw)
    w.load()
    for _ in guesses:
        w.handle_partial(dict(request(1), key=(1, 1, 0)))
    return [e["details"]["confirmed"] for e in bus.get_since(0)[0]]


def test_live_words_only_grow_and_never_change():                         # TEST 16 (append-only)
    shown = live_words(("السلام", "السلام عليكم", "السلام عليكم كيف",
                        "السلام عليكن كيف حالك", "السلام عليكم كيف حالك"))
    # a word appears as soon as the next word has started, and is never changed afterwards
    assert shown == ["", "السلام", "السلام عليكم", "السلام عليكم كيف", "السلام عليكم كيف"]
    for before, after in zip(shown, shown[1:]):
        assert after.startswith(before)              # only grows ("عليكن" in guess 4 did not change it)


def test_live_words_survive_a_joined_or_split_name():
    shown = live_words(("أنا عبد", "أنا عبدالله محمد", "أنا عبد الله محمد علي", "أنا عبد الله محمد علي عبد"))
    assert shown[-1] == "أنا عبدالله محمد علي"           # no repeated "الله", nothing removed

def test_invented_phrases_are_cut_out():                                  # TEST 18
    assert WhisperWorker._check(ok("وين المفتاح؟ اشتركوا في القناة")) == ("ok", "وين المفتاح؟")
    assert WhisperWorker._check(ok("[موسيقى]")) == ("hallucination", "")


class Seg:
    def __init__(self, text, lp, ns, cr=1.5, start=0.0, end=1.0):
        self.text, self.avg_logprob, self.no_speech_prob, self.compression_ratio = text, lp, ns, cr
        self.start, self.end = start, end


class FakeModel:
    def __init__(self, segs):
        self.segs = segs

    def transcribe(self, audio, **kw):
        return iter(self.segs), None


def test_only_the_doubtful_part_is_dropped():                             # TEST 19
    b = FasterWhisperBackend.__new__(FasterWhisperBackend)                 # no real model needed
    b.language, b.beam = "ar", 1
    b.model = FakeModel([Seg("وين رحت أمس؟", -0.3, 0.05), Seg("ممم", -1.6, 0.9, start=1, end=2),
                         Seg("قلت لك قلت لك قلت لك قلت لك", -0.4, 0.1, cr=3.1, start=2, end=3)])
    r = b(np.zeros(SR, dtype=np.float32))
    assert r["text"] == "وين رحت أمس؟" and r["dropped_parts"] == 2


def test_quiet_audio_is_made_louder_but_never_clipped():                  # TEST 20
    q = normalize_level(np.full(SR, 0.01, dtype=np.float32))               # −40 dBFS
    assert abs(20 * np.log10(np.sqrt(np.mean(q ** 2))) - (-20.0)) < 0.1
    assert np.allclose(normalize_level(np.full(SR, 0.5, dtype=np.float32)), 0.5)
    assert np.max(np.abs(q)) <= 0.99