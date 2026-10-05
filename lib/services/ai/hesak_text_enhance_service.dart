import '../../screens/chats_models.dart';

// =====================================================================
//  AI TEXT ENHANCEMENT (OpenAI) — NOT connected yet.
//
//  Always call it through hesakRunOnline (needs internet):
//    final better = await hesakRunOnline(
//        () => HesakTextEnhanceService.instance.enhance(text));
//
//  Until OpenAI is connected, enhance() returns the existing local mock
//  (chatsEnhanceText) so the screens can still be tested.
// =====================================================================

class HesakTextEnhanceService {
  HesakTextEnhanceService._();
  static final HesakTextEnhanceService instance = HesakTextEnhanceService._();

  /// Set to true once the real OpenAI call is added.
  bool get isConnected => false;

  /// Returns an improved version of [text]. Never changes [text] itself.
  Future<String> enhance(String text) async {
    if (!isConnected) return chatsEnhanceText(text); // Mock for testing
    // TODO(models team): call OpenAI and return the improved text.
    throw UnimplementedError('OpenAI is not connected yet');
  }
}