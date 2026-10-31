# ============================================================
# HESAK backend — controller.py : the button rules in ONE place + build_system  (was: notebook Cell 7)
# ------------------------------------------------------------
#  Pipeline (serial): mic → ring → Gate → [conversation ON? → Silero] → Whisper
#  "environment" ON        → ring reset, mic accepted, Gate ▶ (+ Whisper worker ▶)
#  "New conversation"      → only if environment is ON (an open conversation is closed first)
#  "End conversation"      → conversation ⏹ (environment keeps running)
#  "environment" OFF       → conversation ⏹ (forced) + environment ⏹
# ============================================================
import time

from .config import SR, WHISPER_INBOX_MAX
from .audio import SharedRingBuffer, MicInput
from .events import EventBus, Handoff, LatestSlot
from .listening import EnvironmentPath, ConversationPath


class HesakController:
    def __init__(self, ring_buffer, bus, mic, env_path, conv_path, yamnet_box, whisper_box, threaded=True,
                 whisper=None):
        self.ring, self.bus, self.mic = ring_buffer, bus, mic
        self.whisper = whisper                             # Level 3 worker (Cell 12) or None
        self.env, self.conv = env_path, conv_path
        self.yamnet_box, self.whisper_box = yamnet_box, whisper_box
        self.threaded = threaded
        self.env_on = False
        self.next_conversation_id = 1
        self.ignored_chunks = 0
        self.errors = 0
        self.last_error = None

    # ---------- Home page ----------
    # Home button ON: new session (clock back to 0) and start the Home path.
    def env_start(self):
        if self.env_on:
            return {"ok": True}
        self.ring.reset()                                  # new session = new sample clock
        self.mic.reset_stats()
        self.env.start(threaded=self.threaded)
        if self.whisper is not None:
            try:
                self.whisper.start()                       # the model is loaded once, then reused
            except Exception as e:
                self.errors += 1
                self.last_error = repr(e)
        self.env_on = True
        self.bus.publish("system", "Environment ON", self.ring.generation)
        return {"ok": True}

    # Home button OFF: close the conversation first, then stop the Home path.
    def env_stop(self):
        if not self.env_on:
            return {"ok": True}
        if self.conv.running:
            self.conv.stop(reason="environment_off")      # rule: no conversation without environment
        self.env.stop()
        self.env_on = False
        self.bus.publish("system", "Environment OFF", self.ring.generation,
                         end_sample=self.ring.total_written)
        return {"ok": True}

    # ---------- Conversation page ----------
    # 'New conversation': refused with ENV_OFF if the environment is off. Closes any open conversation first.
    def conv_start(self):
        if not self.env_on:
            return {"ok": False, "error": "ENV_OFF"}
        if self.conv.running:
            self.conv.stop(reason="new_conversation")
        try:
            self.conv.start(self.next_conversation_id)
        except Exception as e:                              # e.g. Silero not available
            self.errors += 1
            self.last_error = repr(e)
            return {"ok": False, "error": "VAD_UNAVAILABLE", "detail": repr(e)}
        self.next_conversation_id += 1
        return {"ok": True, "conversation_id": self.conv.conversation_id}

    # 'End conversation': only the conversation stops.
    def conv_stop(self, reason="user"):
        if self.conv.running:
            self.conv.stop(reason=reason)
        return {"ok": True}

    # ---------- microphone ----------
    # Every audio chunk from the page arrives here. Ignored (False) if the environment is off.
    def on_audio(self, base64_audio, sample_rate):
        if not self.env_on:                                 # late chunk after OFF
            self.ignored_chunks += 1
            return False
        self.mic.write(base64_audio, sample_rate)
        if not self.threaded:                               # offline tests: step in order
            self.env.step()                                 # Gate → Silero run inside this one step
        return True

    # Same, for raw PCM16 bytes (the phone over WebSocket — no Base64).
    def on_audio_bytes(self, pcm16_bytes, sample_rate):
        if not self.env_on:
            self.ignored_chunks += 1
            return False
        self.mic.write_bytes(pcm16_bytes, sample_rate)
        if not self.threaded:
            self.env.step()
        return True

    # Re-running Cell 10: stop everything, including the Whisper thread.
    # (Environment OFF alone keeps Whisper running, so the last sentences still get their text.)
    def shutdown(self):
        self.env_stop()
        if self.whisper is not None:
            self.whisper.stop()

    # ---------- one snapshot for both pages ----------
    # One snapshot of everything (mic, buffer, Gate, Silero, mailboxes, errors) — the API reshapes it for apps.
    def status(self, last_id=None, max_events=80):
        if last_id is None:
            events, missed = [], 0
        else:
            events, missed = self.bus.get_since(int(last_id))
            events = events[:max_events]
        mic_live = self.env_on and (time.time() - self.mic.last_chunk_wall) < 1.0
        w = self.whisper.state() if self.whisper is not None else None
        errors = (self.errors + self.mic.errors + self.env.stats["errors"] + self.conv.stats["errors"]
                  + (w["errors"] if w else 0))
        return {
            "env_on": self.env_on,
            "mic": {"live": bool(mic_live), "rate": self.mic.rate_in, "chunks": self.mic.chunks},
            "ring": {"session": self.ring.generation, "seconds": round(self.ring.total_written / SR, 1)},
            "env": self.env.state(),
            "conv": self.conv.state(),
            "yamnet_inbox": {"waiting": self.yamnet_box.size(), "sent": self.yamnet_box.sent,
                             "dropped": self.yamnet_box.dropped},
            "whisper_inbox": {"waiting": self.whisper_box.size(), "sent": self.whisper_box.sent,
                              "dropped": self.whisper_box.dropped},
            "whisper": w,
            "errors": int(errors),
            "last_error": (self.last_error or self.env.last_error or self.conv.last_error
                           or (self.whisper.last_error if self.whisper is not None else None)),
            "bus_last_id": self.bus.last_id,
            "missed": int(missed),
            "events": [{k: e[k] for k in ("id", "type", "label", "session", "start_s", "end_s",
                                          "wall_time", "details")} for e in events],
        }



# Builds one complete system in the right order. Used by the tests AND by the live page, so both are identical.
# whisper_factory=None → Levels 1+2 only (the tests in Cell 9). With a factory → Whisper runs too (Cell 10).
def build_system(vad_factory, threaded=True, whisper_factory=None, partials=False):
    """Create one complete, independent system (used for tests AND for the live system)."""
    r = SharedRingBuffer()
    b = EventBus()
    yb, wb = Handoff("yamnet"), Handoff("whisper", maxsize=WHISPER_INBOX_MAX)
    m = MicInput(r)
    env = EnvironmentPath(r, b, yb)
    conv = ConversationPath(r, b, wb, vad_factory)
    env.attach_conversation(conv)                        # Gate → Silero (serial)
    w = None
    if whisper_factory is not None:                      # Level 3 (whisper_stt.py — loaded only when needed)
        from .whisper_stt import WhisperWorker
        slot = LatestSlot() if partials else None
        conv.partial_slot = slot
        w = WhisperWorker(wb, b, whisper_factory, partial_slot=slot)
    return HesakController(r, b, m, env, conv, yb, wb, threaded=threaded, whisper=w)