import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../core/data/hesak_mode_store.dart';
import 'home_activity_gate.dart';
import 'home_alerts_service.dart';

// =====================================================================
//  HOME MIC SERVICE — the real microphone behind the big listen button.
//
//  Used by: home_screen.dart (shows the mic status under the button).
//  Listens to: HesakModeStore.isListening (on -> mic opens, off -> closes).
//  Sends to:   HomeAlertsService (one new alert for each new sound).
//
//  Flow: mic sound -> small pieces (32 ms) -> loudness -> HomeActivityGate
//        decides "new sound" or "quiet".
//  Works without internet (everything happens on the phone).
//  Widgets rebuild with ListenableBuilder(listenable: HomeMicService.instance).
// =====================================================================

/// What the microphone is doing right now (shown on the home page).
enum HomeMicStatus { off, warming, quiet, active, noPermission }

/// Opens / closes the microphone by itself and feeds the gate frame by frame.
class HomeMicService extends ChangeNotifier {
  HomeMicService._() {
    HesakModeStore.instance.addListener(_syncWithStore);
    _syncWithStore();
  }
  static final HomeMicService instance = HomeMicService._();

  final AudioRecorder _recorder = AudioRecorder();
  final HomeActivityGate _gate = HomeActivityGate();
  final List<int> _pending = []; // Bytes waiting to fill one frame
  StreamSubscription<Uint8List>? _sub;

  bool _isMicOn = false;
  bool _isBusy = false; // true while starting / stopping

  HomeMicStatus _status = HomeMicStatus.off;
  HomeMicStatus get status => _status;

  // ---------------------------------------------------------------
  // Follow the listen button (the store)
  // ---------------------------------------------------------------

  /// Opens or closes the mic so it matches the listen button.
  /// No mic permission -> turns the listen button off.
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

  /// Opens the mic and starts reading the sound. false = no permission.
  Future<bool> _start() async {
    if (!await _recorder.hasPermission()) return false;
    _gate.reset();
    _pending.clear();
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

  /// Closes the mic and clears everything.
  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    await _recorder.stop();
    _isMicOn = false;
    _pending.clear();
    _gate.reset();
    _setStatus(HomeMicStatus.off);
  }

  /// Changes the status and tells the home page (only when it changed).
  void _setStatus(HomeMicStatus next) {
    if (next == _status) return;
    _status = next;
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // Audio -> 32 ms frames -> level in dB -> gate
  // ---------------------------------------------------------------

  /// Cuts the sound into 32 ms pieces and measures how loud each one is.
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

  /// Gives the loudness to the gate. A new sound -> adds one alert.
  void _onFrame(double levelDb) {
    final HomeGateEvent? event = _gate.process(levelDb);
    if (event != null && event.type == HomeGateEventType.open) {
      HomeAlertsService.instance.addSound(); // New sound -> one alert
    }
    final HomeMicStatus next = _gate.warming
        ? HomeMicStatus.warming
        : (_gate.active ? HomeMicStatus.active : HomeMicStatus.quiet);
    // Rebuild only when something changed (not 30 times a second).
    _setStatus(next);
  }
}