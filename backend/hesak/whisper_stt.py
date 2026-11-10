# ============================================================
# HESAK backend — whisper_stt.py : Whisper  (was: notebook Cells 12 + 13)
# ------------------------------------------------------------
#   whisper_inbox ──► WhisperWorker (ONE thread, in order)
#                       1. take the next finished sentence (or, when free, the newest live one)
#                       2. backend(audio) → text + confidence
#                       3. filter: empty / no speech / invented phrases
#                       4. publish "transcript" (final) or "transcript_partial" (live words)
#   Backends with the SAME interface  backend(audio, prompt=None, fast=False) → dict :
#       FakeWhisper (tests) · FasterWhisperBackend (one model) · DualWhisper (live model + final model)
# ============================================================
import collections
import glob
import os
import queue
import re
import sys
import threading
import time

import numpy as np

from .config import (SR, WHISPER_LANG, WHISPER_PROMPT_CHARS, WHISPER_USE_CONTEXT, WHISPER_STYLE_PROMPT,
                     WHISPER_LIVE_MODEL, WHISPER_FINAL_MODEL, WHISPER_GPU_BEAM, WHISPER_CPU_BEAM,
                     WHISPER_NO_SPEECH, WHISPER_MIN_LOGPROB, WHISPER_SEG_NO_SPEECH, WHISPER_SEG_MIN_LOGPROB,
                     WHISPER_SEG_MAX_COMPRESSION, WHISPER_TARGET_DBFS, WHISPER_MAX_GAIN_DB, HALLUCINATIONS)
# DIAGNOSIS (optional): set env HESAK_SAVE_AUDIO=/some/folder to keep every sentence as .wav + its text.
SAVE_AUDIO_DIR = os.environ.get("HESAK_SAVE_AUDIO")

# ============================================================
# Part 1 — the worker  (Cell 12)
# ============================================================
# TESTS ONLY: a fake Whisper with the same interface as the real one.
# By default it answers "<1.6s>" (the audio length). A script of answers can be given to test the filters.
class FakeWhisper:
    def __init__(self, script=None, delay_s=0.0):
        self.script = list(script or [])
        self.delay_s = delay_s
        self.calls = []                                   # (audio length s, prompt) of every call → tests read this

    def __call__(self, audio, prompt=None, fast=False):
        self.calls.append((round(len(audio) / SR, 2), prompt))
        if self.delay_s:
            time.sleep(self.delay_s)
        if self.script:
            r = self.script.pop(0)
            if isinstance(r, Exception):
                raise r
            return dict(r)
        return {"text": f"<{len(audio) / SR:.1f}s>", "avg_logprob": -0.1, "no_speech_prob": 0.0}


class WhisperWorker:
    """whisper_inbox → backend → "transcript" events (+ live "transcript_partial" words)."""

    def __init__(self, inbox, bus, backend_factory, partial_slot=None):
        self.inbox, self.bus, self.factory = inbox, bus, backend_factory
        self.partial_slot = partial_slot      # live requests (LatestSlot, events.py) or None
        # Sentences that already have their FINAL text → a late live request for them is skipped.
        self._finished = collections.deque(maxlen=100)
        # Live words of the sentence being spoken: {"key", "fixed" (words already on screen, never changed)}
        self._live = None
        self.backend = None
        # Context per conversation: conversation_id → recent text (used as the prompt of the next sentence).
        self._context = {}
        self._stop_event = threading.Event()
        self._thread = None
        self.busy = False                     # True while a sentence is being transcribed
        self.stats = self._new_stats()
        self.last_error = None

    @staticmethod
    def _new_stats():
        return {"done": 0, "filtered": 0, "errors": 0, "busy_s": 0.0, "audio_s": 0.0, "last_latency_s": None,
                "partials": 0, "partial_skipped": 0}

    # ---------- lifecycle ----------
    # Load the model ONCE, early (with the environment), so the first sentence is not slow.
    def load(self):
        if self.backend is None:
            self.backend = self.factory()

    def start(self):
        if self._thread is not None:
            return
        self.load()
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._run, name="hesak-whisper", daemon=True)
        self._thread.start()

    # Stop the thread. Sentences still waiting stay in the inbox (nothing is lost).
    def stop(self, timeout=5.0):
        self._stop_event.set()
        if self._thread is not None:
            self._thread.join(timeout)
            self._thread = None

    # The background loop. FINISHED sentences always come first (they are never skipped).
    # Only when no finished sentence is waiting, the newest LIVE request is transcribed.
    def _run(self):
        while not self._stop_event.is_set():
            try:
                req = self.inbox.get(timeout=0.05)
            except queue.Empty:
                p = self.partial_slot.take() if self.partial_slot is not None else None
                if p is not None:
                    if p["key"] in self._finished:
                        self.stats["partial_skipped"] += 1
                    else:
                        self.handle_partial(p)
                continue
            self.handle(req)

    # TESTS (no thread): handle everything that is waiting right now, in order. Returns how many.
    def drain(self):
        self.load()
        n = 0
        while True:
            try:
                req = self.inbox.q.get_nowait()
            except queue.Empty:
                return n
            self.handle(req)
            n += 1

    # ---------- main work: ONE sentence ----------
    def handle(self, req):
        cid = req["conversation_id"]
        audio = req["audio"]
        dur = len(audio) / SR
        self.busy = True
        t0 = time.perf_counter()
        try:
            r = self.backend(audio, self._context.get(cid))
            status, text = self._check(r)
        except Exception as e:                         # the model failed → report it, keep going with the next sentence
            self.stats["errors"] += 1
            self.last_error = repr(e)
            r, status, text = {"avg_logprob": None, "no_speech_prob": None}, "error", ""
        busy = time.perf_counter() - t0
        self.busy = False
        latency = time.time() - req["created_at"]
        self.stats["busy_s"] += busy
        self.stats["audio_s"] += dur
        self.stats["last_latency_s"] = round(latency, 2)

        self._finished.append((req["session"], cid, req["speech_start"]))
        if self._live is not None and self._live["key"] == (req["session"], cid, req["speech_start"]):
            self._live = None                          # the final text replaces the live words
        if status == "ok":
            self.stats["done"] += 1
            # Remember this text as context for the NEXT sentence of the same conversation.
            self._context[cid] = (self._context.get(cid, "") + " " + text).strip()[-WHISPER_PROMPT_CHARS:]
        elif status != "error":
            self.stats["filtered"] += 1

        if SAVE_AUDIO_DIR:
            self._save_audio(req, audio, status, text)






        # Times = where the SPEECH was (not the padded window), so the page lines it up with speech_started/ended.
        self.bus.publish("transcript", status, req["session"],
                         start_sample=req["speech_start"], end_sample=req["speech_end"],
                         details={"request_id": req["id"], "conversation_id": cid, "reason": req["reason"],
                                  "text": text,
                                  "avg_logprob": None if r["avg_logprob"] is None else round(r["avg_logprob"], 3),
                                  "no_speech_prob": None if r["no_speech_prob"] is None else round(r["no_speech_prob"], 3),
                                  "audio_s": round(dur, 2), "busy_s": round(busy, 3),
                                  "rtf": round(busy / max(dur, 1e-6), 3),   # < 1 = faster than real time
                                  "latency_s": round(latency, 2),           # sentence ready → text ready
                                  "waiting": self.inbox.size()})

    # ---------- live text: the sentence SO FAR (fast mode, never used as context) ----------
    def handle_partial(self, p):
        try:
            t0 = time.perf_counter()
            r = self.backend(p["audio"], self._context.get(p["conversation_id"]), fast=True)
            status, text = self._check(r)
            busy = time.perf_counter() - t0
        except Exception as e:
            self.last_error = repr(e)
            return
        if status != "ok":
            return
        fixed, pending = self._agree(p["key"], text.split())
        self.stats["partials"] += 1
        self.bus.publish("transcript_partial", "partial", p["session"],
                         start_sample=p["speech_start"], end_sample=p["speech_end"],
                         details={"conversation_id": p["conversation_id"], "text": " ".join(fixed + pending),
                                  "confirmed": " ".join(fixed), "pending": " ".join(pending),
                                  "audio_s": round(len(p["audio"]) / SR, 2), "busy_s": round(busy, 3)})

    # Word-by-word, append-only: a word is written ONCE and never changes or disappears.
    # The final text of the sentence (accurate model) then replaces the live words → spelling is corrected there.
    def _agree(self, key, words):
        """Live words that only GROW: a word on screen is never changed or removed.
        A word is written as soon as the NEXT word has started (so it is complete, not cut in half).
        Only the last word (still being spoken) waits. The final text of the sentence corrects spelling."""
        L = self._live
        if L is None or L["key"] != key:
            L = self._live = {"key": key, "fixed": []}
        fixed = L["fixed"]
        stable = words[:-1]                          # every word that already has a word after it
        norm = lambda w: w.strip(".,،؟?!:؛;\"'…")
        # Where does the text already on screen end inside this new guess?
        # Usually at the same word count; Whisper may join / split a word ("عبد الله" ↔ "عبدالله"),
        # so look for the last shown word one or two places around it.
        start = len(fixed)
        if fixed:
            last = norm(fixed[-1])
            last2 = norm(fixed[-2]) + last if len(fixed) > 1 else None      # "عبد"+"الله" shown, now "عبدالله"
            for j in (len(fixed) - 1, len(fixed) - 2, len(fixed), len(fixed) - 3, len(fixed) + 1):
                if not 0 <= j < len(stable):
                    continue
                w = norm(stable[j])
                joined = norm(stable[j - 1]) + w if j > 0 else None          # "عبدالله" shown, now "عبد"+"الله"
                if w == last or joined == last or w == last2:
                    start = j + 1
                    break
        new = stable[start:]
        if new:
            L["fixed"] = fixed + new
        return list(L["fixed"]), words[min(start + len(new), len(words)):]




        # DIAGNOSIS: keep the sentence as .wav + .txt, to LISTEN to what the server really received.
    @staticmethod
    def _save_audio(req, audio, status, text):
        try:
            from scipy.io import wavfile
            os.makedirs(SAVE_AUDIO_DIR, exist_ok=True)
            base = os.path.join(SAVE_AUDIO_DIR, f"sentence_{req['id']}")
            pcm = (np.clip(np.asarray(audio, dtype=np.float32), -1, 1) * 32767).astype(np.int16)
            wavfile.write(base + ".wav", SR, pcm)
            with open(base + ".txt", "w", encoding="utf-8") as f:
                f.write(f"{status} | {len(audio) / SR:.1f}s | {text}\n")
        except Exception:
            pass                                       # saving must never break the transcription

    # Decide what to do with the model's answer. Returns (status code, text to show).
    #   "ok"            → show it
    #   "empty"         → the model returned nothing
    #   "no_speech"     → the model itself says there was probably no speech
    #   "hallucination" → a phrase Whisper is known to invent
    @staticmethod
    def _check(r):
        text = (r.get("text") or "").strip()
        if not text:
            return "empty", ""
        if r["no_speech_prob"] > WHISPER_NO_SPEECH and r["avg_logprob"] < WHISPER_MIN_LOGPROB:
            return "no_speech", ""
        # Cut known invented phrases OUT; only if nothing real is left is the sentence dropped.
        for h in HALLUCINATIONS:
            text = text.replace(h, " ")
        text = re.sub(r"\[[^\]]*\]|\([^)]*\)", " ", text)          # "[موسيقى]", "(تصفيق)" …
        text = re.sub(r"\s+", " ", text).strip(" .،,")
        if not text:
            return "hallucination", ""
        return "ok", text

    # A small snapshot for the status (shown through the API).
    def state(self):
        a = self.stats["audio_s"]
        return {"running": self._thread is not None, "busy": self.busy, "waiting": self.inbox.size(),
                "done": self.stats["done"], "filtered": self.stats["filtered"], "errors": self.stats["errors"],
                "partials": self.stats["partials"],
                "rtf": round(self.stats["busy_s"] / a, 3) if a else None,
                "last_latency_s": self.stats["last_latency_s"]}


# ============================================================
# Part 2 — the real model  (Cell 13)
# ============================================================
# Which device + which models. "auto" in config.py → decided here by what the machine has.
def whisper_settings():
    import ctranslate2
    gpu = ctranslate2.get_cuda_device_count() > 0
    live = WHISPER_LIVE_MODEL if WHISPER_LIVE_MODEL != "auto" else ("large-v3-turbo" if gpu else "small")
    final = WHISPER_FINAL_MODEL if WHISPER_FINAL_MODEL != "auto" else ("large-v3" if gpu else live)
    return {"gpu": gpu, "device": "cuda" if gpu else "cpu", "compute": "float16" if gpu else "int8",
            "live_model": live, "final_model": final,
            "beam": WHISPER_GPU_BEAM if gpu else WHISPER_CPU_BEAM,
            "partials": gpu}              # live words only on GPU (on CPU there is no time left for them)


# GPU fix (Linux / Colab): faster-whisper is built for CUDA 12 — load the CUDA-12 libraries
# (pip packages nvidia-cublas-cu12 + nvidia-cudnn-cu12) into memory BEFORE the model starts.
def load_cuda12_libraries():
    if not sys.platform.startswith("linux"):
        return []
    import ctypes
    import site
    loaded = []
    for sp in site.getsitepackages():
        for pat in ("nvidia/cublas/lib/libcublasLt.so.12", "nvidia/cublas/lib/libcublas.so.12",
                    "nvidia/cudnn/lib/libcudnn*.so.9"):
            for lib in sorted(glob.glob(os.path.join(sp, pat))):
                try:
                    ctypes.CDLL(lib, mode=ctypes.RTLD_GLOBAL)
                    loaded.append(os.path.basename(lib))
                except OSError:
                    pass
    return loaded


# Make quiet / far speech louder (never quieter), without clipping.
def normalize_level(audio):
    a = np.ascontiguousarray(audio, dtype=np.float32)
    rms = float(np.sqrt(np.mean(a.astype(np.float64) ** 2))) if len(a) else 0.0
    if rms < 1e-6:
        return a
    gain_db = min(WHISPER_MAX_GAIN_DB, max(0.0, WHISPER_TARGET_DBFS - 20 * np.log10(rms)))
    g = 10 ** (gain_db / 20)
    peak = float(np.max(np.abs(a))) * g
    if peak > 0.99:
        g *= 0.99 / peak
    return a * g if g != 1.0 else a


# The REAL backend — exactly the same interface as FakeWhisper.
class FasterWhisperBackend:
    def __init__(self, size, device="cpu", compute="int8", beam=1, language=WHISPER_LANG):
        from faster_whisper import WhisperModel
        t0 = time.perf_counter()
        # First time: downloads the model (large-v3 ≈ 3 GB, large-v3-turbo ≈ 1.6 GB, small ≈ 0.5 GB).
        self.model = WhisperModel(size, device=device, compute_type=compute)
        self.size, self.language, self.beam = size, language, beam
        self.load_s = round(time.perf_counter() - t0, 1)
        # Warm-up: the very first call is always slow. Do it now on 1 s of silence, not on a real sentence.
        t0 = time.perf_counter()
        self(np.zeros(SR, dtype=np.float32))
        self.warmup_s = round(time.perf_counter() - t0, 2)

    # fast=True (live words): one try, beam 1 → quicker answer while the person is still talking.
    def __call__(self, audio, prompt=None, fast=False):
        audio = normalize_level(audio)
        prompt = " ".join(x for x in (WHISPER_STYLE_PROMPT, prompt if WHISPER_USE_CONTEXT else None) if x)
        segments, info = self.model.transcribe(
            audio,
            language=self.language,               # fixed language, no guessing
            task="transcribe",                    # write what was said (not translate)
            beam_size=1 if fast else self.beam,
            temperature=0.0 if fast else [0.0, 0.2, 0.4],   # high temperatures = invented words
            initial_prompt=prompt or None,
            condition_on_previous_text=False,     # stops repeated-text loops
             no_repeat_ngram_size=3,               # the model may not write the same 3 words twice → no endless loops
            vad_filter=False,                     # Silero already cut the speech
            without_timestamps=True)              # we already know the times (from Silero)
        segs = list(segments)                     # the real work happens HERE (segments is lazy)
        # Drop only the doubtful PARTS (not the whole sentence).
        keep = [s for s in segs
                if not (s.no_speech_prob > WHISPER_SEG_NO_SPEECH and s.avg_logprob < WHISPER_SEG_MIN_LOGPROB)
                and s.compression_ratio <= WHISPER_SEG_MAX_COMPRESSION]
        if not keep:
            return {"text": "", "avg_logprob": 0.0, "no_speech_prob": 1.0, "dropped_parts": len(segs)}
        w = [max(s.end - s.start, 0.01) for s in keep]
        return {"text": " ".join(s.text.strip() for s in keep).strip(),
                "avg_logprob": sum(s.avg_logprob * x for s, x in zip(keep, w)) / sum(w),
                "no_speech_prob": sum(s.no_speech_prob * x for s, x in zip(keep, w)) / sum(w),
                "dropped_parts": len(segs) - len(keep)}


# Two models behind ONE interface: fast=True → live model, fast=False → final (accurate) model.
class DualWhisper:
    def __init__(self, live, final):
        self.live, self.final = live, final
        self.size = f"{live.size} (live) + {final.size} (final)"
        self.load_s = round(live.load_s + final.load_s, 1)
        self.warmup_s = round(live.warmup_s + final.warmup_s, 2)

    @property
    def language(self):
        return self.final.language

    @language.setter
    def language(self, value):
        self.live.language = self.final.language = value

    def __call__(self, audio, prompt=None, fast=False):
        return (self.live if fast else self.final)(audio, prompt, fast=fast)


# Load the right model(s) for this machine, ONCE. Returns (backend, settings).
def load_whisper():
    s = whisper_settings()
    if s["gpu"]:
        s["cuda12_libraries"] = len(load_cuda12_libraries())
    make = lambda size: FasterWhisperBackend(size, s["device"], s["compute"], s["beam"])
    if s["final_model"] == s["live_model"]:
        backend = make(s["live_model"])
    else:
        backend = DualWhisper(make(s["live_model"]), make(s["final_model"]))
    return backend, s