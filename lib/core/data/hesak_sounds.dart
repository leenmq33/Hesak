import 'package:flutter/material.dart';

// =====================================================================
//  SOUNDS — the sounds the user can turn on/off for each mode,
//  grouped in sections (الطوارئ، المداخل والتنبيهات، الأصوات البشرية ...).
//
//  The sound model can hear many more sounds (500+). This is only the
//  list the USER sees and picks from. To add a sound: add one line to
//  `hesakSounds` with a unique id and its section.
//
//  Used by: the mode editor ("الأصوات" list) and HesakModeStore (which
//  sounds each mode keeps on).
//
//  Rules for the team:
//  - Use the sound ids (e.g. 'doorbell') everywhere, never the Arabic text.
//  - Emergency sounds are ALWAYS on in every mode (the user can see them
//    but can't turn them off).
// =====================================================================

/// The sections the sounds are grouped in, in screen order.
enum HesakSoundCategory {
  emergency,
  entrances,
  people,
  animals,
  weather,
  traffic,
}

/// Title + icon of each section (as shown on the sounds list).
extension HesakSoundCategoryInfo on HesakSoundCategory {
  String get label {
    switch (this) {
      case HesakSoundCategory.emergency:
        return 'الطوارئ';
      case HesakSoundCategory.entrances:
        return 'المداخل والتنبيهات';
      case HesakSoundCategory.people:
        return 'الأصوات البشرية';
      case HesakSoundCategory.animals:
        return 'الحيوانات';
      case HesakSoundCategory.weather:
        return 'الطقس';
      case HesakSoundCategory.traffic:
        return 'الطريق';
    }
  }

  IconData get icon {
    switch (this) {
      case HesakSoundCategory.emergency:
        return Icons.notification_important_rounded;
      case HesakSoundCategory.entrances:
        return Icons.door_front_door_outlined;
      case HesakSoundCategory.people:
        return Icons.record_voice_over_outlined;
      case HesakSoundCategory.animals:
        return Icons.pets_rounded;
      case HesakSoundCategory.weather:
        return Icons.thunderstorm_outlined;
      case HesakSoundCategory.traffic:
        return Icons.directions_car_outlined;
    }
  }

  /// Emergency sounds are locked ON in every mode.
  bool get isLocked => this == HesakSoundCategory.emergency;
}

/// One sound the user can pick (e.g. الجرس).
class HesakSound {
  final String id; // Unique, English, e.g. 'doorbell'
  final String label; // Arabic name shown on screen
  final HesakSoundCategory category;

  const HesakSound(this.id, this.label, this.category);
}

/// All the sounds the user can pick, grouped by section (16 sounds).
const List<HesakSound> hesakSounds = [
  // ---- الطوارئ (always on) ----
  HesakSound('emergency_vehicle', 'مركبات الطوارئ', HesakSoundCategory.emergency),
  HesakSound('fire_alarm', 'إنذار الحريق', HesakSoundCategory.emergency),

  // ---- المداخل والتنبيهات ----
  HesakSound('doorbell', 'الجرس', HesakSoundCategory.entrances),
  HesakSound('door_knock', 'طرق الباب', HesakSoundCategory.entrances),
  HesakSound('keys', 'المفاتيح', HesakSoundCategory.entrances),

  // ---- الأصوات البشرية ----
  HesakSound('shout', 'الصراخ', HesakSoundCategory.people),
  HesakSound('baby_cry', 'بكاء الطفل', HesakSoundCategory.people),
  HesakSound('crowd', 'ضجيج الأشخاص', HesakSoundCategory.people),

  // ---- الحيوانات ----
  HesakSound('dog', 'الكلب', HesakSoundCategory.animals),
  HesakSound('cat', 'القطة', HesakSoundCategory.animals),
  HesakSound('birds', 'الطيور', HesakSoundCategory.animals),
  HesakSound('chicken', 'الدجاج/الديك', HesakSoundCategory.animals),
  HesakSound('sheep_goat', 'الغنم/الماعز', HesakSoundCategory.animals),

  // ---- الطقس ----
  HesakSound('rain_storm', 'المطر والعواصف', HesakSoundCategory.weather),

  // ---- الطريق ----
  HesakSound('car_horn', 'البوري', HesakSoundCategory.traffic),
];

/// The sounds of one section, in list order.
List<HesakSound> hesakSoundsIn(HesakSoundCategory category) =>
    hesakSounds.where((sound) => sound.category == category).toList();

/// Ids of the emergency sounds (always on).
final Set<String> hesakEmergencySoundIds =
    hesakSoundsIn(HesakSoundCategory.emergency).map((sound) => sound.id).toSet();

/// Ids of ALL the sounds.
final Set<String> hesakAllSoundIds = hesakSounds.map((sound) => sound.id).toSet();

// ---------------------------------------------------------------------
// Old sound list (before Nov 2026): modes saved in Firebase may still have
// these ids. hesakMigrateSoundIds() turns them into the new list.
// ---------------------------------------------------------------------

/// Old ids that became a new id.
const Map<String, String> _hesakRenamedSoundIds = {
  'siren': 'emergency_vehicle', // صفارة إسعاف أو شرطة -> مركبات الطوارئ
  'rooster': 'chicken', // ديك -> الدجاج/الديك
};

/// ALL the ids of the old list (32 sounds). A mode that had every one of
/// them ("all sounds", like العام) gets every NEW sound too.
const Set<String> _hesakOldAllSoundIds = {
  'fire_alarm', 'general_alarm', 'loud_sound', 'explosion',
  'doorbell', 'door_knock', 'door_open_close', 'keys',
  'baby_cry', 'shout', 'laugh', 'clapping', 'cough',
  'phone_ring', 'alarm_clock', 'timer_beep', 'washing_machine', 'smoke_detector_beep',
  'running_water', 'kettle', 'microwave', 'vacuum', 'glass_break',
  'car_horn', 'siren', 'motorcycle', 'train', 'airplane',
  'dog', 'cat', 'birds', 'rooster',
};

/// Saved sound ids -> ids of the CURRENT list:
/// renamed ids are renamed, removed ones are dropped, emergency is always in.
Set<String> hesakMigrateSoundIds(Iterable<String> savedIds) {
  final Set<String> saved = savedIds.toSet();
  if (saved.containsAll(_hesakOldAllSoundIds)) return {...hesakAllSoundIds};
  return {
    ...hesakEmergencySoundIds,
    for (final id in saved)
      if (hesakAllSoundIds.contains(_hesakRenamedSoundIds[id] ?? id)) _hesakRenamedSoundIds[id] ?? id,
  };
}
