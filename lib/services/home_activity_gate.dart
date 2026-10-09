import 'dart:collection';

enum HomeGateEventType { open, close }

/// One notice from the gate: sound started or sound ended
class HomeGateEvent {
  final HomeGateEventType type;
  final double durationSeconds; // only used when the sound ended
  final String reason; // quiet | rebaseline
  const HomeGateEvent(this.type, {this.durationSeconds = 0, this.reason = ''});
}

/// Detects "there is a sound" above the room's background noise
/// (same logic as ActivityGate in the notebook)
class HomeActivityGate {
  static const int sampleRate = 16000;
  static const int frameSize = 512; // 32 ms per frame

  static const int _bgFrames = 94; // 3 s warm-up
  static const double _bgPercentile = 20;
  static const int _bgUpdateFrames = 8;
  static const double _openDb = 6.0;
  static const double _closeDb = 3.0;
  static const double _minDbfs = -70.0;
  static const int _holdFrames = 10; // about 300 ms
  static const int _rebaselineFrames = 625; // 20 s
  static const double _digitalSilenceDb =
      -99.0; // All-zero frames = mic glitch, not the room

  ListQueue<double> _hist = ListQueue(); // quiet frames -> floor
  final ListQueue<double> _recent = ListQueue(); // all frames -> rebaseline
  int _sinceUpdate = 0;
  int _frames = 0;
  int _segStart = 0;
  int _lastAbove = 0;

  double? floorDb;
  double? levelDb;
  bool active = false;

  bool get warming => _frames < _bgFrames;

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

  /// Call once per 512-sample frame with its level in dB
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

    final rise = eDb - floorDb!;
    final loud = eDb >= _minDbfs;

    if (!active) {
      if (loud && rise >= _openDb) {
        active = true;
        _segStart = _frames;
        _lastAbove = _frames;
        return const HomeGateEvent(HomeGateEventType.open);
      }
      return null;
    }

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

  HomeGateEvent _close(String reason, int endFrame) {
    final seconds = (endFrame - _segStart + 1) * frameSize / sampleRate;
    active = false;
    return HomeGateEvent(
      HomeGateEventType.close,
      durationSeconds: seconds,
      reason: reason,
    );
  }

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

  double _percentile(Iterable<double> values, double p) {
    final s = values.toList()..sort();
    final pos = (s.length - 1) * p / 100;
    final lo = pos.floor();
    final hi = pos.ceil();
    return s[lo] + (s[hi] - s[lo]) * (pos - lo);
  }
}
