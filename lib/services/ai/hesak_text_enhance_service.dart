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
//  Used by: "تحسين النص" on a heard message and the ✦ button next to the
//  typing field (chats_conversation_screen.dart).
// =====================================================================

/// Improves a text (clearer wording) without changing the original.
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