// =====================================================================
//  TEXT-TO-SPEECH (ElevenLabs) — NOT connected yet.
//
//  Flow (after integration):
//    user types text -> generateAndSave() calls ElevenLabs (needs internet)
//    -> the audio is saved on the phone -> its file name is kept on the
//    message (ChatsMessage.audioFileName) -> later playback uses the saved
//    file only (works offline, ElevenLabs is NOT called again).
//
//  Saved audio location (after integration):
//    <app documents folder>/hesak_tts/<conversationId>/<messageId>.mp3
//  Only the file name (relative path) is stored on the message, because
//  the full folder path differs between phones.
//
//  Packages to add at integration time: path_provider (folder) and an
//  audio player (e.g. just_audio).
// =====================================================================

class HesakTtsService {
  HesakTtsService._();
  static final HesakTtsService instance = HesakTtsService._();

  /// Set to true once the real ElevenLabs call below is added.
  /// While false, the app keeps the current mock playback (word highlight)
  /// and no audio file is created or claimed.
  bool get isConnected => false;

  /// Folder (inside the app documents folder) for saved audio.
  static const String audioFolder = 'hesak_tts';

  /// Relative file name for one message's audio.
  static String audioFileNameFor({
    required String conversationId,
    required String messageId,
  }) =>
      '$conversationId/$messageId.mp3';

  /// Generates speech for [text], saves it on the phone and returns the
  /// saved file name. Call through hesakRunOnline (needs internet).
  Future<String> generateAndSave({
    required String text,
    required String conversationId,
    required String messageId,
  }) async {
    // TODO(models team): call ElevenLabs with [text], write the bytes to
    // <documents>/$audioFolder/<audioFileNameFor(...)>, return that name.
    throw UnimplementedError('ElevenLabs is not connected yet');
  }

  /// true when the audio [fileName] is really saved on this phone.
  Future<bool> hasSavedAudio(String fileName) async {
    // TODO(models team): return File('<documents>/$audioFolder/$fileName').exists().
    return false;
  }

  /// Plays a saved audio file (no internet needed).
  Future<void> playSaved(String fileName) async {
    // TODO(models team): play the local file with the audio player.
    throw UnimplementedError('Audio playback is not connected yet');
  }
}