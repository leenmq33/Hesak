# Whole-system tests: the button rules  (were: notebook Cell 9, part 1)
# Plays a scripted "day" through the controller exactly like the phone would.
import threading
import time

from hesak.config import SR, BROWSER_CHUNK
from hesak.audio import encode_like_browser, encode_pcm16
from hesak.controller import build_system
from hesak.listening import EnergyTestVAD
from sounds import room, knock, place, speechlike


def feed(ctl, signal):
    for i in range(0, len(signal), BROWSER_CHUNK):
        ctl.on_audio(encode_like_browser(signal[i:i + BROWSER_CHUNK]), SR)


def new_events(ctl, since, kind):
    return [e for e in ctl.bus.get_since(since)[0] if e["type"] == kind]


def test_no_conversation_and_no_audio_while_environment_is_off():
    ctl = build_system(EnergyTestVAD, threaded=False)
    assert ctl.conv_start() == {"ok": False, "error": "ENV_OFF"}
    feed(ctl, room(1.0))
    assert ctl.ring.total_written == 0 and ctl.ignored_chunks > 0


def test_a_whole_day():
    ctl = build_system(EnergyTestVAD, threaded=False)

    # Home: environment ON → knock → only YAMNet
    ctl.env_start()
    feed(ctl, place(room(8.0), knock(), 5.0))
    assert ctl.yamnet_box.sent >= 1 and ctl.whisper_box.sent == 0

    # Conversation 1: two sentences + a knock in the middle
    mark = ctl.bus.last_id
    assert ctl.conv_start()["ok"]
    y0 = ctl.yamnet_box.sent
    feed(ctl, place(place(place(room(12.0), speechlike(2.0), 1.0), speechlike(3.0), 5.0), knock(0.6), 10.0))
    ctl.conv_stop()
    stt = new_events(ctl, mark, "stt_request")
    assert len(stt) == 2 and all(e["details"]["conversation_id"] == 1 for e in stt)
    assert ctl.yamnet_box.sent > y0                         # environment kept working
    assert ctl.env_on and ctl.env.running                   # ending a conversation keeps the environment
    yam = new_events(ctl, mark, "env_request")
    assert not any((e["start_s"] < 11.0 and e["end_s"] > 9.0) or (e["start_s"] < 16.0 and e["end_s"] > 13.0)
                   for e in yam)                            # speech never went to YAMNet
    assert any(e["details"]["reason"] == "onset" and abs(e["start_s"] - 17.5) < 0.3 for e in yam)

    # Conversation 2: environment switched OFF mid-sentence → the sentence is still sent
    ctl.conv_start()
    feed(ctl, place(room(4.0), speechlike(5.0), 1.0)[: int(3.5 * SR)])
    mark = ctl.bus.last_id
    ctl.env_stop()
    tail = ctl.bus.get_since(mark)[0]
    assert [e["type"] for e in tail][:3] == ["stt_request", "speech_ended", "conversation_ended"]
    assert tail[0]["details"]["conversation_id"] == 2 and tail[0]["details"]["reason"] == "stop"
    assert not (ctl.env_on or ctl.env.running or ctl.conv.running)

    # Restart: new session number, clock from 0
    old = ctl.ring.generation
    ctl.env_start()
    assert ctl.ring.generation == old + 1 and ctl.ring.total_written == 0
    ctl.env_stop()


def test_raw_bytes_from_the_phone_work_like_base64():                    # NEW (server path)
    ctl = build_system(EnergyTestVAD, threaded=False)
    ctl.env_start()
    ctl.conv_start()
    sig = place(room(6.0), speechlike(2.0), 2.0)
    for i in range(0, len(sig), BROWSER_CHUNK):
        assert ctl.on_audio_bytes(encode_pcm16(sig[i:i + BROWSER_CHUNK]), SR)
    ctl.conv_stop()
    assert ctl.whisper_box.sent == 1
    ctl.env_stop()


def test_threaded_like_live_4x_speed():
    before = {t.name for t in threading.enumerate()}
    ctl = build_system(EnergyTestVAD, threaded=True)
    ctl.env_start()
    ctl.conv_start()
    sig = place(place(place(room(20.0), speechlike(3.0), 4.0), knock(), 9.0), speechlike(2.0), 12.0)
    for i in range(0, len(sig), BROWSER_CHUNK):
        ctl.on_audio(encode_like_browser(sig[i:i + BROWSER_CHUNK]), SR)
        time.sleep(BROWSER_CHUNK / SR / 4)
    time.sleep(0.3)
    st = ctl.status(0)
    ctl.env_stop()
    left = [t.name for t in threading.enumerate() if t.name.startswith("hesak-") and t.name not in before]
    assert ctl.whisper_box.sent == 2
    assert st["errors"] == 0 and st["env"]["lag_s"] < 1.0
    assert left == []