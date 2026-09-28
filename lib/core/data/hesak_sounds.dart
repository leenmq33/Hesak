import 'package:flutter/material.dart';

// =====================================================================
//  SOUNDS — the sounds the user can turn on/off for each mode,
//  grouped in sections (الطوارئ، أصوات المداخل، الأشخاص ...).
//
//  The sound model can hear many more sounds (500+). This is only the
//  list the USER sees and picks from. To add a sound: add one line to
//  `hesakSounds` with a unique id and its section.
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
  devices,
  homeKitchen,
  traffic,
  animals,
}

/// Arabic title + icon of each section.
extension HesakSoundCategoryInfo on HesakSoundCategory {
  String get label {
    switch (this) {
      case HesakSoundCategory.emergency:
        return 'الطوارئ والإنذارات';
      case HesakSoundCategory.entrances:
        return 'أصوات المداخل';
      case HesakSoundCategory.people:
        return 'الأشخاص';
      case HesakSoundCategory.devices:
        return 'الأجهزة';
      case HesakSoundCategory.homeKitchen:
        return 'المنزل والمطبخ';
      case HesakSoundCategory.traffic:
        return 'الطريق والمواصلات';
      case HesakSoundCategory.animals:
        return 'الحيوانات';
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
      case HesakSoundCategory.devices:
        return Icons.phone_android_rounded;
      case HesakSoundCategory.homeKitchen:
        return Icons.kitchen_outlined;
      case HesakSoundCategory.traffic:
        return Icons.directions_car_outlined;
      case HesakSoundCategory.animals:
        return Icons.pets_rounded;
    }
  }

  /// Emergency sounds are locked ON in every mode.
  bool get isLocked => this == HesakSoundCategory.emergency;
}

/// One sound the user can pick (e.g. جرس الباب).
class HesakSound {
  final String id; // Unique, English, e.g. 'doorbell'
  final String label; // Arabic name shown on screen
  final HesakSoundCategory category;

  const HesakSound(this.id, this.label, this.category);
}

/// All the sounds the user can pick, grouped by section.
const List<HesakSound> hesakSounds = [
  // ---- الطوارئ والإنذارات (always on) ----
  HesakSound('fire_alarm', 'إنذار حريق', HesakSoundCategory.emergency),
  HesakSound('general_alarm', 'إنذار عام', HesakSoundCategory.emergency),
  HesakSound('loud_sound', 'صوت عالٍ', HesakSoundCategory.emergency),
  HesakSound('explosion', 'صوت انفجار', HesakSoundCategory.emergency),

  // ---- أصوات المداخل ----
  HesakSound('doorbell', 'جرس الباب', HesakSoundCategory.entrances),
  HesakSound('door_knock', 'طرق الباب', HesakSoundCategory.entrances),
  HesakSound('door_open_close', 'فتح وإغلاق باب', HesakSoundCategory.entrances),
  HesakSound('keys', 'صوت مفاتيح', HesakSoundCategory.entrances),

  // ---- الأشخاص ----
  HesakSound('baby_cry', 'بكاء طفل', HesakSoundCategory.people),
  HesakSound('shout', 'صراخ', HesakSoundCategory.people),
  HesakSound('laugh', 'ضحك', HesakSoundCategory.people),
  HesakSound('clapping', 'تصفيق', HesakSoundCategory.people),
  HesakSound('cough', 'سعال', HesakSoundCategory.people),

  // ---- الأجهزة ----
  HesakSound('phone_ring', 'رنين هاتف', HesakSoundCategory.devices),
  HesakSound('alarm_clock', 'منبه', HesakSoundCategory.devices),
  HesakSound('timer_beep', 'صفارة مؤقت', HesakSoundCategory.devices),
  HesakSound('washing_machine', 'غسالة', HesakSoundCategory.devices),
  HesakSound('smoke_detector_beep', 'تنبيه جهاز', HesakSoundCategory.devices),

  // ---- المنزل والمطبخ ----
  HesakSound('running_water', 'ماء جارٍ', HesakSoundCategory.homeKitchen),
  HesakSound('kettle', 'غلاية', HesakSoundCategory.homeKitchen),
  HesakSound('microwave', 'ميكروويف', HesakSoundCategory.homeKitchen),
  HesakSound('vacuum', 'مكنسة كهربائية', HesakSoundCategory.homeKitchen),
  HesakSound('glass_break', 'كسر زجاج', HesakSoundCategory.homeKitchen),

  // ---- الطريق والمواصلات ----
  HesakSound('car_horn', 'بوق سيارة', HesakSoundCategory.traffic),
  HesakSound('siren', 'صفارة إسعاف أو شرطة', HesakSoundCategory.traffic),
  HesakSound('motorcycle', 'دراجة نارية', HesakSoundCategory.traffic),
  HesakSound('train', 'قطار', HesakSoundCategory.traffic),
  HesakSound('airplane', 'طائرة', HesakSoundCategory.traffic),

  // ---- الحيوانات ----
  HesakSound('dog', 'كلب', HesakSoundCategory.animals),
  HesakSound('cat', 'قطة', HesakSoundCategory.animals),
  HesakSound('birds', 'طيور', HesakSoundCategory.animals),
  HesakSound('rooster', 'ديك', HesakSoundCategory.animals),
];

/// The sounds of one section, in list order.
List<HesakSound> hesakSoundsIn(HesakSoundCategory category) =>
    hesakSounds.where((sound) => sound.category == category).toList();

/// Ids of the emergency sounds (always on).
final Set<String> hesakEmergencySoundIds =
    hesakSoundsIn(HesakSoundCategory.emergency).map((sound) => sound.id).toSet();

/// Ids of ALL the sounds.
final Set<String> hesakAllSoundIds = hesakSounds.map((sound) => sound.id).toSet();
