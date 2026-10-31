# Tests for server.py — a fake phone talks to the server through the WebSocket interface
# (no network, no models: the ASGI app is called directly with fake connect/receive/send)
import asyncio
import json
import time

from hesak.config import SR, BROWSER_CHUNK
from hesak.audio import encode_pcm16
from hesak.controller import build_system
from hesak.listening import EnergyTestVAD
from hesak.whisper_stt import FakeWhisper
from server import create_app
from sounds import room, place, speechlike


class FakePhone:
    """Plays the phone side of one WebSocket connection."""

    def __init__(self, app, query=""):
        self.app, self.query = app, query
        self.inbox = asyncio.Queue()       # what the phone sends
        self.got = []                      # what the server sent back

    async def receive(self):
        return await self.inbox.get()

    async def send(self, msg):
        self.got.append(msg)

    def start(self):
        scope = {"type": "websocket", "path": "/ws", "query_string": self.query.encode(), "headers": [],
                 "scheme": "ws", "server": ("test", 80), "client": ("phone", 1), "root_path": "",
                 "subprotocols": []}
        self.inbox.put_nowait({"type": "websocket.connect"})
        return asyncio.create_task(self.app(scope, self.receive, self.send))

    def cmd(self, cmd, **args):
        self.inbox.put_nowait({"type": "websocket.receive",
                               "text": json.dumps({"cmd": cmd, "args": args, "req_id": cmd})})

    async def audio(self, signal, speed=4.0):          # like a phone: chunk by chunk, 4× real time
        for i in range(0, len(signal), BROWSER_CHUNK):
            self.inbox.put_nowait({"type": "websocket.receive", "bytes": encode_pcm16(signal[i:i + BROWSER_CHUNK])})
            await asyncio.sleep(BROWSER_CHUNK / SR / speed)

    def hang_up(self):
        self.inbox.put_nowait({"type": "websocket.disconnect", "code": 1000})

    def messages(self):
        return [json.loads(m["text"]) for m in self.got if m["type"] == "websocket.send"]

    def replies(self):
        return {m["req_id"]: m for m in self.messages() if m["kind"] == "reply"}

    def events(self, kind):
        return [m for m in self.messages() if m["kind"] == "event" and m["type"] == kind]


async def wait_for(cond, timeout=5.0):
    t0 = time.time()
    while not cond() and time.time() - t0 < timeout:
        await asyncio.sleep(0.02)
    return cond()


def fake_system():
    fw = FakeWhisper()
    return build_system(EnergyTestVAD, threaded=True, whisper_factory=lambda: fw, partials=True)


def test_phone_talks_and_gets_text_back():
    async def scenario():
        ctl = fake_system()
        phone = FakePhone(create_app(ctl))
        task = phone.start()
        phone.cmd("env.on")
        phone.cmd("conversation.start")
        assert await wait_for(lambda: "conversation.start" in phone.replies())
        await phone.audio(place(room(6.0), speechlike(2.0), 2.0))     # someone speaks for 2 s
        assert await wait_for(lambda: phone.events("transcript"))
        phone.cmd("conversation.end")
        phone.hang_up()
        await asyncio.wait_for(task, 5)
        r = phone.replies()
        assert r["env.on"]["ok"] and r["conversation.start"]["data"] == {"conversation_id": 1}
        tr = phone.events("transcript")
        assert len(tr) == 1 and tr[0]["code"] == "ok" and tr[0]["data"]["text"] == "<2.6s>"
        assert tr[0]["channel"] == "conversation"
        assert phone.events("transcript_partial")                    # live words came first
        assert not ctl.env_on                                         # phone hung up → everything stopped
        ctl.shutdown()
    asyncio.run(scenario())


def test_wrong_token_is_refused():
    async def scenario():
        ctl = fake_system()
        phone = FakePhone(create_app(ctl, token="secret"), query="token=wrong")
        await asyncio.wait_for(phone.start(), 5)
        assert phone.got[0] == {"type": "websocket.close", "code": 4401, "reason": ""}
        ctl.shutdown()
    asyncio.run(scenario())


def test_channel_filter_and_bad_command():
    async def scenario():
        ctl = fake_system()
        phone = FakePhone(create_app(ctl, token="secret"), query="token=secret&channels=conversation")
        task = phone.start()
        phone.cmd("env.on")
        phone.cmd("dance")
        phone.cmd("conversation.start")
        assert await wait_for(lambda: "conversation.start" in phone.replies())
        phone.hang_up()
        await asyncio.wait_for(task, 5)
        assert phone.replies()["dance"]["error"]["code"] == "UNKNOWN_CMD"
        evs = [m for m in phone.messages() if m["kind"] == "event"]
        assert evs and all(e["channel"] == "conversation" for e in evs)   # no home / system events
        ctl.shutdown()
    asyncio.run(scenario())