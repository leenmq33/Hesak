import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../home_mic_service.dart';

// =====================================================================
//  SPEECH-TO-TEXT (Faster-Whisper on the Hesak server).
//
//  The phone does NOT open a second microphone: it takes the sound that
//  HomeMicService already records (16 kHz, PCM16) and sends it to the server
//  over ONE WebSocket. The server (backend/server.py) answers with text.
//
//    phone ──audio bytes──► server  (Silero finds sentences, Whisper writes them)
//    phone ◄──"transcript"── server (one finished sentence)
//
//  The server (Modal) SLEEPS when nobody uses it. Waking it takes ~1-2 min.
//  So: warmUp() wakes it early (when the chats screen opens), and start()
//  waits for it patiently instead of failing after a few seconds.
//
//  Server address: HESAK_SERVER_URL in env.json, e.g. "wss://….modal.run"
//  Optional:       HESAK_SERVER_TOKEN (only if the server sets HESAK_TOKEN)
//  Run with:       flutter run --dart-define-from-file=env.json
//
//  Used by: the mic button inside a conversation (chats_conversation_screen.dart).
// =====================================================================

/// Turns what is heard in a conversation into text (server side).
class HesakSpeechToTextService {
  HesakSpeechToTextService._();
  static final HesakSpeechToTextService instance = HesakSpeechToTextService._();

  static const String _serverUrl = String.fromEnvironment('HESAK_SERVER_URL');
  static const String _token = String.fromEnvironment('HESAK_SERVER_TOKEN');
  static const Duration _replyTimeout = Duration(seconds: 15);
  static const Duration _wakeTimeout = Duration(minutes: 4);      // longest wait for a sleeping server
  static const Duration _connectTimeout = Duration(seconds: 30);  // one WebSocket try (server already awake)
  static const Duration _stillAwake = Duration(minutes: 15);      // server sleeps 20 min after last use -> trust 15

  /// true when env.json has a server address (otherwise the screen keeps its demo).
  bool get isConnected => _serverUrl.isNotEmpty;

  /// Faster-Whisper runs on the server -> internet is required to start.
  bool get needsInternet => true;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _serverSub;
  StreamSubscription<Uint8List>? _micSub;
  final Map<String, Completer<Map<String, dynamic>>> _waiting = {};
  int _nextRequest = 0;
  int _session = 0; // +1 on every start/stop -> an old start that finishes late is ignored
  void Function(String text)? _onText;
  void Function(String confirmed, String pending)? _onLive;
  void Function()? _onConnectionLost;

  Future<bool>? _waking;   // one wake-up at a time, shared by everyone who asks
  DateTime? _lastAwake;    // last time we know the server was awake

  /// The server address without a trailing "/".
  String get _base => _serverUrl.endsWith('/')
      ? _serverUrl.substring(0, _serverUrl.length - 1)
      : _serverUrl;

  /// wss://x/health -> https://x/health  (ws:// -> http:// for a local server)
  Uri get _healthUri => Uri.parse('${_base.replaceFirst(RegExp(r'^wss://'), 'https://').replaceFirst(RegExp(r'^ws://'), 'http://')}/health');

  // ---------------------------------------------------------------
  // Waking the server
  // ---------------------------------------------------------------

  /// Wakes the server up if it is sleeping. Safe to call many times:
  /// returns at once if the server was awake a moment ago, and shares one
  /// wake-up if several screens ask together. true = the server answered.
  Future<bool> warmUp() {
    if (!isConnected) return Future<bool>.value(false);
    final DateTime? last = _lastAwake;
    if (last != null && DateTime.now().difference(last) < _stillAwake) {
      return Future<bool>.value(true);
    }
    return _waking ??= _wake().whenComplete(() => _waking = null);
  }

  /// Asks /health until the server answers (max [_wakeTimeout]).
  Future<bool> _wake() async {
    final HttpClient client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    final DateTime deadline = DateTime.now().add(_wakeTimeout);
    debugPrint('🟡 [STT] waking the server…');
    try {
      while (DateTime.now().isBefore(deadline)) {
        try {
          final HttpClientRequest req = await client.getUrl(_healthUri);
          req.followRedirects = true; // Modal answers "303 come back later" while it starts
          req.maxRedirects = 20;
          Duration left = deadline.difference(DateTime.now());
          if (left < const Duration(seconds: 5)) left = const Duration(seconds: 5);
          final HttpClientResponse res = await req.close().timeout(left);
          final String body = await res.transform(utf8.decoder).join();
          if (res.statusCode == 200 && body.contains('"ok"')) {
            _lastAwake = DateTime.now();
            debugPrint('🟢 [STT] server awake');
            return true;
          }
          debugPrint('🟠 [STT] wake: HTTP ${res.statusCode}');
        } catch (e) {
          debugPrint('🟠 [STT] wake: $e');
        }
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      debugPrint('🔴 [STT] server did not wake up in ${_wakeTimeout.inMinutes} min');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  // ---------------------------------------------------------------
  // Start / stop
  // ---------------------------------------------------------------

  /// Connects to the server and starts sending the microphone.
  /// [onText] gets each finished sentence. [onLive] (optional) gets the words
  /// of the sentence still being spoken. [onConnectionLost] is called if the
  /// server goes away while listening. [onStatus] (optional) is told
  /// 'waking' (server is starting, can take ~1-2 min), 'connecting', 'listening'.
  Future<void> start({
    required void Function(String text) onText,
    void Function(String confirmed, String pending)? onLive,
    void Function()? onConnectionLost,
    void Function(String status)? onStatus,
  }) async {
    if (!isConnected) {
      throw StateError('HESAK_SERVER_URL is missing in env.json');
    }
    await stop();
    final int my = ++_session;
    _onText = onText;
    _onLive = onLive;
    _onConnectionLost = onConnectionLost;

    // 1) make sure the server is awake (instant if it already is)
    onStatus?.call('waking');
    final bool awake = await warmUp();
    if (my != _session) return; // stop() was pressed while waiting
    if (!awake) {
      throw TimeoutException('the server did not wake up');
    }

    // 2) open the WebSocket (3 tries, in case the first one is unlucky)
    onStatus?.call('connecting');
    final Uri uri = Uri.parse('$_base/ws').replace(queryParameters: {
      'rate': '16000',
      'channels': 'conversation',
      if (_token.isNotEmpty) 'token': _token,
    });
    debugPrint('🟢 [STT] connecting to ${uri.replace(queryParameters: {'rate': '16000'})}'); // no token in the log
    WebSocketChannel? channel;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final WebSocketChannel c = WebSocketChannel.connect(uri);
        await c.ready.timeout(_connectTimeout);
        channel = c;
        break;
      } catch (e) {
        debugPrint('🟠 [STT] connect try $attempt: $e');
        if (attempt == 3 || my != _session) rethrow;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    if (my != _session) {
      await channel?.sink.close();
      return;
    }
    _channel = channel;
    _lastAwake = DateTime.now();
    _serverSub = channel!.stream.listen(
      _onMessage,
      onDone: _onClosed,
      onError: (Object e) => _onClosed(),
    );

    await _send('env.on');
    await _send('conversation.start');
    if (my != _session) return; // stop() was pressed while connecting

    // The same sound the home mic already records -> straight to the server.
    _micSub = HomeMicService.instance.audio.listen((Uint8List bytes) {
      _channel?.sink.add(bytes);
    });
    onStatus?.call('listening');
    debugPrint('🟢 [STT] listening');
  }

  /// Stops sending the mic. Waits for the last sentences' text,
  /// then closes the connection.
  Future<void> stop() async {
    _session++;
    await _micSub?.cancel();
    _micSub = null;
    final WebSocketChannel? channel = _channel;
    if (channel == null) return;
    try {
      await _send('conversation.end');
      // Every sentence already heard must still arrive -> wait until the server
      // has written ALL of them (safety limit: 2 minutes).
      for (int i = 0; i < 600; i++) {
        final Map<String, dynamic> st = await _send('status.get');
        final Map<String, dynamic> p = (st['pipeline'] as Map).cast<String, dynamic>();
        if (p['whisper_waiting'] == 0 && p['whisper_busy'] == false) break;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      debugPrint('🟠 [STT] stop: $e');
    }
    _channel = null; // from here a closed connection is expected, not "lost"
    _lastAwake = DateTime.now(); // the server stays awake ~20 min after this
    await _serverSub?.cancel();
    _serverSub = null;
    await channel.sink.close();
    _failWaiting('stopped');
    debugPrint('⚪ [STT] stopped');
  }

  // ---------------------------------------------------------------
  // Talking to the server
  // ---------------------------------------------------------------

  /// Sends one API command (same messages as the Colab page) and waits for its reply.
  Future<Map<String, dynamic>> _send(String cmd, [Map<String, dynamic>? args]) async {
    final WebSocketChannel? channel = _channel;
    if (channel == null) throw StateError('not connected');
    final String id = 'r${++_nextRequest}';
    final Completer<Map<String, dynamic>> done = Completer<Map<String, dynamic>>();
    _waiting[id] = done;
    channel.sink.add(jsonEncode({'cmd': cmd, 'args': args ?? {}, 'req_id': id}));
    final Map<String, dynamic> reply = await done.future.timeout(_replyTimeout, onTimeout: () {
      _waiting.remove(id);
      throw TimeoutException('no reply to $cmd');
    });
    if (reply['ok'] != true) {
      throw StateError('$cmd failed: ${reply['error']}');
    }
    return (reply['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  }

  /// Every message from the server: a reply to a command, or a pushed event.
  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    final Map<String, dynamic> m = (jsonDecode(raw) as Map).cast<String, dynamic>();
    if (m['kind'] == 'reply') {
      _waiting.remove(m['req_id'])?.complete(m);
      return;
    }
    if (m['kind'] != 'event') return;
    final Map<String, dynamic> data = (m['data'] as Map?)?.cast<String, dynamic>() ?? {};
    if (m['type'] == 'transcript' && m['code'] == 'ok') {
      final String text = (data['text'] as String? ?? '').trim();
      if (text.isNotEmpty) _onText?.call(text);
    } else if (m['type'] == 'transcript_partial') {
      final String confirmed = (data['confirmed'] as String? ?? '').trim();
      final String pending = (data['pending'] as String? ?? '').trim();
      if (confirmed.isNotEmpty || pending.isNotEmpty) _onLive?.call(confirmed, pending);
    }
  }

  /// The connection closed by itself (server stopped, Wi-Fi dropped ...).
  void _onClosed() {
    if (_channel == null) return; // we closed it in stop()
    debugPrint('🔴 [STT] connection lost');
    _session++;
    _micSub?.cancel();
    _micSub = null;
    _channel = null;
    _lastAwake = null; // not sure any more -> wake it properly next time
    _failWaiting('connection lost');
    _onConnectionLost?.call();
  }

  void _failWaiting(String why) {
    for (final Completer<Map<String, dynamic>> c in _waiting.values) {
      if (!c.isCompleted) c.completeError(StateError(why));
    }
    _waiting.clear();
  }
}