import 'dart:async';
import 'dart:convert';
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
//  Server address: HESAK_SERVER_URL in env.json, e.g. "ws://192.168.1.20:8000"
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
  void Function(String words)? _onLive;
  void Function()? _onConnectionLost;

  /// Connects to the server and starts sending the microphone.
  /// [onText] gets each finished sentence. [onLive] (optional) gets the words
  /// of the sentence still being spoken. [onConnectionLost] is called if the
  /// server goes away while listening.
  Future<void> start({
    required void Function(String text) onText,
    void Function(String words)? onLive,
    void Function()? onConnectionLost,
  }) async {
    if (!isConnected) {
      throw StateError('HESAK_SERVER_URL is missing in env.json');
    }
    await stop();
    final int my = ++_session;
    _onText = onText;
    _onLive = onLive;
    _onConnectionLost = onConnectionLost;

    final String base = _serverUrl.endsWith('/')
        ? _serverUrl.substring(0, _serverUrl.length - 1)
        : _serverUrl;
    final Uri uri = Uri.parse('$base/ws').replace(queryParameters: {
      'rate': '16000',
      'channels': 'conversation',
      if (_token.isNotEmpty) 'token': _token,
    });
    debugPrint('🟢 [STT] connecting to $uri');
    final WebSocketChannel channel = WebSocketChannel.connect(uri);
    _channel = channel;
    await channel.ready.timeout(_replyTimeout);
    _serverSub = channel.stream.listen(
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
    debugPrint('🟢 [STT] listening');
  }

  /// Stops sending the mic. Waits (max ~5 s) for the last sentence's text,
  /// then closes the connection.
  Future<void> stop() async {
    _session++;
    await _micSub?.cancel();
    _micSub = null;
    final WebSocketChannel? channel = _channel;
    if (channel == null) return;
    try {
      await _send('conversation.end');
      // The last sentence is still being written on the server -> wait for it.
      for (int i = 0; i < 25; i++) {
        final Map<String, dynamic> st = await _send('status.get');
        final Map<String, dynamic> p = (st['pipeline'] as Map).cast<String, dynamic>();
        if (p['whisper_waiting'] == 0 && p['whisper_busy'] == false) break;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      debugPrint('🟠 [STT] stop: $e');
    }
    _channel = null; // from here a closed connection is expected, not "lost"
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
      final String words = (data['confirmed'] as String? ?? '').trim();
      if (words.isNotEmpty) _onLive?.call(words);
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