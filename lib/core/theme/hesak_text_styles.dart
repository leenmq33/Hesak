import 'package:flutter/material.dart';
import 'hesak_colors.dart';

/// ALL text styles used in the Hesak app live here.
///
/// Rules for the team:
/// - Never write `TextStyle(fontSize: ...)` inside a screen. Use `HesakTextStyles.xxx`.
/// - Need a small change (e.g. different color)? Use `.copyWith(...)`:
///     HesakTextStyles.body.copyWith(color: HesakColors.urgent)
/// - Need a new style? Add it here first.
class HesakTextStyles {
  HesakTextStyles._(); // Use HesakTextStyles.xxx directly

  /// The app font. null = the phone's default font.
  /// When the team picks a font (e.g. 'Tajawal'), add it to pubspec.yaml
  /// and write its name here — every text in the app changes at once.
  static const String? fontFamily = null;

  // ---- Big titles ----

  /// Page title under the header ("الرئيسية", "المحادثات" ...). 26 / Bold.
  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: HesakColors.primaryDark,
  );

  /// Splash tagline ("لأن ما لا يسمع يستحق أن يدرك"). 22 / SemiBold.
  static const TextStyle splashTagline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: HesakColors.primaryDark,
    height: 1.4,
  );

  /// Greeting ("مرحبًا رحاب"). 22 / Bold.
  static const TextStyle greeting = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: HesakColors.primaryDark,
  );

  /// Big action text under a main button ("اضغط للاستماع"). 20 / Bold.
  static const TextStyle actionLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: HesakColors.textPrimary,
  );

  // ---- Cards ----

  /// Title at the top of a card ("الأصوات الحالية", "التنبيهات"). 15 / Bold.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: HesakColors.textPrimary,
  );

  /// Title of one row inside a card ("إنذار", "بكاء طفل"). 14.5 / Bold.
  static const TextStyle itemTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    color: HesakColors.textPrimary,
  );

  /// Text inside a chip ("صوت إسعاف"). 13 / SemiBold.
  static const TextStyle chipLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: HesakColors.primary,
  );

  // ---- Bottom nav bar ----

  /// Tab label in the bottom bar (unselected). 11 / Medium / grey.
  static const TextStyle navLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: HesakColors.iconInactive,
  );

  /// Tab label in the bottom bar (selected). 11 / Bold / purple.
  static const TextStyle navLabelSelected = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: HesakColors.primaryMuted,
  );

  /// Label under each mode circle ("الصلاة", "النوم", "إضافة"). 12 / SemiBold.
  static const TextStyle modeLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: HesakColors.textSecondary,
  );

  // ---- Small text ----

  /// Descriptions / subtitles ("تم رصد صوت إنذار"). 12 / Regular.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: HesakColors.textSecondary,
  );

  /// Times and small hints ("منذ ساعة"). 12 / Medium.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: HesakColors.textMuted,
  );

  /// Urgent caption ("الآن" on a new alert). 12 / Bold / red.
  static const TextStyle captionUrgent = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: HesakColors.urgent,
  );
}
