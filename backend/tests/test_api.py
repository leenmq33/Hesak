# API v1 contract — exactly what the Flutter app relies on  (were: notebook Cell 9, part 2)
import json

import numpy as np

from hesak.config import SR, BROWSER_CHUNK
from hesak.audio import encode_like_browser
from hesak.controller import build_system
from hesak.listening import EnergyTestVAD
from hesak.api import (HesakAPI, API_VERSION, ERR_UNKNOWN_CMD, ERR_BAD_ARGS, ERR_ENV_OFF)
from sounds import room, knock, place, speechlike

EVENT_KEYS = {"id", "channel", "type", "code", "session", "t_start", "t_end", "wall_time", "data"}
KNOWN_CODES = (None, "onset", "ongoing", "idle_check", "silence", "max_length", "stop", "discontinuity",
               "gate_closed", "env_on", "env_off", "ok", "empty", "no_speech", "hallucination", "error", "partial")


def make():
    api = HesakAPI(build_system(EnergyTestVAD, threaded=False))

    def call(cmd, **args):                       # JSON text in, like an app
        r = api.handle(json.dumps({"cmd": cmd, "args": args, "req_id": f"t-{cmd}"}))
        json.dumps(r)                            # JSON out, always
        return r

    def push(sig):
        for i in range(0, len(sig), BROWSER_CHUNK):
            assert call("audio.push", pcm16_b64=encode_like_browser(sig[i:i + BROWSER_CHUNK]), sample_rate=SR)["ok"]
    return api, call, push


def test_reply_envelope_and_status_shape():
    _, call, _ = make()
    r = call("sync")
    assert set(r) == {"api", "req_id", "ok", "data"} and r["api"] == API_VERSION and r["req_id"] == "t-sync"
    assert set(r["data"]["status"]) == {"environment", "conversation", "pipeline", "health"}


def test_errors_are_codes():
    api, call, _ = make()
    assert call("dance")["error"]["code"] == ERR_UNKNOWN_CMD
    assert api.handle("{not json")["error"]["code"] == ERR_BAD_ARGS
    assert call("audio.push")["error"]["code"] == ERR_BAD_ARGS
    assert call("conversation.start")["error"]["code"] == ERR_ENV_OFF
    r = call("audio.push", pcm16_b64=encode_like_browser(np.zeros(BROWSER_CHUNK)), sample_rate=SR)
    assert r["data"]["accepted"] is False


def test_a_conversation_through_the_api():
    _, call, push = make()
    last = call("sync")["data"]["last_id"]
    assert call("env.on")["data"]["environment"]["on"] is True
    push(place(room(6.0), knock(), 4.0))
    assert call("conversation.start")["data"] == {"conversation_id": 1}
    push(place(place(room(8.0), speechlike(2.5), 1.0), knock(0.6), 5.5))
    assert call("conversation.end")["data"] == {"conversation_id": 1}
    call("env.off")

    every = call("events.get", since=last, limit=1000)["data"]["events"]
    home = call("events.get", since=last, limit=1000, channel="home")["data"]["events"]
    conv = call("events.get", since=last, limit=1000, channel="conversation")["data"]["events"]
    assert all(set(e) == EVENT_KEYS for e in every)
    assert home and {e["type"] for e in home} <= {"activity_started", "activity_ended", "env_request"}
    assert conv and {e["type"] for e in conv} <= {"conversation_started", "conversation_ended", "speech_started",
                                                  "speech_ended", "stt_request"}
    assert any(e["type"] == "env_request" and abs(e["t_start"] - 11.0) < 1.0 for e in home)   # knock → Home
    assert all(e["code"] in KNOWN_CODES for e in every)
    assert set(call("sync", since=last)["data"]) >= {"status", "events", "last_id"}