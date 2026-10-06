import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// =====================================================================
//  ALERT SERVICE — saves the sound alerts (تنبيهات الأصوات) in Firebase.
//
//  Firestore path: users/{uid}/alerts/{alertId}
//
//  Like the conversations: every alert is deleted after 24 hours.
//  (expireAt = detectedAt + 24h, old ones are removed when the list loads.)
//
//  The alert itself (vibration / notification / flash) happens on the
//  phone right away. This service only keeps the HISTORY in Firebase.
//  Firestore also works offline: alerts saved without internet are sent
//  automatically when the phone is back online.
// =====================================================================

/// One saved alert.
class HesakAlert {
  final String id;
  final String soundId; // e.g. 'fire_alarm' (same ids as hesak_sounds.dart)
  final String modeId; // the mode that was on (e.g. 'general', 'sleep')
  final double confidence; // how sure the model was: 0.0 – 1.0
  final String? direction; // optional: where the sound came from
  final DateTime detectedAt;

  const HesakAlert({
    required this.id,
    required this.soundId,
    required this.modeId,
    required this.confidence,
    required this.detectedAt,
    this.direction,
  });

  factory HesakAlert.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return HesakAlert(
      id: doc.id,
      soundId: data['soundId'] as String? ?? '',
      modeId: data['modeId'] as String? ?? '',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
      direction: data['direction'] as String?,
      detectedAt: (data['detectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class AlertService {
  AlertService._(); // Only one AlertService in the whole app
  static final AlertService instance = AlertService._();

  /// How long an alert is kept.
  static const Duration keepFor = Duration(hours: 24);

  /// The same sound is saved at most once every 10 seconds
  /// (the model may hear a fire alarm many times per second).
  static const Duration sameSoundGap = Duration(seconds: 10);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, DateTime> _lastSavedAt = {};

  /// users/{uid}/alerts of the signed-in user (null = not signed in).
  CollectionReference<Map<String, dynamic>>? get _alerts {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('alerts');
  }

  // ---------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------

  /// Call this when the model detects a sound the user wants to be alerted about.
  /// Returns the new alert id, or null if it was skipped / failed.
  Future<String?> saveAlert({
    required String soundId,
    required String modeId,
    required double confidence,
    String? direction,
  }) async {
    final alerts = _alerts;
    if (alerts == null) return null;

    // Skip repeats of the same sound within a few seconds.
    final now = DateTime.now();
    final last = _lastSavedAt[soundId];
    if (last != null && now.difference(last) < sameSoundGap) return null;
    _lastSavedAt[soundId] = now;

    try {
      final doc = alerts.doc();
      await doc.set({
        'soundId': soundId,
        'modeId': modeId,
        'confidence': confidence,
        if (direction != null) 'direction': direction,
        'detectedAt': Timestamp.fromDate(now),
        'expireAt': Timestamp.fromDate(now.add(keepFor)),
      });
      return doc.id;
    } catch (e) {
      debugPrint('saveAlert error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------

  /// Loads the alerts of the last 24 hours (newest first),
  /// and deletes the expired ones from Firebase.
  Future<List<HesakAlert>> loadAlerts() async {
    final alerts = _alerts;
    if (alerts == null) return [];
    try {
      await _deleteExpired(alerts);
      final snap = await alerts.orderBy('detectedAt', descending: true).get();
      return snap.docs.map(HesakAlert.fromFirestore).toList();
    } catch (e) {
      debugPrint('loadAlerts error: $e');
      return [];
    }
  }

  /// Live list (updates by itself when a new alert is saved). Newest first.
  /// Expired alerts are hidden; they are deleted on the next loadAlerts().
  Stream<List<HesakAlert>> watchAlerts() {
    final alerts = _alerts;
    if (alerts == null) return Stream.value(const []);
    return alerts.orderBy('detectedAt', descending: true).snapshots().map((snap) {
      final cutoff = DateTime.now().subtract(keepFor);
      return snap.docs
          .map(HesakAlert.fromFirestore)
          .where((a) => a.detectedAt.isAfter(cutoff))
          .toList();
    });
  }

  // ---------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------

  Future<void> deleteAlert(String alertId) async {
    try {
      await _alerts?.doc(alertId).delete();
    } catch (e) {
      debugPrint('deleteAlert error: $e');
    }
  }

  Future<void> deleteAllAlerts() async {
    final alerts = _alerts;
    if (alerts == null) return;
    try {
      final snap = await alerts.get();
      await _deleteInBatches(snap.docs);
    } catch (e) {
      debugPrint('deleteAllAlerts error: $e');
    }
  }

  /// Deletes alerts whose expireAt has passed (older than 24h).
  Future<void> _deleteExpired(CollectionReference<Map<String, dynamic>> alerts) async {
    final snap = await alerts.where('expireAt', isLessThan: Timestamp.now()).get();
    await _deleteInBatches(snap.docs);
  }

  Future<void> _deleteInBatches(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    // Firestore allows max 500 operations per batch.
    for (var i = 0; i < docs.length; i += 500) {
      final batch = _db.batch();
      for (final doc in docs.skip(i).take(500)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}