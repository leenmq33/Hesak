# ============================================================
# HESAK backend — listening.py : Gate + Silero  (was: notebook Cells 5 + 6)
# ------------------------------------------------------------
#   ring → EnvironmentPath (Gate, frames of 32 ms) ─┬─ YAMNet requests (Home — not used by the server)
#                                                  └─ conversation open → ConversationPath (Silero)
#                                                         └─ finished sentence → whisper_inbox
#                                                         └─ sentence so far   → live slot (partials)
# This file never runs Whisper — it only decides WHEN and WHAT.
# ============================================================
import collections
import importlib.util
import threading
import time

import numpy as np

from .config import (SR, FRAME, _EPS,
                     GATE_BG_FRAMES, GATE_BG_PERCENTILE, GATE_BG_UPDATE_FRAMES, GATE_OPEN_DB, GATE_CLOSE_DB,
                     GATE_HOLD_MS, GATE_MIN_DBFS, GATE_REBASELINE_S,
                     ENV_PREROLL_S, ENV_WINDOW_S, ENV_ONGOING_EVERY_S, ENV_IDLE_CHECK_S,
                     VAD_THRESHOLD, CONV_ALWAYS_LISTEN, VAD_MIN_SILENCE_MS, VAD_SPEECH_PAD_MS, VAD_PREROLL_S,
                     STT_PRE_PAD_S, STT_POST_PAD_S, STT_MAX_SEGMENT_S, STT_MIN_SEGMENT_S,
                     SPEECH_BLOCKS_YAMNET, STT_PARTIAL_MIN_S, STT_PARTIAL_EVERY_S)
from .audio import BufferReader


# ============================================================
# Part 1 — the Activity Gate + the environment path  (Cell 5)
# ============================================================
class ActivityGate:
    """Pure per-frame logic: activity vs no activity above an adaptive background."""

    def __init__(self):
        self.reset()

    def reset(self):
        # Two memories: quiet frames (to learn the room) and all frames (used when a long sound becomes background).
        self._hist = collections.deque(maxlen=GATE_BG_FRAMES)     # quiet frames → floor
        self._recent = collections.deque(maxlen=GATE_BG_FRAMES)   # all frames → rebaseline
        self._since_update = 0
        self.floor_db = None
        self.frames = 0
        self.active = False
        self.seg_start = None
        self._last_above_end = None
        self.level_db = None
        self.in_warmup = True          # True while frames are only used to learn the room

    @property
    def warming(self):
        return self.frames < GATE_BG_FRAMES

    # Room level = the 20% quietest recent frames. Recomputed every 256 ms.
    def _learn(self, e_db, force=False):
        self._hist.append(e_db)
        self._since_update += 1
        if force or self._since_update >= GATE_BG_UPDATE_FRAMES or (
                self.floor_db is None and len(self._hist) >= GATE_BG_UPDATE_FRAMES):
            self.floor_db = float(np.percentile(self._hist, GATE_BG_PERCENTILE))
            self._since_update = 0

    def _close(self, reason, end):
        ev = ("close", self.seg_start, end, reason)
        self.active = False
        self.seg_start = None
        return ev

    # The decision for ONE frame. Returns: nothing / 'open' / 'close'.
    def process(self, fs, e_db, hold_open=False):
        """One 512-sample frame. Returns None, ('open', start) or ('close', start, end, reason).
        hold_open=True (Silero is inside a sentence) → never rebaseline: long speech must not be cut."""
        self.frames += 1
        self.in_warmup = self.frames <= GATE_BG_FRAMES
        self.level_db = e_db
        self._recent.append(e_db)
        fe = fs + FRAME

        if self.frames <= GATE_BG_FRAMES:                       # warm-up: learn only
            self._learn(e_db, force=(self.frames == GATE_BG_FRAMES))
            return None
        # While a sound is going on, the room level is FROZEN (so a long alarm is not 'forgotten').
        if not self.active:                                     # learn from quiet frames only
            self._learn(e_db)

        # How much louder than the room is this frame (in dB)?
        rise = e_db - self.floor_db
        loud = e_db >= GATE_MIN_DBFS

        if not self.active:
            if loud and rise >= GATE_OPEN_DB:                   # open fast: one frame
                self.active = True
                self.seg_start = fs
                self._last_above_end = fe
                return ("open", fs)
            return None

        # Still loud enough → keep open. Quiet for 300 ms → close.
        # While Silero is inside a sentence, wait a bit LONGER than Silero's own pause rule,
        # so Silero ends the sentence itself (a short pause is not cut by the Gate).
        hold_ms = max(GATE_HOLD_MS, VAD_MIN_SILENCE_MS + 200) if hold_open else GATE_HOLD_MS
        if loud and rise >= GATE_CLOSE_DB:
            self._last_above_end = fe
        elif fe - self._last_above_end >= int(hold_ms * SR / 1000):        # close slow
            return self._close("quiet", self._last_above_end)

        # A sound longer than 20 s (AC, rain) becomes the new room level, so new sounds on top still open the Gate.
        # Not while someone is mid-sentence (hold_open), so long speech is not cut.
        if not hold_open and fe - self.seg_start >= int(GATE_REBASELINE_S * SR):  # long sound → new background
            self._hist = collections.deque(self._recent, maxlen=GATE_BG_FRAMES)
            self.floor_db = float(np.percentile(self._hist, GATE_BG_PERCENTILE))
            self._since_update = 0
            return self._close("rebaseline", fe)
        return None



# ---- The Home path: runs the Gate in its own background thread and decides when to call YAMNet ----
class EnvironmentPath:
    """Level 2 for the Home page. Never runs YAMNet — only decides when and what.
    Also the router: feeds Silero (ConversationPath) with the sound that passed the Gate."""

    def __init__(self, ring_buffer, bus, inbox):
        self.ring, self.bus, self.inbox = ring_buffer, bus, inbox
        self.gate = ActivityGate()
        self.conv = None                  # ConversationPath — set by attach_conversation()
        self.running = False
        self.session = None
        self._thread = None
        self._stop_event = threading.Event()
        self.activity_id = 0
        self.request_id = 0
        # A list of when the Gate was open (start, end) — for checks and reports.
        self.spans = collections.deque(maxlen=200)   # [start, end or None] of every Gate-open period
        self.stats = self._new_stats()
        self.last_error = None

    @staticmethod
    def _new_stats():
        return {"frames": 0, "activities": 0, "requests": 0, "onset": 0, "ongoing": 0, "idle_check": 0,
                "lost_requests": 0, "overflows": 0, "dropped_samples": 0, "proc_us": 0.0, "errors": 0,
                "speech_routed": 0}

    # Connects Silero behind the Gate (done once in build_system, Cell 7).
    def attach_conversation(self, conv):
        """Connect the next stage: Silero (+Whisper) sits behind this Gate."""
        self.conv = conv

    # ---------- lifecycle ----------
    # Environment ON: make a reader that starts 'now' and start the background thread.
    def start(self, threaded=True):
        if self.running:
            return
        self.session = self.ring.generation
        self.reader = BufferReader(self.ring, "environment")      # starts at "now"
        self._restart_at(self.reader.cursor)
        self.stats = self._new_stats()
        self.running = True
        if threaded:
            self._stop_event.clear()
            self._thread = threading.Thread(target=self._run, name="hesak-environment", daemon=True)
            self._thread.start()

    # Environment OFF: stop the thread, process the last bit of audio, close any open sound.
    def stop(self):
        if not self.running:
            return
        self._stop_event.set()
        if self._thread is not None:
            self._thread.join(2.0)
            self._thread = None
        try:
            self.step()                                            # finish the audio tail
        except Exception as e:
            self._error(e)
        if self.gate.active:
            self._on_close(("close", self.gate.seg_start, self._next_frame, "stop"))
            self.gate.active = False
        self._pending = None
        self.running = False

    # Reset everything for a fresh start (new session or after audio was lost).
    def _restart_at(self, start):
        self._origin = start
        self._local = np.zeros(0, dtype=np.float32)
        self._local_start = start
        self._next_frame = -(-start // FRAME) * FRAME
        self.gate.reset()
        self._pending = None                  # start sample of an onset window not yet sent
        self._next_ongoing = None
        self._last_req_end = self._next_frame
        self.spans.clear()                                   # new sample clock → old spans are meaningless

    # ---------- main work ----------
    # One round of work: read the new audio, cut it into 32 ms frames, decide each frame.
    def step(self):
        t0 = time.perf_counter()
        start, audio, dropped = self.reader.read_new()
        local_end = self._local_start + len(self._local)
        # A gap in the audio (session reset or this path fell 30 s behind) → start over cleanly.
        if start != local_end:                                     # overflow or reset
            self.stats["overflows"] += 1
            self.stats["dropped_samples"] += dropped
            if self.gate.active:
                self._on_close(("close", self.gate.seg_start, local_end, "discontinuity"))
            self.session = self.ring.generation
            self._restart_at(start)
            if self.conv is not None:
                self.conv.resync(start)
        if len(audio):
            self._local = np.concatenate([self._local, audio])

        off = self._next_frame - self._local_start
        n = max(0, (len(self._local) - off) // FRAME)
        if n:
            block = self._local[off:off + n * FRAME].reshape(n, FRAME).astype(np.float64)
            # Loudness of every frame at once (in dB).
            e_db = 10 * np.log10(np.mean(block * block, axis=1) + _EPS)
            for i in range(n):
                fs = self._next_frame + i * FRAME
                # Is Silero in the middle of a sentence? (then the Gate must not 'forget' this sound)
                hold = self.conv is not None and self.conv.speech_on
                ev = self.gate.process(fs, float(e_db[i]), hold_open=hold)
                if ev is not None and ev[0] == "open":
                    self._on_open(ev)
                closing = ev is not None and ev[0] == "close"
                # the frame goes to Silero BEFORE the close is announced → Silero can end its own sentence
                self._feed_conv(fs, self._local[off + i * FRAME: off + (i + 1) * FRAME], closing)
                if closing:
                    self._on_close(ev)
                self._after_frame(fs + FRAME)
            self._next_frame += n * FRAME
            self.stats["frames"] += n
            keep_from = self._next_frame - self._local_start
            self._local = self._local[keep_from:]
            self._local_start = self._next_frame
        self.stats["proc_us"] += (time.perf_counter() - t0) * 1e6
        return n

    # THE ROUTER: decides if this frame goes to Silero.
    def _feed_conv(self, fs, chunk, closing):
        """The router. Silero gets this frame ONLY while the Gate is open (or still learning the room).
        Conversation OFF → nothing here, the sound is YAMNet's only.
        Conversation ON  → Silero listens to what passed the Gate; speech → Whisper, the rest → YAMNet."""
        c = self.conv
        if c is None or not c.running:
            return
        # Conversation open → Silero hears everything; it alone decides where sentences start and end.
        if CONV_ALWAYS_LISTEN:
            if not c.feeding:
                c.begin(fs)
            c.feed(chunk)
            return
        # Silero only gets audio while the Gate is open (or during the first 3 s, so no word is lost).
        if self.gate.active or closing or self.gate.in_warmup:
            if closing and not c.feeding:
                return
            if not c.feeding:
                c.begin(fs)                  # also gives Silero VAD_PREROLL_S of audio before this frame
            c.feed(chunk)
        elif c.feeding:
            c.end(fs, "gate_closed")         # safety: Gate shut but Silero still awake

    # The Gate just opened: new activity. Remember where the YAMNet window should start (0.5 s earlier).
    def _on_open(self, ev):
        self.activity_id += 1
        self.stats["activities"] += 1
        fs = ev[1]
        self.spans.append([fs, None])
        self._pending = max(self._origin, fs - int(ENV_PREROLL_S * SR))
        self.bus.publish("activity_started", "Activity ON", self.session, start_sample=fs,
                         details={"activity_id": self.activity_id})

    # The Gate just closed: tell Silero (it sends any open sentence) and announce the end.
    def _on_close(self, ev):
        _, s, e, reason = ev
        # The Gate closing does not cut a sentence when Silero listens all the time (only a gap in the audio does).
        if self.conv is not None and (not CONV_ALWAYS_LISTEN or reason == "discontinuity"):
            self.conv.end(e, reason)         # a sentence in progress is cut where the sound ended
        if self.spans and self.spans[-1][1] is None:
            self.spans[-1][1] = e
        self._next_ongoing = None
        self._last_req_end = max(self._last_req_end, e)
        self.bus.publish("activity_ended", "Activity OFF", self.session, start_sample=s, end_sample=e,
                         details={"activity_id": self.activity_id, "reason": reason,
                                  "duration_s": round((e - s) / SR, 3)})

    # After each frame: is it time to ask YAMNet?
    #   onset      = the first 1 s window after the Gate opened
    #   ongoing    = every 3 s while the sound continues
    #   idle_check = every 10 s while it is quiet (catches sounds that became background, like rain)
    def _after_frame(self, fe):
        """Decide whether YAMNet must look now."""
        W = int(ENV_WINDOW_S * SR)
        if self._pending is not None:
            if fe >= self._pending + W:                                  # onset window complete
                s = self._pending
                self._pending = None
                self._request("onset", s, s + W, self.activity_id)
                self._next_ongoing = s + W + int(ENV_ONGOING_EVERY_S * SR)
        elif self.gate.active:
            if self._next_ongoing is not None and fe >= self._next_ongoing:
                self._request("ongoing", fe - W, fe, self.activity_id)
                self._next_ongoing += int(ENV_ONGOING_EVERY_S * SR)
        elif (ENV_IDLE_CHECK_S and not self.gate.warming
              and fe - self._last_req_end >= int(ENV_IDLE_CHECK_S * SR) and fe - W >= self._origin):
            self._request("idle_check", fe - W, fe, None)

    # Build one YAMNet request: copy the exact audio window and put it in the YAMNet mailbox.
    def _request(self, reason, s, e, activity_id):
        self._last_req_end = e
        # Skip windows that contain speech (they go to Whisper). See the WARNING in Cell 1.
        if SPEECH_BLOCKS_YAMNET and self.conv is not None and self.conv.was_speech(s, e):
            self.stats["speech_routed"] += 1     # Silero heard speech here → it goes to Whisper, not YAMNet
            return
        try:
            audio = self.ring.read(s, e)
        except ValueError:
            self.stats["lost_requests"] += 1
            return
        self.request_id += 1
        self.stats["requests"] += 1
        self.stats[reason] += 1
        self.inbox.put({"id": self.request_id, "target": "yamnet", "reason": reason,
                        "activity_id": activity_id, "session": self.session,
                        "start_sample": s, "end_sample": e, "audio": audio, "created_at": time.time()})
        self.bus.publish("env_request", reason, self.session, start_sample=s, end_sample=e,
                         details={"request_id": self.request_id, "reason": reason,
                                  "activity_id": activity_id, "waiting": self.inbox.size()})

    # ---------- thread ----------
    def _error(self, e):
        self.stats["errors"] += 1
        self.last_error = repr(e)

    # The background loop: work if there is new audio, otherwise sleep 20 ms.
    def _run(self):
        while not self._stop_event.is_set():
            try:
                n = self.step()
            except Exception as e:
                self._error(e)
                n = 0
            if n == 0:
                self._stop_event.wait(0.02)

    # A small snapshot for the page (is it learning? open? how loud?).
    def state(self):
        g = self.gate
        return {"running": self.running, "warming": bool(self.running and g.warming),
                "active": bool(self.running and g.active),
                "level_db": None if g.level_db is None else round(g.level_db, 1),
                "floor_db": None if g.floor_db is None else round(g.floor_db, 1),
                "lag_s": round(max(0, self.ring.total_written - self._next_frame) / SR, 2) if self.running else 0.0,
                "requests": self.stats["requests"], "activities": self.stats["activities"]}
    

# ============================================================
# Part 2 — Silero + the conversation path  (Cell 6)
# ============================================================
_SILERO_MODEL = None
SILERO_AVAILABLE = importlib.util.find_spec("silero_vad") is not None


# Small wrapper: give Silero 512 samples, get back 'speech started' / 'speech ended' / nothing.
class SileroStream:
    """Wraps Silero's VADIterator. Indices are samples since the last reset()."""

    def __init__(self):
        global _SILERO_MODEL
        import torch
        from silero_vad import load_silero_vad, VADIterator
        # One CPU core is plenty for Silero (~1 ms per 32 ms frame).
        torch.set_num_threads(1)                      # one core is plenty (≈1 ms / 32 ms)
        if _SILERO_MODEL is None:
            _SILERO_MODEL = load_silero_vad()
        self._torch = torch
        self.it = VADIterator(_SILERO_MODEL, sampling_rate=SR, threshold=VAD_THRESHOLD,
                              min_silence_duration_ms=VAD_MIN_SILENCE_MS, speech_pad_ms=VAD_SPEECH_PAD_MS)

    def reset(self):
        self.it.reset_states()

    def __call__(self, chunk):
        return self.it(self._torch.from_numpy(np.ascontiguousarray(chunk, dtype=np.float32)),
                       return_seconds=False)



# TESTS ONLY: a fake Silero that says 'speech' when a sound is loud for ≥ 0.25 s. Lets us test anywhere.
class EnergyTestVAD:
    """TESTS ONLY — same interface as SileroStream, decides by loudness.
    Lets the plumbing be tested with known boundaries, anywhere."""

    def __init__(self, thr_db=-40.0, min_run_frames=8):
        self.thr_db = thr_db
        self.min_run = min_run_frames          # speech = sustained sound (≥ 0.25 s), not a knock
        self.reset()

    def reset(self):
        self.n = 0
        self.on = False
        self.quiet = 0
        self.run = 0
        self.run_start = 0

    def __call__(self, chunk):
        e = 10 * np.log10(np.mean(chunk.astype(np.float64) ** 2) + _EPS)
        fs = self.n
        self.n += len(chunk)
        if not self.on:
            if e > self.thr_db:
                if self.run == 0:
                    self.run_start = fs
                self.run += 1
                if self.run >= self.min_run:
                    self.on, self.quiet, self.run = True, 0, 0
                    return {"start": self.run_start}
            else:
                self.run = 0
            return None
        if self.on:
            self.quiet = 0 if e > self.thr_db else self.quiet + len(chunk)
            if self.quiet >= VAD_MIN_SILENCE_MS * SR // 1000:
                self.on = False
                return {"end": self.n - self.quiet}
        return None



# ---- The Conversation path ----
class ConversationPath:
    """Level 2 for the Conversation page. Never runs Whisper — only decides when and what.

    Driven by the Gate (EnvironmentPath):
        begin(fs)      Gate opened (or conversation started during a sound) → Silero starts,
                       first fed with VAD_PREROLL_S of audio from BEFORE the Gate opened
        feed(chunk)    one 512-sample frame while the Gate is open
        end(e, why)    Gate closed → a sentence still in progress is sent to Whisper
    """

    def __init__(self, ring_buffer, bus, inbox, vad_factory):
        self.ring, self.bus, self.inbox = ring_buffer, bus, inbox
        self.vad_factory = vad_factory
        self.vad = None
        self.running = False            # a conversation is open
        # running = a conversation is open.  feeding = Silero is awake right now (Gate open).
        self.feeding = False            # Silero is receiving audio right now (Gate open)
        self.conversation_id = None
        self.session = None
        self.speech_on = False
        self.seg_start = None
        # Where Silero heard speech. The Gate reads this to keep speech away from YAMNet.
        self.speech_spans = collections.deque(maxlen=200)   # [start, end or None] — read by Cell 5
        # The Gate thread feeds audio while the buttons start/stop → this lock keeps them from clashing.
        self._lock = threading.RLock()  # Gate thread feeds, button thread starts/stops
        self._origin = self._base = self._fed = 0
        self.request_id = 0
        # Live text: set by build_system (Cell 7). None = no partial requests (the tests above).
        self.partial_slot = None
        self._next_partial = None
        self.stats = self._new_stats()
        self.last_error = None

    @staticmethod
    def _new_stats():
        return {"vad_frames": 0, "sentences": 0, "requests": 0, "too_short": 0, "lost_requests": 0,
                "overflows": 0, "vad_us": 0.0, "errors": 0, "partials": 0}

    # ---------- lifecycle ----------
    # 'New conversation' button. Loads Silero the first time only.
    def start(self, conversation_id):
        with self._lock:
            if self.running:
                return
            if self.vad is None:
                self.vad = self.vad_factory()                      # model loaded once
            self.vad.reset()
            self.conversation_id = conversation_id
            self.session = self.ring.generation
            self._origin = max(self.ring.oldest_index, self.ring.total_written - int(VAD_PREROLL_S * SR))
            self._base = self._fed = self._origin
            self.seg_start = None
            self.speech_on = False
            self.feeding = False
            self.speech_spans.clear()
            self.stats = self._new_stats()
            self.running = True
            self.bus.publish("conversation_started", f"Conversation {conversation_id}", self.session,
                             start_sample=self._origin, details={"conversation_id": conversation_id})

    # 'End conversation' (or environment OFF). A sentence in progress is still sent.
    def stop(self, reason="user"):
        with self._lock:
            if not self.running:
                return
            if self.seg_start is not None:                         # sentence cut by the stop
                self._request(self.seg_start, self._fed, "stop")
                self._speech_off(self._fed, "stop")
            self.feeding = False
            self.bus.publish("conversation_ended", f"Conversation {self.conversation_id}", self.session,
                             end_sample=self.ring.total_written,
                             details={"conversation_id": self.conversation_id, "reason": reason})
            self.running = False

    # Audio was lost or the session reset: send what we have and restart the clock.
    def resync(self, start):
        """The Gate lost continuity (ring overflow / reset): cut what is in progress, restart the clock."""
        with self._lock:
            if self.feeding:
                self.end(self._fed, "discontinuity")
            self.stats["overflows"] += 1
            self.session = self.ring.generation
            self._origin = self._base = self._fed = start

    # ---------- fed by the Gate ----------
    # The Gate opened → wake Silero. It first hears 0.5 s from BEFORE the Gate opened, so the first word is not cut.
    def begin(self, fs):
        with self._lock:
            if not self.running or self.feeding:
                return
            self.vad.reset()
            ps = max(self._origin, self.ring.oldest_index, fs - int(VAD_PREROLL_S * SR))
            ps = min(ps, fs)
            ps = fs - ((fs - ps) // FRAME) * FRAME                 # stay on the 32 ms grid
            pre = np.zeros(0, dtype=np.float32)
            if ps < fs:
                try:
                    pre = self.ring.read(ps, fs)
                except ValueError:
                    ps = fs
            self._base = self._fed = ps
            self.feeding = True
            for k in range(len(pre) // FRAME):
                self._feed_frame(pre[k * FRAME:(k + 1) * FRAME])

    # One 32 ms frame from the Gate.
    def feed(self, chunk):
        with self._lock:
            if self.running and self.feeding:
                self._feed_frame(chunk)

    # The Gate closed → Silero goes to sleep; an unfinished sentence is sent to Whisper.
    def end(self, end, reason):
        with self._lock:
            if not self.feeding:
                return
            if self.seg_start is not None:
                code = reason if reason in ("discontinuity", "stop") else "gate_closed"
                e = min(self._fed, max(end, self.seg_start))
                self._request(self.seg_start, e, code)
                self._speech_off(e, code)
            self.feeding = False

    # Asked by the Gate before each YAMNet request: was there speech in this window?
    def was_speech(self, s, e):
        """Used by the Gate: did Silero hear speech inside [s, e)?  (then YAMNet does not need it)"""
        return any(a < e and (b is None or b > s) for a, b in list(self.speech_spans))

    # ---------- main work ----------
    # Run Silero on one frame and react to what it says.
    def _feed_frame(self, chunk):
        t0 = time.perf_counter()
        try:
            ev = self.vad(chunk)
        except Exception as e:                                     # Silero failed → Gate/YAMNet keep working
            self._error(e)
            ev = None
        self.stats["vad_us"] += (time.perf_counter() - t0) * 1e6
        self.stats["vad_frames"] += 1
        self._fed += FRAME
        if ev:
            # Silero: speech started → remember where.
            if "start" in ev and self.seg_start is None:
                self.seg_start = max(self._origin, self._base + int(ev["start"]))
                self.speech_on = True
                self.speech_spans.append([self.seg_start, None])
                self._next_partial = self.seg_start + int(STT_PARTIAL_MIN_S * SR)
                self.bus.publish("speech_started", "Speech ON", self.session, start_sample=self.seg_start,
                                 details={"conversation_id": self.conversation_id})
            # Silero: speech ended (300 ms of silence) → send the sentence.
            elif "end" in ev and self.seg_start is not None:
                end = min(self._fed, self._base + int(ev["end"]))
                self._request(self.seg_start, end, "silence")
                self._speech_off(end, "silence")
        # Talking non-stop for 15 s → send this part now and keep going.
        if self.seg_start is not None and self._fed - self.seg_start >= int(STT_MAX_SEGMENT_S * SR):
            self._request(self.seg_start, self._fed, "max_length")    # speech continues
            self.seg_start = self._fed
            self._next_partial = self.seg_start + int(STT_PARTIAL_MIN_S * SR)
        # Someone is still talking → every 1 s, hand the sentence-so-far to Whisper as LIVE text.
        if (self.partial_slot is not None and self.seg_start is not None and self._next_partial is not None
                and self._fed >= self._next_partial):
            self._partial()
            self._next_partial = self._fed + int(STT_PARTIAL_EVERY_S * SR)

    # The sentence so far (not finished) → the live slot. Only the newest one is kept.
    def _partial(self):
        cs = max(self._origin, self.ring.oldest_index, self.seg_start - int(STT_PRE_PAD_S * SR))
        try:
            audio = self.ring.read(cs, self._fed)
        except ValueError:
            return
        self.stats["partials"] += 1
        self.partial_slot.put({"key": (self.session, self.conversation_id, self.seg_start), "partial": True,
                               "conversation_id": self.conversation_id, "session": self.session,
                               "speech_start": self.seg_start, "speech_end": self._fed,
                               "audio": audio, "created_at": time.time()})

    def _speech_off(self, end, reason):
        s = self.seg_start
        self.seg_start = None
        self._next_partial = None
        self.speech_on = False
        self.stats["sentences"] += 1
        if self.speech_spans and self.speech_spans[-1][1] is None:
            self.speech_spans[-1][1] = end
        self.bus.publish("speech_ended", "Speech OFF", self.session, start_sample=s, end_sample=end,
                         details={"conversation_id": self.conversation_id, "reason": reason})

    # Build one Whisper request: skip tiny bits (< 0.3 s), add padding, copy the audio, put it in the mailbox.
    def _request(self, s, e, reason):
        # The final text of this sentence is coming → its waiting live request is out of date.
        if self.partial_slot is not None:
            self.partial_slot.clear(key=(self.session, self.conversation_id, s))
        if e - s < int(STT_MIN_SEGMENT_S * SR):
            self.stats["too_short"] += 1
            return
        cs = max(self._origin, self.ring.oldest_index, s - int(STT_PRE_PAD_S * SR))
        ce = min(self._fed, self.ring.total_written, e + int(STT_POST_PAD_S * SR))
        try:
            audio = self.ring.read(cs, ce)
        except ValueError:
            self.stats["lost_requests"] += 1
            return
        self.request_id += 1
        self.stats["requests"] += 1
        self.inbox.put({"id": self.request_id, "target": "whisper", "reason": reason,
                        "conversation_id": self.conversation_id, "session": self.session,
                        "speech_start": s, "speech_end": e, "start_sample": cs, "end_sample": ce,
                        "audio": audio, "created_at": time.time()})
        self.bus.publish("stt_request", reason, self.session, start_sample=cs, end_sample=ce,
                         details={"request_id": self.request_id, "reason": reason,
                                  "conversation_id": self.conversation_id,
                                  "speech_s": round((e - s) / SR, 2), "waiting": self.inbox.size()})

    def _error(self, e):
        self.stats["errors"] += 1
        self.last_error = repr(e)

    def state(self):
        f = max(1, self.stats["vad_frames"])
        return {"running": self.running, "conversation_id": self.conversation_id,
                "speech": bool(self.running and self.speech_on),
                "vad_running": bool(self.running and self.feeding),     # Silero awake (Gate open)
                "requests": self.stats["requests"],
                # cost of Silero WHILE it runs (it sleeps whenever the Gate is closed)
                "vad_load_pct": round(self.stats["vad_us"] / f / (FRAME / SR * 1e6) * 100, 2)}