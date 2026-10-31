# Tests for Silero + the conversation path (hesak/listening.py, part 2)
# (were: notebook Cell 6 TEST 1–8 and Cell 14 TEST 17)
import numpy as np
import pytest

from hesak.config import SR, STT_PRE_PAD_S, STT_POST_PAD_S, CONV_ALWAYS_LISTEN
from hesak.listening import EnergyTestVAD, SileroStream, SILERO_AVAILABLE
from sounds import room, knock, place, speechlike, run_conv, reasons


def speech_s(reqs):
    return [round(r["details"]["speech_s"], 1) for r in reqs]


def test_two_sentences_give_two_requests_with_padding():                 # TEST 1
    _, reqs, _, _, _ = run_conv(place(place(room(12.0), speechlike(2.0), 2.0), speechlike(3.0), 6.0),
                                EnergyTestVAD)
    assert reasons(reqs) == ["silence", "silence"]
    assert speech_s(reqs) == [2.0, 3.0]
    assert abs(reqs[0]["start_s"] - (2.0 - STT_PRE_PAD_S)) < 0.05
    assert abs(reqs[0]["end_s"] - (4.0 + STT_POST_PAD_S)) < 0.05


def test_long_speech_is_split_every_15s():                               # TEST 2
    _, reqs, _, _, _ = run_conv(place(room(40.0), speechlike(35.0), 2.0), EnergyTestVAD)
    assert reasons(reqs) == ["max_length", "max_length", "silence"]
    assert speech_s(reqs) == [15.0, 15.0, 5.0]


def test_closing_mid_sentence_still_sends_it():                          # TEST 3
    _, reqs, _, _, _ = run_conv(place(room(15.0), speechlike(10.0), 2.0)[: int(6.0 * SR)], EnergyTestVAD)
    assert reasons(reqs) == ["stop"] and speech_s(reqs) == [4.0]


def test_tiny_blip_is_not_sent():                                        # TEST 4
    _, reqs, _, _, _ = run_conv(place(room(6.0), speechlike(0.15), 2.0), EnergyTestVAD)
    assert reqs == []


SENTENCE_AND_KNOCK = place(place(room(24.0), speechlike(2.0), 6.0), knock(0.6), 15.0)


def test_speech_goes_to_whisper_and_the_knock_to_yamnet():               # TEST 5
    _, reqs, _, env, yam = run_conv(SENTENCE_AND_KNOCK, EnergyTestVAD)
    onsets = [y for y in yam if y["details"]["reason"] == "onset"]
    assert len(reqs) == 1
    assert [round(o["start_s"], 1) for o in onsets] == [14.5]
    assert not [y for y in yam if y["start_s"] < 8.0 and y["end_s"] > 6.0]   # the sentence never reached YAMNet


def test_silero_listens_to_every_frame_during_a_conversation():          # TEST 6
    c, _, _, env, _ = run_conv(SENTENCE_AND_KNOCK, EnergyTestVAD)
    share = c.stats["vad_frames"] / env.stats["frames"]
    assert share > 0.95 if CONV_ALWAYS_LISTEN else share < 0.4


def test_no_conversation_no_whisper():                                   # TEST 7
    c, reqs, _, _, yam = run_conv(SENTENCE_AND_KNOCK, EnergyTestVAD, conv_on=False)
    onsets = [round(y["start_s"], 1) for y in yam if y["details"]["reason"] == "onset"]
    assert reqs == [] and c.stats["vad_frames"] == 0
    assert onsets == [5.5, 14.5]


class BrokenVAD:
    def reset(self):
        pass

    def __call__(self, chunk):
        raise RuntimeError("vad crashed")


def test_silero_crash_does_not_stop_the_rest():                          # TEST 8
    c, reqs, _, _, yam = run_conv(SENTENCE_AND_KNOCK, BrokenVAD)
    assert reqs == [] and c.stats["errors"] > 0
    assert [round(y["start_s"], 1) for y in yam if y["details"]["reason"] == "onset"] == [5.5, 14.5]


def test_far_quiet_speech_is_heard_even_if_the_gate_stays_closed():      # Cell 14 TEST 17
    far = (0.017 * np.sin(2 * np.pi * 220 * np.arange(2 * SR) / SR)).astype(np.float32)   # ≈ −38 dBFS
    _, reqs, _, env, _ = run_conv(place(room(10.0, std=0.01), far, 4.0), lambda: EnergyTestVAD(thr_db=-37.5))
    assert env.stats["activities"] == 0          # the Gate never opened
    assert len(reqs) == (1 if CONV_ALWAYS_LISTEN else 0)


@pytest.mark.skipif(not SILERO_AVAILABLE, reason="silero-vad is not installed")
def test_real_silero_finds_sentences_in_a_real_recording():              # TEST 9 (real model)
    import os
    import torch
    from silero_vad import read_audio
    wav = os.path.join(os.path.dirname(__file__), "silero_en_example.wav")
    if not os.path.exists(wav):
        torch.hub.download_url_to_file("https://models.silero.ai/vad_models/en.wav", wav, progress=False)
    speech = read_audio(wav, sampling_rate=SR).numpy().astype(np.float32)[: 40 * SR]
    c, reqs, _, _, _ = run_conv(np.concatenate([room(1.0), speech, room(1.0)]), SileroStream)
    assert 4 <= len(reqs) <= 12
    assert c.stats["errors"] == 0