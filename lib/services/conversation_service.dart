import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../screens/chats_models.dart';

// =====================================================================
//  CONVERSATION SERVICE — the ONLY place that saves chats to Firebase.
//
//  Firestore path: users/{uid}/conversations/{conversationId}
//
//  24-hour rule:
//    - Unsaved conversation: has "expireAt" = start time + 24 hours.
//      It is deleted automatically after that.
//    - Saved conversation (isSaved = true): has NO "expireAt",
//      so it is kept until the user deletes it.
//
//  The models in chats_models.dart are NOT changed; this file only
//  converts them to / from Firestore.
// =====================================================================

class ConversationService {
  ConversationService._(); // Only one in the whole app
  static final ConversationService instance = ConversationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// users/{uid}/conversations of the signed-in user (null = not signed in).
  CollectionReference<Map<String, dynamic>>? get _collection {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('conversations');
  }

  /// A new unique id for a new conversation (use it as ChatsConversation.id).
  String newConversationId() =>
      _collection?.doc().id ?? 'local_${DateTime.now().millisecondsSinceEpoch}';

  /// Loads all conversations of the user, newest first.
  /// Expired unsaved conversations are deleted here and not returned.
  Future<List<ChatsConversation>> loadConversations() async {
    final collection = _collection;
    if (collection == null) return <ChatsConversation>[];

    try {
      final snap =
      await collection.orderBy('createdAt', descending: true).get();
      final DateTime now = DateTime.now();
      final WriteBatch cleanup = _db.batch();
      bool hasExpired = false;
      final List<ChatsConversation> result = <ChatsConversation>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        final bool isSaved = data['isSaved'] as bool? ?? false;
        final Timestamp? expireAt = data['expireAt'] as Timestamp?;

        if (!isSaved && expireAt != null && expireAt.toDate().isBefore(now)) {
          cleanup.delete(doc.reference);
          hasExpired = true;
          continue;
        }
        result.add(_conversationFromMap(doc.id, data));
      }

      if (hasExpired) {
        cleanup.commit().catchError((e) => debugPrint('cleanup error: $e'));
      }
      return result;
    } catch (e) {
      debugPrint('loadConversations error: $e');
      return <ChatsConversation>[];
    }
  }

  /// Saves the whole conversation (create or update).
  /// Call it after ANY change: new message, rename, start listening,
  /// save / unsave, accepting an AI enhancement.
  Future<void> saveConversation(ChatsConversation conversation) async {
    final collection = _collection;
    if (collection == null) return;

    try {
      await collection
          .doc(conversation.id)
          .set(_conversationToMap(conversation), SetOptions(merge: true));
    } catch (e) {
      debugPrint('saveConversation error: $e');
    }
  }

  /// Deletes a conversation (saved or not).
  Future<void> deleteConversation(String conversationId) async {
    final collection = _collection;
    if (collection == null) return;

    try {
      await collection.doc(conversationId).delete();
    } catch (e) {
      debugPrint('deleteConversation error: $e');
    }
  }

  // -------------------------------------------------------------------
  // Converting models <-> Firestore maps
  // -------------------------------------------------------------------

  Map<String, dynamic> _conversationToMap(ChatsConversation c) {
    return <String, dynamic>{
      'title': c.title,
      'createdAt': Timestamp.fromDate(c.createdAt),
      'startedAt':
      c.startedAt == null ? null : Timestamp.fromDate(c.startedAt!),
      'updatedAt': FieldValue.serverTimestamp(),
      'isSaved': c.isSaved,
      // Saved → remove expireAt (never deleted automatically).
      // Unsaved → start time + 24 hours (same countdown shown in the app).
      'expireAt': c.isSaved
          ? FieldValue.delete()
          : Timestamp.fromDate(c.displayTime.add(chatsAutoDeleteAfter)),
      'messages': c.messages.map(_messageToMap).toList(),
    };
  }

  ChatsConversation _conversationFromMap(String id, Map<String, dynamic> d) {
    final List<dynamic> rawMessages = d['messages'] as List<dynamic>? ?? [];
    return ChatsConversation(
      id: id,
      title: d['title'] as String? ?? '',
      createdAt:
      (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (d['startedAt'] as Timestamp?)?.toDate(),
      isSaved: d['isSaved'] as bool? ?? false,
      messages: rawMessages
          .map((m) => _messageFromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> _messageToMap(ChatsMessage m) {
    return <String, dynamic>{
      'id': m.id,
      'kind': m.kind == ChatsMessageKind.speechToText ? 'stt' : 'tts',
      'originalText': m.originalText,
      'enhancedText': m.enhancedText,
      'isEnhancementAccepted': m.isEnhancementAccepted,
      'speakerLabel': m.speakerLabel,
      'sentAt': Timestamp.fromDate(m.sentAt),
      'voiceDurationMs': m.voiceDuration?.inMilliseconds,
    };
  }

  ChatsMessage _messageFromMap(Map<String, dynamic> d) {
    final int? voiceMs = d['voiceDurationMs'] as int?;
    return ChatsMessage(
      id: d['id'] as String? ?? '',
      kind: d['kind'] == 'tts'
          ? ChatsMessageKind.textToSpeech
          : ChatsMessageKind.speechToText,
      originalText: d['originalText'] as String? ?? '',
      sentAt: (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      speakerLabel: d['speakerLabel'] as String? ?? 'شخص',
      enhancedText: d['enhancedText'] as String?,
      isEnhancementAccepted: d['isEnhancementAccepted'] as bool? ?? false,
      voiceDuration:
      voiceMs == null ? null : Duration(milliseconds: voiceMs),
    );
  }
}