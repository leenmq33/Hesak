# ============================================================
# HESAK backend — api.py : API v1 — the ONLY door for any interface  (was: notebook Cell 8)
# ------------------------------------------------------------
# The Colab test page used it; the Flutter app sends the SAME messages (over WebSocket).
#   request : {"cmd": "env.on", "args": {...}, "req_id": "optional"}
#   reply   : {"api": "1.0", "req_id": ..., "ok": true,  "data": {...}}
#             {"api": "1.0", "req_id": ..., "ok": false, "error": {"code": "ENV_OFF", "message": "..."}}
# The API sends CODES, never display text. Each app translates codes itself.
# ============================================================
import json

API_VERSION = "1.0"

# ---- error codes ----
# Error codes an app may receive:
ERR_ENV_OFF = "ENV_OFF"                    # conversation needs the environment ON
ERR_VAD_UNAVAILABLE = "VAD_UNAVAILABLE"    # Silero could not be loaded
ERR_UNKNOWN_CMD = "UNKNOWN_CMD"
ERR_BAD_ARGS = "BAD_ARGS"
ERR_INTERNAL = "INTERNAL"

# ---- which page each event belongs to ----
# Which screen shows each event: 'home', 'conversation' or 'system'.
EVENT_CHANNEL = {
    "activity_started": "home", "activity_ended": "home", "env_request": "home",
    "conversation_started": "conversation", "conversation_ended": "conversation",
    "speech_started": "conversation", "speech_ended": "conversation", "stt_request": "conversation",
    "system": "system",
    "sound": "home",              # YAMNet result   → Home page (later)
    "transcript": "conversation", # Whisper result  → Conversation page
    "transcript_partial": "conversation",  # live Whisper text while someone is talking
}
_SYSTEM_CODES = {"Environment ON": "env_on", "Environment OFF": "env_off"}


# Used inside the API to return a clean error reply instead of crashing.
class ApiError(Exception):
    def __init__(self, code, message=""):
        super().__init__(message)
        self.code, self.message = code, message



# The API itself: a table of commands → functions.
class HesakAPI:
    def __init__(self, controller):
        self.ctl = controller
        self._commands = {
            "env.on": self._env_on,
            "env.off": self._env_off,
            "conversation.start": self._conv_start,
            "conversation.end": self._conv_end,
            "audio.push": self._audio_push,
            "status.get": lambda a: self.status(),
            "events.get": self._events_get,
            "sync": self._sync,
        }

    # ---------- the single entry point ----------
    # The single entry point. Takes a JSON message, returns a JSON-safe reply. Never raises.
    def handle(self, message):
        req_id = None
        try:
            if isinstance(message, (str, bytes)):
                try:
                    message = json.loads(message)
                except ValueError:
                    raise ApiError(ERR_BAD_ARGS, "message is not valid JSON")
            if not isinstance(message, dict):
                raise ApiError(ERR_BAD_ARGS, "message must be an object")
            req_id = message.get("req_id")
            cmd = message.get("cmd")
            args = message.get("args") or {}
            if cmd not in self._commands:
                raise ApiError(ERR_UNKNOWN_CMD, f"unknown command: {cmd}")
            if not isinstance(args, dict):
                raise ApiError(ERR_BAD_ARGS, "args must be an object")
            return {"api": API_VERSION, "req_id": req_id, "ok": True, "data": self._commands[cmd](args)}
        except ApiError as e:
            return {"api": API_VERSION, "req_id": req_id, "ok": False,
                    "error": {"code": e.code, "message": e.message}}
        except Exception as e:
            self.ctl.errors += 1
            self.ctl.last_error = repr(e)
            return {"api": API_VERSION, "req_id": req_id, "ok": False,
                    "error": {"code": ERR_INTERNAL, "message": repr(e)}}

    # ---------- commands ----------
    def _env_on(self, a):
        self.ctl.env_start()
        return self.status()

    def _env_off(self, a):
        self.ctl.env_stop()
        return self.status()

    def _conv_start(self, a):
        r = self.ctl.conv_start()
        if not r["ok"]:
            raise ApiError(r["error"], r.get("detail", ""))
        return {"conversation_id": r["conversation_id"]}

    def _conv_end(self, a):
        cid = self.ctl.conv.conversation_id if self.ctl.conv.running else None
        self.ctl.conv_stop()
        return {"conversation_id": cid}

    # Audio from the app: PCM16 as Base64 + the sample rate.
    def _audio_push(self, a):
        pcm, rate = a.get("pcm16_b64"), a.get("sample_rate")
        if not isinstance(pcm, str) or not isinstance(rate, (int, float)) or rate <= 0:
            raise ApiError(ERR_BAD_ARGS, "audio.push needs pcm16_b64 (str) and sample_rate (> 0)")
        return {"accepted": bool(self.ctl.on_audio(pcm, int(rate)))}

    # New events after id 'since', optionally only one channel.
    def _events_get(self, a):
        since = a.get("since", 0)
        limit = a.get("limit", 100)
        channel = a.get("channel")
        if not isinstance(since, int) or since < 0 or not isinstance(limit, int) or limit < 1:
            raise ApiError(ERR_BAD_ARGS, "since must be int ≥ 0, limit int ≥ 1")
        if channel not in (None, "home", "conversation", "system"):
            raise ApiError(ERR_BAD_ARGS, "channel must be home | conversation | system")
        raw, missed = self.ctl.bus.get_since(since)
        raw = raw[:limit]
        last = raw[-1]["id"] if raw else max(since, 0)
        evs = [self._event(e) for e in raw]
        if channel:
            evs = [e for e in evs if e["channel"] == channel]
        return {"events": evs, "last_id": last, "latest_id": self.ctl.bus.last_id, "missed": missed}

    # What a screen calls every 250 ms: new events + current status in ONE call.
    def _sync(self, a):
        """What a page needs on every poll: new events + current status, in one call."""
        since = a.get("since")
        if since is None:                             # first call: start from "now"
            return {"status": self.status(), "events": [], "last_id": self.ctl.bus.last_id, "missed": 0}
        out = self._events_get({"since": since, "limit": a.get("limit", 100)})
        out["status"] = self.status()
        return out

    # ---------- shapes the apps depend on ----------
    @staticmethod
    # The event shape apps can rely on (API v1). Do not change without a new version.
    def _event(e):
        d = dict(e["details"])
        code = e["label"] if e["type"] in ("env_request", "stt_request", "transcript", "transcript_partial") else None
        if e["type"] == "system":
            code = _SYSTEM_CODES.get(e["label"], e["label"])
        return {"id": e["id"], "channel": EVENT_CHANNEL.get(e["type"], "system"), "type": e["type"],
                "code": code, "session": e["session"], "t_start": e["start_s"], "t_end": e["end_s"],
                "wall_time": e["wall_time"], "data": d}

    # The status shape apps can rely on (API v1).
    def status(self):
        c = self.ctl
        s = c.status(None)
        g = s["env"]
        W = s["whisper"]
        gate = "off" if not g["running"] else "warming" if g["warming"] else "active" if g["active"] else "quiet"
        return {
            "environment": {"on": s["env_on"], "mic_live": s["mic"]["live"], "sample_rate": s["mic"]["rate"],
                            "session": s["ring"]["session"], "seconds": s["ring"]["seconds"],
                            "gate": gate, "level_db": g["level_db"]},
            "conversation": {"on": s["conv"]["running"],
                             "id": s["conv"]["conversation_id"] if s["conv"]["running"] else None,
                             "speech": s["conv"]["speech"], "vad_running": s["conv"]["vad_running"]},
            "pipeline": {"yamnet_waiting": s["yamnet_inbox"]["waiting"], "yamnet_sent": s["yamnet_inbox"]["sent"],
                         "whisper_waiting": s["whisper_inbox"]["waiting"], "whisper_sent": s["whisper_inbox"]["sent"],
                         "env_lag_s": g["lag_s"], "conv_lag_s": g["lag_s"],   # serial: one lag for both
                         "vad_load_pct": s["conv"]["vad_load_pct"],
                         # Level 3 (None / False when Whisper is not part of this system)
                         "whisper_on": bool(W and W["running"]), "whisper_busy": bool(W and W["busy"]),
                         "whisper_done": W["done"] if W else 0, "whisper_rtf": W["rtf"] if W else None,
                         "whisper_latency_s": W["last_latency_s"] if W else None},
            "health": {"errors": s["errors"], "last_error": s["last_error"]},
        }