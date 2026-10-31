# ============================================================
# HESAK backend — server.py : the bridge between the phone and the system (WebSocket)
# ------------------------------------------------------------
#   📱 Flutter ──WebSocket /ws──► server.py ──► HesakAPI (api.py) ──► Gate → Silero → Whisper
#
#   Phone → server
#     • binary frame = raw audio: PCM16, mono, little-endian (the `record` package's pcm16bits stream)
#     • text frame   = an API message, the SAME as in Colab:  {"cmd": "env.on", "req_id": "1"}
#   Server → phone (text frames, JSON)
#     • {"kind": "reply", "api": "1.0", "req_id": "1", "ok": true, "data": {...}}   ← answer to a command
#     • {"kind": "event", "type": "transcript", "code": "ok", "data": {"text": ...}, ...}   ← pushed live
#
#   Connect:  ws://HOST:8000/ws?rate=16000&token=SECRET
#     rate     sample rate of the binary audio (default 16000)
#     token    required only if the HESAK_TOKEN environment variable is set on the server
#     channels optional filter, e.g. channels=conversation,system (default: every event)
#   Health:   GET http://HOST:8000/health
#
#   Run:  python server.py              → real Silero + real Whisper (GPU if there is one)
#         python server.py --fake       → fake speech detector + fake Whisper (no models, for app testing)
# ============================================================
import argparse
import asyncio
import json
import os

from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route, WebSocketRoute

from hesak.config import SR
from hesak.api import HesakAPI, API_VERSION
from hesak.controller import build_system


def create_app(controller, info=None, token=None):
    """One ASGI app around ONE system. Used by main() and by the tests."""
    api = HesakAPI(controller)
    clients = {"n": 0}
    info = dict(info or {})

    async def health(request):
        return JSONResponse({"ok": True, "api": API_VERSION, "clients": clients["n"], **info})

    async def ws_endpoint(ws):
        if token and ws.query_params.get("token") != token:
            await ws.close(code=4401)                              # wrong / missing token
            return
        try:
            rate = int(ws.query_params.get("rate", SR))
        except ValueError:
            rate = SR
        wanted = {c for c in ws.query_params.get("channels", "").split(",") if c} or None
        await ws.accept()
        clients["n"] += 1

        loop = asyncio.get_running_loop()
        outbox = asyncio.Queue()
        send_lock = asyncio.Lock()

        async def send(obj):
            async with send_lock:                                  # one frame at a time
                await ws.send_text(json.dumps(obj, ensure_ascii=False))

        # Every new event on the notice board → pushed to this phone (from any thread).
        def on_event(e):
            loop.call_soon_threadsafe(outbox.put_nowait, e)
        unsubscribe = controller.bus.subscribe(on_event)

        async def pusher():
            while True:
                ev = HesakAPI._event(await outbox.get())
                if wanted is None or ev["channel"] in wanted:
                    await send({"kind": "event", **ev})
        push_task = asyncio.create_task(pusher())

        try:
            while True:
                msg = await ws.receive()
                if msg["type"] == "websocket.disconnect":
                    break
                if msg.get("bytes") is not None:                   # audio
                    controller.on_audio_bytes(msg["bytes"], rate)
                elif msg.get("text") is not None:                  # a command
                    await send({"kind": "reply", **api.handle(msg["text"])})
        except Exception:
            pass                                                   # connection lost
        finally:
            unsubscribe()
            push_task.cancel()
            clients["n"] -= 1
            if clients["n"] == 0:
                controller.env_stop()                              # phone gone → close the conversation cleanly

    return Starlette(routes=[Route("/health", health), WebSocketRoute("/ws", ws_endpoint)])


# Build the system: real models, or fakes for testing the app without a GPU.
def make_system(fake=False):
    if fake:
        from hesak.listening import EnergyTestVAD
        from hesak.whisper_stt import FakeWhisper
        backend = FakeWhisper()
        ctl = build_system(EnergyTestVAD, threaded=True, whisper_factory=lambda: backend, partials=True)
        return ctl, {"mode": "fake"}
    from hesak.listening import SileroStream
    from hesak.whisper_stt import load_whisper
    print("Loading Whisper (first time downloads the model — a few minutes)…", flush=True)
    backend, settings = load_whisper()
    print(f"✅ Whisper {backend.size} on {settings['device']} | loaded in {backend.load_s}s", flush=True)
    SileroStream()                                                 # load Silero now, not on the first conversation
    ctl = build_system(SileroStream, threaded=True, whisper_factory=lambda: backend,
                       partials=settings["partials"])
    ctl.whisper.load()
    return ctl, {"mode": "real", "whisper": backend.size, **settings}


def main():
    p = argparse.ArgumentParser(description="Hesak speech-to-text server")
    p.add_argument("--host", default="0.0.0.0")
    p.add_argument("--port", type=int, default=8000)
    p.add_argument("--fake", action="store_true", help="no models: fake speech detector + fake Whisper")
    a = p.parse_args()
    ctl, info = make_system(a.fake)
    app = create_app(ctl, info, token=os.environ.get("HESAK_TOKEN") or None)
    import uvicorn
    print(f"🟢 Hesak server: ws://{a.host}:{a.port}/ws   health: http://{a.host}:{a.port}/health", flush=True)
    try:
        uvicorn.run(app, host=a.host, port=a.port, log_level="warning")
    finally:
        ctl.shutdown()


if __name__ == "__main__":
    main()