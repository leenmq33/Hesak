import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'hesak_modes.dart';
import 'hesak_sounds.dart';

// =====================================================================
//  MODE STORE — the user's modes and all their settings, in ONE place.
//
//  - The modes page reads and changes the modes through
//    `HesakModeStore.instance`.
//  - The bottom bar (through HesakMainShell) listens to it, so starring
//    a mode adds it to the wheel right away.
//
//  Saved in Firebase (Cloud Firestore):
//    users/{uid}/userModes/{modeId}   one document per mode the user changed
//                                     or created (same field names as
//                                     HesakModeConfig below).
//    users/{uid}.settings.currentModeId   the active mode.
//  Built-in modes the user never changed come from the defaults in this file.
//  Loads automatically after login, and goes back to the defaults on logout.
//
//  NAMING: public types start with "Hesak".
// =====================================================================

// ---------------------------------------------------------------------
// Small enums: days, alert type, repeat
// ---------------------------------------------------------------------

/// Days of the week, starting Sunday (like the Saudi calendar).
enum HesakWeekday { sunday, monday, tuesday, wednesday, thursday, friday, saturday }

extension HesakWeekdayInfo on HesakWeekday {
  /// Full Arabic name ("الأحد").
  String get label => const ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'][index];

  /// Short name for the day chips ("أحد").
  String get shortLabel => const ['أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'][index];
}

/// How the user is alerted. The user can pick more than one.
enum HesakAlertType { vibration, notification, flash }

extension HesakAlertTypeInfo on HesakAlertType {
  String get label => const ['اهتزاز', 'إشعار', 'وميض'][index];

  IconData get icon => const [
    Icons.vibration_rounded,
    Icons.notifications_active_outlined,
    Icons.flash_on_rounded,
  ][index];
}

/// How many times an alert repeats.
enum HesakAlertRepeat { once, twice, thrice }

extension HesakAlertRepeatInfo on HesakAlertRepeat {
  String get label => const ['مرة', 'مرتين', 'ثلاث مرات'][index];
}

// ---------------------------------------------------------------------
// Schedule period: some days + from/to time
// ---------------------------------------------------------------------

/// One schedule period, e.g. الأحد – الخميس · 11:00 م – 6:00 ص.
/// A mode can have many periods (different days / different times).
@immutable
class HesakSchedulePeriod {
  final Set<HesakWeekday> days;
  final TimeOfDay start;
  final TimeOfDay end;

  const HesakSchedulePeriod({required this.days, required this.start, required this.end});

  /// "الأحد – الخميس" / "الجمعة، السبت" / "كل يوم".
  String get daysText => hesakFormatDays(days);

  /// "11:00 م – 6:00 ص".
  String get timeText => '${hesakFormatTime(start)} – ${hesakFormatTime(end)}';

  @override
  bool operator ==(Object other) =>
      other is HesakSchedulePeriod &&
          setEquals(other.days, days) &&
          other.start == start &&
          other.end == end;

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(days), start, end);
}

// ---- Clash check between periods ----

const int _minutesPerDay = 24 * 60;
const int _minutesPerWeek = 7 * _minutesPerDay;

/// The minutes of the week a period covers when it starts on [day].
/// Overnight periods (e.g. 10 م – 6 ص) run into the next day; start == end = the whole 24 hours.
/// Returns 1 range, or 2 when it wraps from Saturday night into Sunday.
List<(int, int)> _hesakWeekRanges(HesakWeekday day, TimeOfDay start, TimeOfDay end) {
  final int startMinute = day.index * _minutesPerDay + start.hour * 60 + start.minute;
  int length = (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute);
  if (length <= 0) length += _minutesPerDay;
  final int endMinute = startMinute + length;
  if (endMinute <= _minutesPerWeek) return [(startMinute, endMinute)];
  return [(startMinute, _minutesPerWeek), (0, endMinute - _minutesPerWeek)];
}

bool _hesakRangesOverlap(List<(int, int)> a, List<(int, int)> b) =>
    a.any((x) => b.any((y) => x.$1 < y.$2 && y.$1 < x.$2));

/// The first day of [candidate] whose time clashes with one of [others], or null if none.
/// Used to stop two periods covering the same time on the same day.
HesakWeekday? hesakFirstClashDay(HesakSchedulePeriod candidate, Iterable<HesakSchedulePeriod> others) {
  final days = candidate.days.toList()..sort((a, b) => a.index.compareTo(b.index));
  for (final day in days) {
    final mine = _hesakWeekRanges(day, candidate.start, candidate.end);
    for (final other in others) {
      for (final otherDay in other.days) {
        if (_hesakRangesOverlap(mine, _hesakWeekRanges(otherDay, other.start, other.end))) return day;
      }
    }
  }
  return null;
}

/// true when [period] covers the moment [now] (used by the real schedule).
bool hesakPeriodCovers(HesakSchedulePeriod period, DateTime now) {
  // DateTime.weekday: Monday = 1 ... Sunday = 7  ->  our index: Sunday = 0 ... Saturday = 6.
  final int nowMinute = (now.weekday % 7) * _minutesPerDay + now.hour * 60 + now.minute;
  for (final day in period.days) {
    for (final range in _hesakWeekRanges(day, period.start, period.end)) {
      if (range.$1 <= nowMinute && nowMinute < range.$2) return true;
    }
  }
  return false;
}

/// "11:00 م" — 12-hour time with ص / م.
String hesakFormatTime(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.period == DayPeriod.am ? 'ص' : 'م';
  return '$hour:$minute $suffix';
}

/// Days in short readable Arabic:
///  all 7 -> "كل يوم", 3+ days in a row -> "الأحد – الخميس", otherwise "الجمعة، السبت".
String hesakFormatDays(Set<HesakWeekday> days) {
  if (days.isEmpty) return '';
  if (days.length == 7) return 'كل يوم';

  final sorted = days.toList()..sort((a, b) => a.index.compareTo(b.index));
  final isInARow = sorted.last.index - sorted.first.index == sorted.length - 1;
  if (isInARow && sorted.length >= 3) {
    return '${sorted.first.label} – ${sorted.last.label}';
  }
  return sorted.map((day) => day.label).join('، ');
}

// ---------------------------------------------------------------------
// One mode with all its settings
// ---------------------------------------------------------------------

/// A mode and everything the user set for it.
@immutable
class HesakModeConfig {
  final String id; // Unique. Built-in: HesakModeIds.xxx, new ones: 'custom_...'
  final String name; // Exactly what the user typed ("النوم"), no "وضع" added
  final IconData? icon; // null = no icon -> the first letter of the name is shown
  final bool isFavorite; // true = shown on the wheel of the bottom bar ("الأوضاع المفضلة")

  final List<HesakSchedulePeriod> periods; // When the mode turns on by itself

  // الإعدادات العامة
  final bool isCallNameAlertOn; // التنبيه عند نداء اسمك
  final Set<HesakAlertType> alertTypes; // اهتزاز / إشعار / وميض
  final HesakAlertRepeat alertRepeat; // مرة / مرتين / ثلاث مرات

  final Set<String> soundIds; // Sounds that alert the user (always includes emergency)

  const HesakModeConfig({
    required this.id,
    required this.name,
    required this.icon,
    this.isFavorite = false,
    this.periods = const [],
    this.isCallNameAlertOn = true,
    this.alertTypes = const {HesakAlertType.vibration, HesakAlertType.flash},
    this.alertRepeat = HesakAlertRepeat.twice,
    required this.soundIds,
  });

  /// The general mode is the default one: it can't be deleted.
  bool get isGeneral => id == HesakModeIds.general;

  /// The letter shown in the circle when there's no icon.
  String get firstLetter => name.trim().isEmpty ? '؟' : name.trim().characters.first;

  /// One line for the mode card header: first period (+ how many more), or "بدون جدولة".
  String get scheduleLine {
    if (periods.isEmpty) return 'بدون جدولة';
    final first = '${periods.first.daysText} · ${periods.first.timeText}';
    return periods.length == 1 ? first : '$first  (+${periods.length - 1})';
  }

  /// "بدون جدولة" or the first period (+ how many more).
  String get scheduleSummary {
    if (periods.isEmpty) return 'بدون جدولة';
    final first = '${periods.first.daysText} · ${periods.first.timeText}';
    if (periods.length == 1) return first;
    final more = periods.length - 1;
    return '$first\n+ ${more == 1 ? 'فترة أخرى' : '$more فترات أخرى'}';
  }

  /// The small version the bottom bar understands.
  /// Modes without an icon show the first letter of their name (like on the الأوضاع page).
  HesakModeOption toOption() => HesakModeOption(
    id: id,
    label: name,
    icon: icon ?? Icons.person_rounded, // Not shown when [letter] is set
    letter: icon == null ? firstLetter : null,
  );

  HesakModeConfig copyWith({
    String? name,
    IconData? icon,
    bool clearIcon = false, // true = remove the icon (icon can't be set to null with ??)
    bool? isFavorite,
    List<HesakSchedulePeriod>? periods,
    bool? isCallNameAlertOn,
    Set<HesakAlertType>? alertTypes,
    HesakAlertRepeat? alertRepeat,
    Set<String>? soundIds,
  }) {
    return HesakModeConfig(
      id: id,
      name: name ?? this.name,
      icon: clearIcon ? null : (icon ?? this.icon),
      isFavorite: isFavorite ?? this.isFavorite,
      periods: periods ?? this.periods,
      isCallNameAlertOn: isCallNameAlertOn ?? this.isCallNameAlertOn,
      alertTypes: alertTypes ?? this.alertTypes,
      alertRepeat: alertRepeat ?? this.alertRepeat,
      soundIds: soundIds ?? this.soundIds,
    );
  }
}

// ---------------------------------------------------------------------
// The store
// ---------------------------------------------------------------------

/// All the user's modes + which one is active.
/// Widgets rebuild on changes with `ListenableBuilder(listenable: HesakModeStore.instance, ...)`.
class HesakModeStore extends ChangeNotifier {
  HesakModeStore._() {
    // Load the user's modes after login; back to the defaults after logout.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _resetToDefaults();
      } else {
        _loadFromFirebase(user.uid);
      }
    });
    // The real schedule: look at the clock every 30 seconds.
    _scheduleTimer = Timer.periodic(const Duration(seconds: 30), (_) => checkSchedule());
    checkSchedule(isAppStart: true);
  }
  static final HesakModeStore instance = HesakModeStore._();

  /// Starting modes. The general mode hears everything; the others only emergencies
  /// (+ road sounds for the car).
  static List<HesakModeConfig> _defaultModes() => [
    HesakModeConfig(
      id: HesakModeIds.general,
      name: 'العام',
      icon: Icons.person_rounded,
      isFavorite: true,
      soundIds: hesakAllSoundIds,
    ),
    HesakModeConfig(
      id: HesakModeIds.sleep,
      name: 'النوم',
      icon: Icons.nightlight_round,
      // Only العام starts in الأوضاع المفضلة; the user stars the others.
      alertTypes: const {HesakAlertType.vibration, HesakAlertType.flash},
      alertRepeat: HesakAlertRepeat.thrice,
      soundIds: hesakEmergencySoundIds,
    ),
    HesakModeConfig(
      id: HesakModeIds.car,
      name: 'السيارة',
      icon: Icons.directions_car_rounded,
      soundIds: {
        ...hesakEmergencySoundIds,
        ...hesakSoundsIn(HesakSoundCategory.traffic).map((sound) => sound.id),
      },
    ),
  ];

  final List<HesakModeConfig> _modes = _defaultModes();

  String _selectedModeId = HesakModeIds.general;

  /// All modes, in the user's order.
  List<HesakModeConfig> get modes => List.unmodifiable(_modes);

  /// The id of the active mode.
  String get selectedModeId => _selectedModeId;

  /// The active mode.
  HesakModeConfig get selectedMode => modeById(_selectedModeId) ?? _modes.first;

  /// A mode by its id, or null.
  HesakModeConfig? modeById(String id) {
    for (final mode in _modes) {
      if (mode.id == id) return mode;
    }
    return null;
  }

  /// Modes for the wheel in the bottom bar: ONLY the starred ones (الأوضاع المفضلة),
  /// in the user's order. The active mode shows in the middle button even when
  /// it isn't starred (see HesakBottomNavBar.activeModeIcon).
  List<HesakModeOption> get wheelOptions =>
      _modes.where((mode) => mode.isFavorite).map((mode) => mode.toOption()).toList();

  // -------------------------------------------------------------------
  // Listening (the big button on الرئيسية)
  // -------------------------------------------------------------------

  bool _isListening = false;

  /// true while the listen button on الرئيسية is ON.
  /// The selected mode is only really ACTIVE (مفعّل) while listening.
  bool get isListening => _isListening;

  /// Called by the listen button on الرئيسية.
  void setListening(bool isOn) {
    if (isOn == _isListening) return;
    _isListening = isOn;
    notifyListeners();
    // TODO: start / stop the real microphone listening here.
  }

  // -------------------------------------------------------------------
  // The real schedule (جدولة الوضع)
  //  - When "now" enters a period of a mode, that mode becomes the selected one.
  //  - When the period ends, العام becomes the selected one.
  //  - If the user picks another mode by hand during a period, we leave it:
  //    we only switch when a period STARTS or ENDS.
  //  - Works while the app is open. When the app opens again, it checks right away.
  //    TODO: switching while the app is fully closed needs the real background
  //    listening service (Android) — later.
  // -------------------------------------------------------------------

  Timer? _scheduleTimer;

  /// The mode whose period covered "now" at the last check (null = none).
  String? _lastScheduledModeId;

  /// The selected mode when the SCHEDULE picked it (null = the user picked it).
  /// Saved in Firebase with the selected mode.
  String? _scheduleSelectedModeId;

  final StreamController<String> _scheduleMessages = StreamController<String>.broadcast();

  /// Messages to show when the schedule switches the mode
  /// ("تم التبديل إلى وضع النوم حسب الجدولة"). HesakMainShell shows them.
  Stream<String> get scheduleMessages => _scheduleMessages.stream;

  /// The first mode (in the user's order) with a period that covers [now], or null.
  HesakModeConfig? scheduledModeAt(DateTime now) {
    for (final mode in _modes) {
      if (mode.periods.any((period) => hesakPeriodCovers(period, now))) return mode;
    }
    return null;
  }

  /// Looks at the clock and switches the selected mode when a period starts or ends.
  /// [isAppStart] = the app just opened (or the modes just loaded).
  void checkSchedule({bool isAppStart = false}) {
    final HesakModeConfig? scheduled = scheduledModeAt(DateTime.now());

    if (isAppStart) {
      _lastScheduledModeId = scheduled?.id;
      if (scheduled != null) {
        _switchBySchedule(scheduled);
      } else if (_scheduleSelectedModeId == _selectedModeId && !selectedMode.isGeneral) {
        // The schedule picked this mode, and its period ended while the app was closed -> back to العام.
        // (A mode the user picked by hand stays.)
        _switchBySchedule(modeById(HesakModeIds.general));
      }
      return;
    }

    if (scheduled?.id == _lastScheduledModeId) return; // Nothing started or ended
    _lastScheduledModeId = scheduled?.id;
    // A period started -> its mode. A period ended -> العام.
    _switchBySchedule(scheduled ?? modeById(HesakModeIds.general));
  }

  void _switchBySchedule(HesakModeConfig? mode) {
    if (mode == null || mode.id == _selectedModeId) return;
    selectMode(mode.id, isBySchedule: true);
    _scheduleMessages.add('تم التبديل إلى وضع ${mode.name} حسب الجدولة');
  }

  /// The other mode that already has [candidate]'s time, or null.
  /// Two modes can't share the same time: the mode that took it first keeps it.
  /// [modeId] = the mode being edited (or the new mode's id).
  HesakModeConfig? modeClashingWith(HesakSchedulePeriod candidate, {required String modeId}) {
    for (final mode in _modes) {
      if (mode.id == modeId) continue;
      if (hesakFirstClashDay(candidate, mode.periods) != null) return mode;
    }
    return null;
  }

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    _scheduleMessages.close();
    super.dispose();
  }

  /// Makes [id] the active mode.
  /// [isBySchedule] true = the schedule picked it (not the user).
  void selectMode(String id, {bool isBySchedule = false}) {
    if (id == _selectedModeId || modeById(id) == null) return;
    _selectedModeId = id;
    // Remember if the schedule picked it, so after the app was closed we know
    // whether to go back to العام (schedule) or keep it (the user's choice).
    _scheduleSelectedModeId = isBySchedule ? id : null;
    notifyListeners();
    _saveSelectedModeId();
    // TODO: apply the mode's listening settings here.
  }

  /// Stars / un-stars a mode. Returns the new value (true = now in الأوضاع المفضلة).
  bool toggleFavorite(String id) {
    final mode = modeById(id);
    if (mode == null) return false;
    final updated = mode.copyWith(isFavorite: !mode.isFavorite);
    _replace(updated);
    return updated.isFavorite;
  }

  /// Saves changes to an existing mode.
  void updateMode(HesakModeConfig mode) => _replace(mode);

  /// Adds a new mode at the end.
  void addMode(HesakModeConfig mode) {
    _modes.add(mode);
    notifyListeners();
    _saveMode(mode);
  }

  /// Deletes a mode (never the general one). If it was active, العام becomes active.
  void deleteMode(String id) {
    final mode = modeById(id);
    if (mode == null || mode.isGeneral) return;
    _modes.removeWhere((m) => m.id == id);
    final wasSelected = _selectedModeId == id;
    if (wasSelected) _selectedModeId = HesakModeIds.general;
    notifyListeners();
    _deleteSavedMode(id);
    if (wasSelected) _saveSelectedModeId();
  }

  /// Moves a mode to a new place in the list — used by drag-to-reorder on the
  /// الأوضاع page. [oldIndex] / [newIndex] are given the way ReorderableListView
  /// gives them. The wheel in the bottom bar shows the starred modes in this same order.
  void reorderModes({required int oldIndex, required int newIndex}) {
    if (oldIndex < 0 || oldIndex >= _modes.length) return;
    if (newIndex > oldIndex) newIndex -= 1; // ReorderableListView counts the moved item
    final moved = _modes.removeAt(oldIndex);
    _modes.insert(newIndex.clamp(0, _modes.length), moved);
    notifyListeners();
    _saveAllModes(); // The order of every mode changed
  }

  /// Puts the modes in the order of [orderedIds] (used by the الأوضاع page, where
  /// the selected mode stays on top and the others are dragged under it).
  void setModesOrder(List<String> orderedIds) {
    if (orderedIds.length != _modes.length) return;
    final reordered = <HesakModeConfig>[];
    for (final id in orderedIds) {
      final mode = modeById(id);
      if (mode == null) return; // Unknown id -> keep the old order
      reordered.add(mode);
    }
    _modes
      ..clear()
      ..addAll(reordered);
    notifyListeners();
    _saveAllModes(); // The order of every mode changed
  }

  /// A new unique id for a mode the user creates.
  String newModeId() => 'custom_${DateTime.now().microsecondsSinceEpoch}';

  void _replace(HesakModeConfig updated) {
    final index = _modes.indexWhere((m) => m.id == updated.id);
    if (index == -1) return;
    _modes[index] = updated;
    notifyListeners();
    _saveMode(updated);
  }

  // -------------------------------------------------------------------
  // Firebase (Cloud Firestore)
  // -------------------------------------------------------------------

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// users/{uid} of the signed-in user (null = not signed in).
  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  /// users/{uid}/userModes of the signed-in user.
  CollectionReference<Map<String, dynamic>>? get _userModes => _userDoc?.collection('userModes');

  /// Back to the starting modes (after logout).
  void _resetToDefaults() {
    _modes
      ..clear()
      ..addAll(_defaultModes());
    _selectedModeId = HesakModeIds.general;
    _scheduleSelectedModeId = null;
    _isListening = false;
    notifyListeners();
    checkSchedule(isAppStart: true);
  }

  /// Reads the user's modes and the active mode from Firestore.
  Future<void> _loadFromFirebase(String uid) async {
    try {
      final userDoc = _db.collection('users').doc(uid);
      final modesSnap = await userDoc.collection('userModes').get();
      final userSnap = await userDoc.get();

      final Map<String, Map<String, dynamic>> saved = {
        for (final doc in modesSnap.docs) doc.id: doc.data(),
      };
      final List<(int, HesakModeConfig)> loaded = [];

      // Built-in modes: the user's saved copy, or the default if never changed.
      final defaults = _defaultModes();
      for (int i = 0; i < defaults.length; i++) {
        final def = defaults[i];
        final data = saved.remove(def.id);
        if (data == null) {
          loaded.add((i, def));
        } else if (data['isDeleted'] != true) {
          loaded.add(((data['order'] as num?)?.toInt() ?? i, _modeFromMap(def.id, data, fallback: def)));
        }
      }

      // Modes the user created.
      for (final entry in saved.entries) {
        if (entry.value['isDeleted'] == true) continue;
        final order = (entry.value['order'] as num?)?.toInt() ?? 1000;
        loaded.add((order, _modeFromMap(entry.key, entry.value)));
      }

      loaded.sort((a, b) => a.$1.compareTo(b.$1));
      _modes
        ..clear()
        ..addAll(loaded.map((e) => e.$2));

      final settings = userSnap.data()?['settings'] as Map<String, dynamic>?;
      final savedModeId = settings?['currentModeId'] as String?;
      _selectedModeId =
      (savedModeId != null && modeById(savedModeId) != null) ? savedModeId : HesakModeIds.general;
      _scheduleSelectedModeId = settings?['scheduleSelectedModeId'] as String?;

      notifyListeners();
      checkSchedule(isAppStart: true); // The loaded schedule may say another mode now
    } catch (e) {
      debugPrint('🔴 [HesakModeStore] load error: $e');
    }
  }

  /// Saves one mode (all its settings) to users/{uid}/userModes/{id}.
  void _saveMode(HesakModeConfig mode) {
    final collection = _userModes;
    if (collection == null) return;
    final order = _modes.indexWhere((m) => m.id == mode.id);
    unawaited(
      collection
          .doc(mode.id)
          .set(_modeToMap(mode, order), SetOptions(merge: true))
          .catchError((e) => debugPrint('🔴 [HesakModeStore] save error: $e')),
    );
  }

  /// Saves every mode at once (used after reordering).
  void _saveAllModes() {
    final collection = _userModes;
    if (collection == null) return;
    final batch = _db.batch();
    for (int i = 0; i < _modes.length; i++) {
      batch.set(collection.doc(_modes[i].id), _modeToMap(_modes[i], i), SetOptions(merge: true));
    }
    unawaited(batch.commit().catchError((e) => debugPrint('🔴 [HesakModeStore] reorder error: $e')));
  }

  /// A mode the user created is deleted; a built-in mode is only marked as deleted
  /// (so it doesn't come back from the defaults).
  void _deleteSavedMode(String id) {
    final collection = _userModes;
    if (collection == null) return;
    final bool isBuiltIn = _defaultModes().any((m) => m.id == id);
    final Future<void> action = isBuiltIn
        ? collection.doc(id).set({'isDeleted': true, 'updatedAt': FieldValue.serverTimestamp()})
        : collection.doc(id).delete();
    unawaited(action.catchError((e) => debugPrint('🔴 [HesakModeStore] delete error: $e')));
  }

  /// Saves the active mode to users/{uid}.settings.currentModeId.
  void _saveSelectedModeId() {
    final userDoc = _userDoc;
    if (userDoc == null) return;
    unawaited(
      userDoc
          .update({
            'settings.currentModeId': _selectedModeId,
            'settings.scheduleSelectedModeId': _scheduleSelectedModeId, // null = picked by the user
          })
          .catchError((e) => debugPrint('🔴 [HesakModeStore] select error: $e')),
    );
  }

  // ---- Converting HesakModeConfig <-> Firestore (same field names) ----

  Map<String, dynamic> _modeToMap(HesakModeConfig mode, int order) {
    final int iconIndex = mode.icon == null ? -1 : hesakModeIconChoices.indexOf(mode.icon!);
    return <String, dynamic>{
      'name': mode.name,
      'icon': iconIndex >= 0 ? iconIndex : null, // Index in hesakModeIconChoices (null = letter)
      'isFavorite': mode.isFavorite,
      'periods': mode.periods.map(_periodToMap).toList(),
      'isCallNameAlertOn': mode.isCallNameAlertOn,
      'alertTypes': mode.alertTypes.map((type) => type.name).toList(),
      'alertRepeat': mode.alertRepeat.name,
      'soundIds': mode.soundIds.toList(),
      'order': order,
      'isDeleted': false,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  HesakModeConfig _modeFromMap(String id, Map<String, dynamic> d, {HesakModeConfig? fallback}) {
    IconData? icon = fallback?.icon;
    if (d.containsKey('icon')) {
      final index = (d['icon'] as num?)?.toInt();
      icon = (index != null && index >= 0 && index < hesakModeIconChoices.length)
          ? hesakModeIconChoices[index]
          : null;
    }

    final List<dynamic> rawPeriods = d['periods'] as List<dynamic>? ?? const [];
    final List<dynamic>? rawTypes = d['alertTypes'] as List<dynamic>?;
    final List<dynamic>? rawSounds = d['soundIds'] as List<dynamic>?;

    return HesakModeConfig(
      id: id,
      name: d['name'] as String? ?? fallback?.name ?? '',
      icon: icon,
      isFavorite: d['isFavorite'] as bool? ?? fallback?.isFavorite ?? false,
      periods: rawPeriods.map((p) => _periodFromMap(Map<String, dynamic>.from(p as Map))).toList(),
      isCallNameAlertOn: d['isCallNameAlertOn'] as bool? ?? fallback?.isCallNameAlertOn ?? true,
      alertTypes: rawTypes == null
          ? (fallback?.alertTypes ?? const {HesakAlertType.vibration, HesakAlertType.flash})
          : HesakAlertType.values.where((type) => rawTypes.contains(type.name)).toSet(),
      alertRepeat: HesakAlertRepeat.values.firstWhere(
            (repeat) => repeat.name == d['alertRepeat'],
        orElse: () => fallback?.alertRepeat ?? HesakAlertRepeat.twice,
      ),
      // Emergency sounds are always on.
      soundIds: {
        ...hesakEmergencySoundIds,
        ...(rawSounds?.cast<String>() ?? fallback?.soundIds ?? const <String>{}),
      },
    );
  }

  Map<String, dynamic> _periodToMap(HesakSchedulePeriod period) => <String, dynamic>{
    'days': (period.days.map((day) => day.index).toList()..sort()),
    'start': _timeToHhmm(period.start),
    'end': _timeToHhmm(period.end),
  };

  HesakSchedulePeriod _periodFromMap(Map<String, dynamic> d) => HesakSchedulePeriod(
    days: (d['days'] as List<dynamic>? ?? const [])
        .map((i) => HesakWeekday.values[(i as num).toInt()])
        .toSet(),
    start: _hhmmToTime(d['start'] as String? ?? '00:00'),
    end: _hhmmToTime(d['end'] as String? ?? '00:00'),
  );

  /// TimeOfDay -> "22:00".
  static String _timeToHhmm(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  /// "22:00" -> TimeOfDay.
  static TimeOfDay _hhmmToTime(String text) {
    final parts = text.split(':');
    return TimeOfDay(hour: int.tryParse(parts.first) ?? 0, minute: int.tryParse(parts.last) ?? 0);
  }
}