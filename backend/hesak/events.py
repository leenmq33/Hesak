
# ============================================================
# HESAK backend — events.py : EventBus + hand-off queues  (was: notebook Cell 3)
# ------------------------------------------------------------
#   EventBus   = a notice board. Small JSON messages, NO audio. Everyone can read every message.
#   Handoff    = a mailbox. Requests WITH audio. Each request is taken out ONCE (by Whisper).
#   LatestSlot = holds only the NEWEST live (partial) request.
# ============================================================
import collections
import json
import queue
import threading
import time

from .config import SR, EVENT_HISTORY_MAX, HANDOFF_MAX

# The only event names allowed. A typo is rejected instead of silently getting lost.
EVENT_TYPES = (
    "system",
    # environment path
    "activity_started", "activity_ended", "env_request",
    # conversation path
    "conversation_started", "conversation_ended",
    "speech_started", "speech_ended", "stt_request",
    # Whisper results
    "transcript",                     # final text of a sentence
    "transcript_partial",             # live words while the sentence is still being spoken
)


class EventBus:
    """Thread-safe notice board. publish() by producers, get_since(last_id) by readers.
    Reading never removes events; each reader keeps its own last_id."""

    def __init__(self, max_history=EVENT_HISTORY_MAX):
        self._lock = threading.Lock()
        self._history = collections.deque(maxlen=max_history)   # the oldest fall off
        self._next_id = 1
        self._listeners = []

    # Add one event. Times come in as samples and are stored as seconds.
    def publish(self, event_type, label, session, start_sample=None, end_sample=None, details=None):
        if event_type not in EVENT_TYPES:
            raise ValueError(f"unknown event type: {event_type}")
        event = {
            "id": None, "type": event_type, "label": str(label), "session": int(session),
            "start_s": None if start_sample is None else round(start_sample / SR, 3),
            "end_s": None if end_sample is None else round(end_sample / SR, 3),
            "wall_time": time.time(), "details": dict(details or {}),
        }
        json.dumps(event)                                 # fail early if not JSON-safe
        with self._lock:
            event["id"] = self._next_id                   # ids given inside the lock → never shared
            self._next_id += 1
            self._history.append(event)
            listeners = list(self._listeners)
        for fn in listeners:                              # push to live listeners (the server)
            try:
                fn(event)
            except Exception:
                pass
        return event

    # 'Give me everything after event N' + how many I missed (if the history was too short).
    def get_since(self, last_id):
        with self._lock:
            events = [e for e in self._history if e["id"] > last_id]
            oldest = self._history[0]["id"] if self._history else self._next_id
        return events, max(0, oldest - 1 - last_id)

    @property
    def last_id(self):
        with self._lock:
            return self._next_id - 1

    # NEW (server): call fn(event) for every new event. Returns a function that stops it.
    def subscribe(self, fn):
        with self._lock:
            self._listeners.append(fn)

        def unsubscribe():
            with self._lock:
                if fn in self._listeners:
                    self._listeners.remove(fn)
        return unsubscribe


class Handoff:
    """Bounded queue of requests for one model. When full, the OLDEST request is dropped.
    Also keeps a copy of the last few requests for listening back."""

    def __init__(self, name, maxsize=HANDOFF_MAX, keep=20):
        self.name = name
        self.q = queue.Queue(maxsize=maxsize)
        self.recent = collections.deque(maxlen=keep)
        self.sent = 0
        self.dropped = 0
        self._lock = threading.Lock()

    def put(self, item):
        with self._lock:
            while True:
                try:
                    self.q.put_nowait(item)
                    break
                except queue.Full:
                    try:
                        self.q.get_nowait()
                        self.dropped += 1
                    except queue.Empty:
                        pass
            self.sent += 1
            self.recent.append(item)

    def get(self, timeout=None):
        return self.q.get(timeout=timeout)

    def size(self):
        return self.q.qsize()


class LatestSlot:
    """Holds only the NEWEST live request. A newer one replaces an older one."""

    def __init__(self):
        self._lock = threading.Lock()
        self._item = None
        self.replaced = 0

    def put(self, item):
        with self._lock:
            if self._item is not None:
                self.replaced += 1
            self._item = item

    def take(self):
        with self._lock:
            item, self._item = self._item, None
            return item

    # Throw away the waiting partial of a sentence that has just been finished.
    def clear(self, key=None):
        with self._lock:
            if self._item is not None and (key is None or self._item["key"] == key):
                self._item = None
                