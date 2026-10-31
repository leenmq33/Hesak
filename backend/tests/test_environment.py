# Tests for the Gate (hesak/listening.py, part 1)  (were: notebook Cell 5 TEST 1–4)
import numpy as np

from hesak.config import SR, ENV_IDLE_CHECK_S
from sounds import room, knock, beeping_alarm, place, run_env, reasons, _rng


def test_quiet_room_opens_nothing():                                    # TEST 1
    _, acts, reqs, _ = run_env(room(25.0))
    assert acts == []
    assert set(reasons(reqs)) == {"idle_check"}


def test_knock_is_caught_with_its_preroll():                            # TEST 2
    _, acts, reqs, inbox = run_env(place(room(10.0), knock(), 5.0))
    onset = [r for r in reqs if r["details"]["reason"] == "onset"]
    assert len(acts) == 1 and len(onset) == 1
    assert abs(onset[0]["start_s"] - 4.5) < 0.05 and abs(onset[0]["end_s"] - 5.5) < 0.05
    assert len(inbox.recent[0]["audio"]) == SR


def test_long_alarm_keeps_being_checked_and_a_knock_after_it_is_caught():   # TEST 3
    sig = place(place(room(45.0), beeping_alarm(30.0), 5.0), knock(0.6), 40.0)
    _, acts, reqs, _ = run_env(sig)
    during = [r for r in reqs if 5.0 <= r["start_s"] < 35.0]
    assert len(during) >= 5
    assert all(b["start_s"] - a["start_s"] <= ENV_IDLE_CHECK_S + 0.1 for a, b in zip(during, during[1:]))
    assert any(abs(a["start_s"] - 40.0) < 0.2 for a in acts)


def test_steady_noise_becomes_background_and_a_knock_on_top_is_caught():   # TEST 4
    steady = (0.02 * _rng.standard_normal(int(30 * SR))).astype(np.float32)   # AC / rain
    _, acts, _, _ = run_env(place(place(room(50.0), steady, 5.0), knock(0.6), 30.0))
    assert any(a["details"]["reason"] == "rebaseline" for a in acts)
    assert any(abs(a["start_s"] - 30.0) < 0.2 for a in acts)