// =====================================================================
//  SPEECH-TO-TEXT (Faster-Whisper on the Hesak server) — NOT connected yet.
//
//  It runs on the server, so starting it needs internet. Previously saved
//  transcripts are normal messages and stay readable offline.
//
//  Until it is connected, the conversation screen keeps its demo
//  transcript (one fake heard sentence) for testing.
// =====================================================================

class HesakSpeechToTextService {
  HesakSpeechToTextService._();
  static final HesakSpeechToTextService instance = HesakSpeechToTextService._();

  /// Set to true once the real server connection is added.
  bool get isConnected => false;

  /// Faster-Whisper runs on the server -> internet is required to start.
  /// Change to false only if it is moved on-device.
  bool get needsInternet => true;

  /// Starts sending the microphone to the server; [onText] gets each result.
  Future<void> start({required void Function(String text) onText}) async {
    // TODO(models team): open the server stream and call onText(text).
    throw UnimplementedError('Faster-Whisper is not connected yet');
  }

  /// Stops listening and closes the server stream.
  Future<void> stop() async {
    // TODO(models team): close the server stream.
  }
}