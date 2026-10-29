import 'dart:collection';

// =====================================================================
//  HOME ACTIVITY GATE — decides "a new sound started / ended" from the
//  loudness of the microphone, compared to the room's normal noise.
//
//  Used by: HomeMicService (gives it one loudness value every 32 ms).
//  Same logic as ActivityGate in the team's sound notebook.
//
//  How it works:
//   1) Warm-up (3 s): only learns how loud the quiet room is (the "floor").
//   2) Louder than the floor by 6 dB -> sound STARTS (open event).
//   3) Back near the floor for ~300 ms -> sound ENDS (close event).
//   4) A sound longer than 20 s becomes the new normal room noise.
// =====================================================================

/// Sound started (open) or sound ended (close).
enum HomeGateEventType { open, close }

/// One notice from the gate: sound started or sound ended.
class HomeGateEvent {
  final HomeGateEventType type;
  final double durationSeconds; // only used when the sound ended
  final String reason; // quiet | rebaseline
  const HomeGateEvent(this.type, {this.durationSeconds = 0, this.reason = ''});
}

/// Detects "there is a sound" above the room's background noise.
class HomeActivityGate {
  static const int sampleRate = 16000; // Mic samples per second
  static const int frameSize = 512; // 32 ms per frame

  // ---- Settings (from the notebook) ----
  static const int _bgFrames = 94; // 3 s warm-up
  static const double _bgPercentile = 20; // The floor = the quietest 20% of frames
  static const int _bgUpdateFrames = 8; // Update the floor every 8 quiet frames
  static const double _openDb = 6.0; // Louder than the floor by this -> sound starts
  static const double _closeDb = 3.0; // Below this rise -> counts as quiet again
  static const double _minDbfs = -70.0; // Quieter than this is never a sound
  static const int _holdFrames = 10; // about 300 ms
  static const int _rebaselineFrames = 625; // 20 s
  static const double _digitalSilenceDb =
      -99.0; // All-zero frames = mic glitch, not the room

  ListQueue<double> _hist = ListQueue(); // quiet frames -> floor
  final ListQueue<double> _recent = ListQueue(); // all frames -> rebaseline
  int _sinceUpdate = 0; // Quiet frames since the last floor update
  int _frames = 0; // Frames since the mic opened
  int _segStart = 0; // Frame where the current sound started
  int _lastAbove = 0; // Last frame that was still loud

  double? floorDb; // The room's normal loudness (null = not known yet)
  double? levelDb; // Loudness of the last frame
  bool active = false; // true while a sound is going on

  /// true during the 3 s warm-up (HomeMicStatus.warming on الرئيسية).
  bool get warming => _frames < _bgFrames;

  /// Forgets everything (called when the mic opens / closes).
  void reset() {
    _hist = ListQueue();
    _recent.clear();
    _sinceUpdate = 0;
    _frames = 0;
    _segStart = 0;
    _lastAbove = 0;
    floorDb = null;
    levelDb = null;
    active = false;
  }

  /// Call once per 512-sample frame with its level in dB.
  /// Returns an event when a sound starts / ends, otherwise null.
  HomeGateEvent? process(double eDb) {
    _frames++;
    levelDb = eDb;
    // Pure digital silence is a mic glitch: never learn the room from it.
    final bool isDigitalSilence = eDb <= _digitalSilenceDb;
    if (!isDigitalSilence) {
      _recent.addLast(eDb);
      if (_recent.length > _bgFrames) _recent.removeFirst();
    }

    // Warm-up: only learn the room
    if (_frames <= _bgFrames) {
      if (!isDigitalSilence) _learn(eDb, force: _frames == _bgFrames);
      return null;
    }
    if (!active && !isDigitalSilence) {
      _learn(eDb); // learn from quiet frames only
    }
    if (floorDb == null) return null; // Nothing real heard yet

    final rise = eDb - floorDb!; // How much louder than the room
    final loud = eDb >= _minDbfs;

    // ---- Quiet now: does a sound start? ----
    if (!active) {
      if (loud && rise >= _openDb) {
        active = true;
        _segStart = _frames;
        _lastAbove = _frames;
        return const HomeGateEvent(HomeGateEventType.open);
      }
      return null;
    }

    // ---- A sound is going on: is it over? ----
    if (loud && rise >= _closeDb) {
      _lastAbove = _frames;
    } else if (_frames - _lastAbove >= _holdFrames) {
      return _close('quiet', _lastAbove);
    }

    // A very long sound becomes the new background
    if (_frames - _segStart >= _rebaselineFrames && _recent.isNotEmpty) {
      _hist = ListQueue.from(_recent);
      floorDb = _percentile(_hist, _bgPercentile);
      _sinceUpdate = 0;
      return _close('rebaseline', _frames);
    }
    return null;
  }

  /// Ends the current sound and returns the close event (with its length).
  HomeGateEvent _close(String reason, int endFrame) {
    final seconds = (endFrame - _segStart + 1) * frameSize / sampleRate;
    active = false;
    return HomeGateEvent(
      HomeGateEventType.close,
      durationSeconds: seconds,
      reason: reason,
    );
  }

  /// Adds a quiet frame to the room history and updates the floor
  /// every few frames. [force] = update now (end of the warm-up).
  void _learn(double db, {bool force = false}) {
    _hist.addLast(db);
    if (_hist.length > _bgFrames) _hist.removeFirst();
    _sinceUpdate++;
    if (force ||
        _sinceUpdate >= _bgUpdateFrames ||
        (floorDb == null && _hist.length >= _bgUpdateFrames)) {
      floorDb = _percentile(_hist, _bgPercentile);
      _sinceUpdate = 0;
    }
  }

  /// The value below which [p]% of [values] fall (e.g. p = 20).
  double _percentile(Iterable<double> values, double p) {
    final s = values.toList()..sort();
    final pos = (s.length - 1) * p / 100;
    final lo = pos.floor();
    final hi = pos.ceil();
    return s[lo] + (s[hi] - s[lo]) * (pos - lo);
  }
}
