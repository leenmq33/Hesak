import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../auth_service.dart';

// =====================================================================
//  TEXT-TO-SPEECH (ElevenLabs) — CONNECTED.
//
//  Flow:
//    user types text -> generateAndSave() calls ElevenLabs (needs internet)
//    -> the audio is saved on the phone -> its file name is kept on the
//    message (ChatsMessage.audioFileName) -> later playback uses the saved
//    file only (works offline, ElevenLabs is NOT called again).
//
//  Voice: male / female, from the user's choice (AuthService.currentVoice).
//
//  Saved audio location:
//    <app documents folder>/hesak_tts/<conversationId>/<messageId>.mp3
//
//  The key and voices come from env.json (never pushed to GitHub):
//    flutter run --dart-define-from-file=env.json
//
//  Testing stage only: before release, move the ElevenLabs call to a
//  server (Firebase Cloud Function) so the key is not inside the APK.
// =====================================================================

class HesakTtsService {
  HesakTtsService._();
  static final HesakTtsService instance = HesakTtsService._();

  static const String _apiKey = String.fromEnvironment('ELEVENLABS_API_KEY');
  static const String _voiceMale =
  String.fromEnvironment('ELEVENLABS_VOICE_ID_MALE');
  static const String _voiceFemale =
  String.fromEnvironment('ELEVENLABS_VOICE_ID_FEMALE');

  /// The voice the user chose (sign up / settings).
  String get _voiceId => AuthService.instance.currentVoice == HesakVoice.female
      ? _voiceFemale
      : _voiceMale;

  /// Fast model with Arabic support.
  static const String _modelId = 'eleven_flash_v2_5';

  final AudioPlayer _player = AudioPlayer();

  /// true only when env.json has the key and both voices.
  /// While false, the app keeps the mock playback (word highlight only).
  bool get isConnected =>
      _apiKey.isNotEmpty && _voiceMale.isNotEmpty && _voiceFemale.isNotEmpty;

  /// Folder (inside the app documents folder) for saved audio.
  static const String audioFolder = 'hesak_tts';

  /// Relative file name for one message's audio.
  static String audioFileNameFor({
    required String conversationId,
    required String messageId,
  }) =>
      '$conversationId/$messageId.mp3';

  Future<File> _fileFor(String fileName) async {
    final Directory docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/$audioFolder/$fileName');
  }

  /// Generates speech for [text], saves it on the phone and returns the
  /// saved file name. Call through hesakRunOnline (needs internet).
  Future<String> generateAndSave({
    required String text,
    required String conversationId,
    required String messageId,
  }) async {
    final Uri url = Uri.parse(
      'https://api.elevenlabs.io/v1/text-to-speech/$_voiceId'
          '?output_format=mp3_44100_128',
    );
    final http.Response res = await http.post(
      url,
      headers: {
        'xi-api-key': _apiKey,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
      },
      body: jsonEncode({
        'text': text,
        'model_id': _modelId,
        'language_code': 'ar',
      }),
    );
    if (res.statusCode != 200) {
      // 401 = wrong key · 402/429 = credits/limit · 404 = wrong voice ID
      throw Exception('ElevenLabs ${res.statusCode}: ${res.body}');
    }

    final String fileName = audioFileNameFor(
      conversationId: conversationId,
      messageId: messageId,
    );
    final File file = await _fileFor(fileName);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(res.bodyBytes);
    return fileName;
  }

  /// true when the audio [fileName] is really saved on this phone.
  Future<bool> hasSavedAudio(String fileName) async =>
      (await _fileFor(fileName)).exists();

  /// Plays a saved audio file (no internet needed). Returns its length.
  Future<Duration?> playSaved(String fileName) async {
    final File file = await _fileFor(fileName);
    await _player.stop();
    final Duration? duration = await _player.setFilePath(file.path);
    _player.play(); // not awaited: returns when playback finishes
    return duration;
  }

  /// Stops any audio that is playing.
  Future<void> stop() => _player.stop();
}