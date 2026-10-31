# Tests for hesak/events.py  (were: notebook Cell 3 TEST 1–4)
import threading

import pytest

from hesak.events import EventBus, Handoff, LatestSlot


def test_two_producers_at_once_get_unique_ids():                  # TEST 1
    bus, n = EventBus(), 400

    def produce(kind):
        for i in range(n):
            bus.publish(kind, f"{i}", session=1, start_sample=i)

    threads = [threading.Thread(target=produce, args=(k,)) for k in ("env_request", "stt_request")]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    events, _ = bus.get_since(0)
    ids = [e["id"] for e in events]
    assert len(events) == 2 * n
    assert ids == sorted(set(ids))


def test_slow_reader_is_told_what_it_missed():                    # TEST 2
    small = EventBus(max_history=10)
    for i in range(25):
        small.publish("system", i, session=0)
    assert small.get_since(0)[1] == 15


def test_unknown_event_type_is_rejected():                        # TEST 3
    with pytest.raises(ValueError):
        EventBus().publish("bogus", "x", 0)


def test_full_handoff_keeps_the_newest():                         # TEST 4
    h = Handoff("test", maxsize=3)
    for i in range(5):
        h.put({"id": i})
    assert [h.get()["id"] for _ in range(h.size())] == [2, 3, 4]
    assert h.dropped == 2


def test_subscribe_pushes_new_events_and_stops():                 # NEW (used by the server)
    bus, got = EventBus(), []
    stop = bus.subscribe(got.append)
    bus.publish("system", "a", 1)
    stop()
    bus.publish("system", "b", 1)
    assert [e["label"] for e in got] == ["a"]


def test_latest_slot_keeps_only_the_newest():
    s = LatestSlot()
    s.put({"key": 1, "n": 1})
    s.put({"key": 1, "n": 2})
    assert s.take()["n"] == 2 and s.take() is None and s.replaced == 1