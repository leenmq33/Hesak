import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../core/data/hesak_mode_store.dart';
import 'home_activity_gate.dart';
import 'home_alerts_service.dart';

/// What the microphone is doing right now (shown on the home page).
enum HomeMicStatus { off, warming, quiet, active, noPermission }

/// Opens / closes the microphone by itself when listening turns on / off
/// (HesakModeStore.isListening), and feeds the gate frame by frame.
/// Each new sound is added to HomeAlertsService.
/// Widgets rebuild with ListenableBuilder(listenable: HomeMicService.instance).
class HomeMicService extends ChangeNotifier {
  HomeMicService._() {
    HesakModeStore.instance.addListener(_syncWithStore);
    _syncWithStore();
  }
  static final HomeMicService instance = HomeMicService._();

  /// How long the light chip stays after a sound ends.
  static const Duration _endedChipTime = Duration(seconds: 1);

  final AudioRecorder _recorder = AudioRecorder();
  final HomeActivityGate _gate = HomeActivityGate();
  final List<int> _pending = []; // Bytes waiting to fill one frame
  StreamSubscription<Uint8List>? _sub;

  bool _isMicOn = false;
  bool _isBusy = false; // true while starting / stopping

  HomeMicStatus _status = HomeMicStatus.off;
  HomeMicStatus get status => _status;

  Timer? _endedTimer;
  bool _isShowingEnded = false;

  /// true for 1 second after a sound ends (light chip).
  bool get isShowingEnded => _isShowingEnded;

  // ---------------------------------------------------------------
  // Follow the listen button (the store)
  // ---------------------------------------------------------------

  Future<void> _syncWithStore() async {
    if (_isBusy) return;
    _isBusy = true;
    try {
      while (HesakModeStore.instance.isListening != _isMicOn) {
        if (HesakModeStore.instance.isListening) {
          final bool isAllowed = await _start();
          if (!isAllowed) {
            _setStatus(HomeMicStatus.noPermission);
            HesakModeStore.instance.setListening(false); // No mic -> listening off
            break;
          }
        } else {
          await _stop();
        }
      }
    } catch (e) {
      debugPrint('🔴 [HomeMicService] mic error: $e');
      _isMicOn = false;
      _setStatus(HomeMicStatus.off);
      if (HesakModeStore.instance.isListening) {
        HesakModeStore.instance.setListening(false);
      }
    } finally {
      _isBusy = false;
    }
  }

  Future<bool> _start() async {
    if (!await _recorder.hasPermission()) return false;
    _gate.reset();
    _pending.clear();
    _clearEndedChip();
    final Stream<Uint8List> stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: HomeActivityGate.sampleRate,
      numChannels: 1,
    ));
    _sub = stream.listen(_onBytes, onError: (e) => debugPrint('🔴 [HomeMicService] stream error: $e'));
    _isMicOn = true;
    _setStatus(HomeMicStatus.warming);
    return true;
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    await _recorder.stop();
    _isMicOn = false;
    _pending.clear();
    _gate.reset();
    _clearEndedChip();
    _setStatus(HomeMicStatus.off);
  }

  void _setStatus(HomeMicStatus next) {
    if (next == _status) return;
    _status = next;
    notifyListeners();
  }

  void _clearEndedChip() {
    _endedTimer?.cancel();
    _endedTimer = null;
    _isShowingEnded = false;
  }

  // ---------------------------------------------------------------
  // Audio -> 32 ms frames -> level in dB -> gate
  // ---------------------------------------------------------------

  void _onBytes(Uint8List bytes) {
    _pending.addAll(bytes);
    const int frameBytes = HomeActivityGate.frameSize * 2; // 16-bit = 2 bytes
    int offset = 0;
    while (_pending.length - offset >= frameBytes) {
      double sum = 0;
      for (int i = 0; i < HomeActivityGate.frameSize; i++) {
        int sample = _pending[offset + 2 * i] | (_pending[offset + 2 * i + 1] << 8);
        if (sample >= 32768) sample -= 65536; // Little-endian signed 16-bit
        final double x = sample / 32768.0;
        sum += x * x;
      }
      offset += frameBytes;
      final double mean = sum / HomeActivityGate.frameSize;
      _onFrame(10 * math.log(mean + 1e-10) / math.ln10);
    }
    if (offset > 0) _pending.removeRange(0, offset);
  }

  void _onFrame(double levelDb) {
    final HomeGateEvent? event = _gate.process(levelDb);
    if (event != null) {
      if (event.type == HomeGateEventType.open) {
        // New sound: dark chip + one alert.
        _clearEndedChip();
        HomeAlertsService.instance.addSound();
      } else {
        // Sound ended: light chip for 1 second, then it disappears.
        _endedTimer?.cancel();
        _isShowingEnded = true;
        _endedTimer = Timer(_endedChipTime, () {
          _isShowingEnded = false;
          notifyListeners();
        });
      }
    }
    final HomeMicStatus next = _gate.warming
        ? HomeMicStatus.warming
        : (_gate.active ? HomeMicStatus.active : HomeMicStatus.quiet);
    // Rebuild only when something changed (not 30 times a second).
    if (event != null || next != _status) {
      _status = next;
      notifyListeners();
    }
  }
}