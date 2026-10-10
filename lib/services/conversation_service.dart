import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../screens/chats_models.dart';

// =====================================================================
//  CONVERSATION SERVICE — the ONLY place that saves chats to Firebase.
//
//  Firestore path: users/{uid}/conversations/{conversationId}
//
//  24-hour rule:
//    - Unsaved conversation: has "expireAt" = LAST change + 24 hours
//      (a new message or rename starts the 24 hours again).
//      It is deleted automatically after that.
//    - Saved conversation (isSaved = true): has NO "expireAt",
//      so it is kept until the user deletes it.
//
//  Audio (ElevenLabs): the mp3 files are saved on the phone in
//    <app documents folder>/hesak_tts/<conversationId>/<messageId>.mp3
//  When a conversation is deleted (by the user or by the 24-hour rule),
//  its audio folder is deleted from the phone too.
//
//  Conversation numbers ("محادثة 05") work like an id: a number is never
//  given again, even after its conversation is deleted. The last used
//  number is kept in users/{uid} -> "lastConversationNumber".
//
//  Order: the last changed conversation first (new message, rename,
//  improved text) — "editedAt" keeps the last rename / improve time.
//
//  Offline: the project doesn't change Firestore settings (main.dart), so
//  the default applies — on Android / iOS Firestore keeps a copy on the
//  phone. Reading works from that copy, and saves / deletes are applied to
//  it at once and uploaded when the internet returns. Nothing is deleted
//  because of the internet; only the 24-hour rule deletes (unsaved only).
//
//  This file only converts the models (chats_models.dart) to / from Firestore.
// =====================================================================

class ConversationService {
  ConversationService._(); // Only one in the whole app
  static final ConversationService instance = ConversationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Same folder name used by HesakTtsService.audioFolder.
  static const String _audioFolder = 'hesak_tts';

  /// Goes up by 1 after every save / delete. الرئيسية and المحادثات listen
  /// to it and reload, so a conversation started on one page shows on the other.
  final ValueNotifier<int> changeCount = ValueNotifier<int>(0);

  /// users/{uid}/conversations of the signed-in user (null = not signed in).
  CollectionReference<Map<String, dynamic>>? get _collection {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('conversations');
  }

  /// A new unique id for a new conversation (use it as ChatsConversation.id).
  String newConversationId() =>
      _collection?.doc().id ?? 'local_${DateTime.now().millisecondsSinceEpoch}';

  /// How long we wait for Firebase before showing "تعذّر التحميل".
  static const Duration _loadTimeout = Duration(seconds: 12);

  /// Deletes the saved audio files of one conversation from the phone.
  Future<void> _deleteAudioFolder(String conversationId) async {
    try {
      final Directory docs = await getApplicationDocumentsDirectory();
      final Directory dir =
      Directory('${docs.path}/$_audioFolder/$conversationId');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('deleteAudioFolder error: $e');
    }
  }

  /// Loads all conversations of the user, the last changed first.
  /// Expired unsaved conversations are deleted here and not returned.
  /// Returns null when loading failed (no internet and nothing saved on the
  /// phone yet, or Firebase error) — the page then shows "إعادة المحاولة".
  Future<List<ChatsConversation>?> loadConversations() async {
    final collection = _collection;
    if (collection == null) return <ChatsConversation>[];

    try {
      final snap = await collection
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(_loadTimeout);

      // Offline with nothing cached yet: we don't really know the list.
      if (snap.metadata.isFromCache && snap.docs.isEmpty) return null;

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
          unawaited(_deleteAudioFolder(doc.id)); // delete its audio files too
          hasExpired = true;
          continue;
        }
        result.add(_conversationFromMap(doc.id, data));
      }

      // Newest change first (last message / rename), not the creation time.
      result.sort((a, b) => b.displayTime.compareTo(a.displayTime));

      if (hasExpired) {
        cleanup.commit().catchError((e) => debugPrint('cleanup error: $e'));
      }
      return result;
    } catch (e) {
      debugPrint('loadConversations error: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------
  // New conversation + its number (like an id, never reused)
  // -------------------------------------------------------------------

  /// Highest number this app already gave (kept while the app is open).
  int _lastUsedNumberOnPhone = 0;

  /// New conversations whose number is not saved yet: id -> number.
  /// The number is saved only when the conversation is really used
  /// (first save), so an empty conversation that is closed right away
  /// does not use up a number.
  final Map<String, int> _pendingNumbers = <String, int>{};

  /// users/{uid} of the signed-in user (null = not signed in).
  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  /// Creates (does not save yet) a new conversation "محادثة NN".
  /// [existing] = the conversations already loaded, so the number is
  /// always bigger than every "محادثة NN" the user has.
  Future<ChatsConversation> createNewConversation(List<ChatsConversation> existing) async {
    // Only one new conversation is open at a time: an older one that was
    // closed without being used gives its number back.
    _pendingNumbers.clear();
    int lastSaved = 0;
    try {
      final snap = await _userDoc?.get().timeout(const Duration(seconds: 5));
      lastSaved = (snap?.data()?['lastConversationNumber'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('read lastConversationNumber error: $e'); // Offline: use what we know
    }
    final int number = <int>[
      lastSaved,
      _lastUsedNumberOnPhone,
      chatsHighestDefaultNumber(existing),
    ].reduce(math.max) + 1;

    final ChatsConversation conversation = ChatsConversation(
      id: newConversationId(),
      // Auto name until the user renames it.
      title: chatsDefaultConversationTitle(number),
      createdAt: DateTime.now(),
    );
    _pendingNumbers[conversation.id] = number;
    return conversation;
  }

  /// Saves "this number is used" (only goes up, never down).
  Future<void> _rememberUsedNumber(int number) async {
    _lastUsedNumberOnPhone = math.max(_lastUsedNumberOnPhone, number);
    final ref = _userDoc;
    if (ref == null) return;
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final int last = (snap.data()?['lastConversationNumber'] as num?)?.toInt() ?? 0;
        if (number > last) {
          tx.set(ref, <String, dynamic>{'lastConversationNumber': number}, SetOptions(merge: true));
        }
      });
    } catch (e) {
      debugPrint('save lastConversationNumber error: $e');
    }
  }

  /// Saves the whole conversation (create or update).
  /// Call it after ANY change: new message, rename, start listening,
  /// save / unsave, accepting an AI enhancement.
  Future<void> saveConversation(ChatsConversation conversation) async {
    // First save of a new conversation: its number is now used for good.
    final int? number = _pendingNumbers.remove(conversation.id);
    if (number != null) unawaited(_rememberUsedNumber(number));

    final collection = _collection;
    if (collection == null) return;

    // Firestore writes to the phone's copy right away and uploads later
    // when there is internet. Its Future only completes after the server
    // confirms, so we do NOT wait for it (it would hang while offline).
    collection
        .doc(conversation.id)
        .set(_conversationToMap(conversation), SetOptions(merge: true))
        .catchError((Object e) => debugPrint('saveConversation error: $e'));
    changeCount.value++;
  }

  /// Deletes a conversation (saved or not) and its audio files.
  Future<void> deleteConversation(String conversationId) async {
    final collection = _collection;
    if (collection == null) return;

    // Same as saving: applied on the phone now, uploaded later if offline.
    collection
        .doc(conversationId)
        .delete()
        .catchError((Object e) => debugPrint('deleteConversation error: $e'));
    unawaited(_deleteAudioFolder(conversationId)); // delete its audio files too
    changeCount.value++;
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
      'editedAt': c.editedAt == null ? null : Timestamp.fromDate(c.editedAt!),
      'updatedAt': FieldValue.serverTimestamp(),
      'isSaved': c.isSaved,
      // Saved → remove expireAt (never deleted automatically).
      // Unsaved → last change + 24 hours (same countdown shown in the app).
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
      editedAt: (d['editedAt'] as Timestamp?)?.toDate(),
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
      'audioFileName': m.audioFileName,
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
      audioFileName: d['audioFileName'] as String?,
    );
  }
}