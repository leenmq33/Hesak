import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// One alert on the home page.
class HomeAlert {
  final String id;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final bool isUrgent; // Red alert (YAMNet will decide this later)

  const HomeAlert({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    this.isUrgent = false,
  });
}

/// "منذ ثوانٍ" / "منذ دقيقة" / "منذ 5 دقائق" / "منذ ساعة" ...
/// Never "الآن": what is heard right now shows in الأصوات الحالية.
String homeFormatTimeAgo(DateTime time) {
  final Duration ago = DateTime.now().difference(time);
  if (ago.inMinutes < 1) return 'منذ ثوانٍ';
  if (ago.inHours < 1) {
    final int minutes = ago.inMinutes;
    if (minutes == 1) return 'منذ دقيقة';
    if (minutes == 2) return 'منذ دقيقتين';
    if (minutes <= 10) return 'منذ $minutes دقائق';
    return 'منذ $minutes دقيقة';
  }
  final int hours = ago.inHours;
  if (hours == 1) return 'منذ ساعة';
  if (hours == 2) return 'منذ ساعتين';
  if (hours <= 10) return 'منذ $hours ساعات';
  return 'منذ $hours ساعة';
}

/// Every sound heard while listening, newest first (last 24 hours).
/// Saved in Firebase: users/{uid}/homeAlerts/{alertId}
///   title, subtitle, isUrgent, createdAt
/// Widgets rebuild with ListenableBuilder(listenable: HomeAlertsService.instance).
class HomeAlertsService extends ChangeNotifier {
  HomeAlertsService._() {
    // Load the user's alerts after login; clear them after logout.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _alerts.clear();
        notifyListeners();
      } else {
        _load();
      }
    });
    // Refresh "منذ ..." and drop alerts older than 24 hours.
    Timer.periodic(const Duration(seconds: 30), (_) => _onClockTick());
  }
  static final HomeAlertsService instance = HomeAlertsService._();

  static const Duration _keepFor = Duration(hours: 24);

  final List<HomeAlert> _alerts = [];

  /// Newest first.
  List<HomeAlert> get alerts => List.unmodifiable(_alerts);

  /// users/{uid}/homeAlerts of the signed-in user (null = not signed in).
  CollectionReference<Map<String, dynamic>>? get _alertsRef {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('homeAlerts');
  }

  /// Called by HomeMicService when a new sound starts.
  void addSound() {
    final DocumentReference<Map<String, dynamic>>? doc = _alertsRef?.doc();
    final HomeAlert alert = HomeAlert(
      id: doc?.id ?? 'local_${DateTime.now().microsecondsSinceEpoch}',
      title: 'صوت', // YAMNet will give the real name later
      subtitle: 'تم رصد صوت',
      createdAt: DateTime.now(),
    );
    _alerts.insert(0, alert);
    notifyListeners();
    if (doc != null) {
      unawaited(
        doc
            .set(<String, dynamic>{
              'title': alert.title,
              'subtitle': alert.subtitle,
              'isUrgent': alert.isUrgent,
              'createdAt': Timestamp.fromDate(alert.createdAt),
            })
            .catchError((e) => debugPrint('🔴 [HomeAlertsService] save error: $e')),
      );
    }
  }

  // ---------------------------------------------------------------
  // Firebase
  // ---------------------------------------------------------------

  Future<void> _load() async {
    final CollectionReference<Map<String, dynamic>>? ref = _alertsRef;
    if (ref == null) return;
    try {
      final Timestamp since = Timestamp.fromDate(DateTime.now().subtract(_keepFor));
      final QuerySnapshot<Map<String, dynamic>> snap = await ref
          .where('createdAt', isGreaterThan: since)
          .orderBy('createdAt', descending: true)
          .get();
      final List<HomeAlert> loaded = snap.docs.map(_fromDoc).toList();
      // Keep alerts added while loading.
      final Set<String> loadedIds = loaded.map((a) => a.id).toSet();
      final List<HomeAlert> merged = [
        ...loaded,
        ..._alerts.where((a) => !loadedIds.contains(a.id)),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _alerts
        ..clear()
        ..addAll(merged);
      notifyListeners();
      unawaited(_deleteOld(ref, since));
    } catch (e) {
      debugPrint('🔴 [HomeAlertsService] load error: $e');
    }
  }

  HomeAlert _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> d = doc.data();
    return HomeAlert(
      id: doc.id,
      title: d['title'] as String? ?? 'صوت',
      subtitle: d['subtitle'] as String? ?? 'تم رصد صوت',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isUrgent: d['isUrgent'] as bool? ?? false,
    );
  }

  /// Deletes alerts older than 24 hours from Firebase.
  Future<void> _deleteOld(CollectionReference<Map<String, dynamic>> ref, Timestamp before) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> old =
          await ref.where('createdAt', isLessThan: before).limit(400).get();
      if (old.docs.isEmpty) return;
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      for (final doc in old.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('🔴 [HomeAlertsService] cleanup error: $e');
    }
  }

  void _onClockTick() {
    if (_alerts.isEmpty) return;
    final DateTime since = DateTime.now().subtract(_keepFor);
    _alerts.removeWhere((a) => a.createdAt.isBefore(since));
    notifyListeners(); // Also refreshes "منذ ..."
  }
}