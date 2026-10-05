import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

// =====================================================================
//  HESAK CONNECTION — is the phone connected to the internet?
//
//  ONE shared object for the whole app (like HesakModeStore):
//    HesakConnection.instance.isOnline   -> true / false right now
//    HesakConnection.instance.checkNow() -> checks again right now
//    addListener(...)                    -> told when it changes
//
//  Started once in HesakMainShell.
//
//  How it checks: it really tries to reach the internet (looks up
//  google.com), every few seconds. No extra package is needed, so it also
//  catches "Wi-Fi is on but there is no internet".
//
//  When the real models are connected (speech-to-text / text-to-speech),
//  their own errors (no reply, timeout) should show the same
//  "لا يوجد اتصال بالإنترنت" window too.
// =====================================================================

class HesakConnection extends ChangeNotifier {
  HesakConnection._(); // Only one in the whole app
  static final HesakConnection instance = HesakConnection._();

  /// How often the connection is checked in the background.
  static const Duration _checkEvery = Duration(seconds: 5);

  /// Longest wait for one check (slower = counted as no internet).
  static const Duration _checkTimeout = Duration(seconds: 4);

  Timer? _timer;
  Future<bool>? _runningCheck; // Shared by callers while a check runs
  bool _isOnline = true;

  /// true = the internet can be reached.
  bool get isOnline => _isOnline;

  /// Starts checking every few seconds (safe to call more than once).
  void start() {
    if (_timer != null) return;
    checkNow();
    _timer = Timer.periodic(_checkEvery, (_) => checkNow());
  }

  /// Checks right now. Returns true when connected.
  /// Callers arriving during a running check wait for that same result.
  Future<bool> checkNow() =>
      _runningCheck ??= _check().whenComplete(() => _runningCheck = null);

  Future<bool> _check() async {
    bool isOnlineNow;
    try {
      final List<InternetAddress> result =
          await InternetAddress.lookup('google.com').timeout(_checkTimeout);
      isOnlineNow = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      isOnlineNow = false; // No internet, or too slow
    }
    if (isOnlineNow != _isOnline) {
      _isOnline = isOnlineNow;
      notifyListeners();
    }
    return _isOnline;
  }
}