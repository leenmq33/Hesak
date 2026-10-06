import 'package:flutter/material.dart';
import 'hesak_colors.dart';

/// ALL text styles used in the Hesak app live here.
///
/// Rules for the team:
/// - Never write `TextStyle(fontSize: ...)` inside a screen. Use `HesakTextStyles.xxx`.
/// - Need a small change (e.g. different color)? Use `.copyWith(...)`:
///     HesakTextStyles.body.copyWith(color: HesakColors.urgent)
/// - Need a new style? Add it here first.
/// - The styles follow فاتح / داكن (their colors come from HesakColors), so they
///   are not `const`: don't write `const` in front of a widget that uses them.
class HesakTextStyles {
  HesakTextStyles._(); // Use HesakTextStyles.xxx directly

  /// The app font. null = the phone's default font.
  /// When the team picks a font (e.g. 'Tajawal'), add it to pubspec.yaml
  /// and write its name here — every text in the app changes at once.
  static const String? fontFamily = null;

  // ---- Big titles ----

  /// Page title under the header ("الرئيسية", "المحادثات" ...). 26 / Bold.
  static TextStyle get pageTitle => TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: HesakColors.primaryDark,
  );

  /// Splash tagline (the sentence under the logo). 22 / SemiBold.
  static TextStyle get splashTagline => TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: HesakColorsLight.primaryDark, // Always the dark purple: sits on the same light purple in فاتح and داكن
    height: 1.4,
  );

  /// Greeting ("مرحبًا رحاب"). 22 / Bold.
  static TextStyle get greeting => TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: HesakColors.primaryDark,
  );

  /// Big action text under a main button ("اضغط للاستماع"). 20 / Bold.
  static TextStyle get actionLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: HesakColors.textPrimary,
  );

  // ---- Cards ----

  /// Title at the top of a card ("الأصوات الحالية", "التنبيهات"). 15 / Bold.
  static TextStyle get cardTitle => TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: HesakColors.textPrimary,
  );

  /// Title of one row inside a card ("إنذار", "بكاء طفل"). 14.5 / Bold.
  static TextStyle get itemTitle => TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    color: HesakColors.textPrimary,
  );

  /// Text inside a chip ("صوت إسعاف"). 13 / SemiBold.
  static TextStyle get chipLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: HesakColors.primary,
  );

  // ---- Bottom nav bar ----

  /// Tab label in the bottom bar (unselected). 11 / Medium / grey.
  static TextStyle get navLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: HesakColors.iconInactive,
  );

  /// Tab label in the bottom bar (selected). 11 / Bold / purple.
  static TextStyle get navLabelSelected => TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: HesakColors.primaryMuted,
  );

  /// Label under each mode circle ("الصلاة", "النوم", "إضافة"). 12 / SemiBold.
  static TextStyle get modeLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: HesakColors.textSecondary,
  );

  // ---- Small text ----

  /// Descriptions / subtitles ("تم رصد صوت إنذار"). 12 / Regular.
  static TextStyle get body => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: HesakColors.textSecondary,
  );

  /// Times and small hints ("منذ ساعة"). 12 / Medium.
  static TextStyle get caption => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: HesakColors.textMuted,
  );

  /// Urgent caption ("الآن" on a new alert). 12 / Bold / red.
  static TextStyle get captionUrgent => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: HesakColors.urgent,
  );

  // ---- Sign in / sign up screens ----

  /// Title at the top of the white sheet ("تسجيل الدخول", "إنشاء حساب"). 20 / Bold.
  static TextStyle get authSheetTitle => TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: HesakColors.primaryDark,
  );

  /// Label above a text field ("البريد الإلكتروني:"). 17 / Bold.
  static TextStyle get fieldLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: HesakColors.textPrimary,
  );

  /// Text the user types in a field. 15 / Regular.
  static TextStyle get fieldInput => TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: HesakColors.textPrimary,
  );

  /// Placeholder inside a field ("example@email.com"). 15 / Regular / grey.
  static TextStyle get fieldHint => TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: HesakColors.fieldHint,
  );

  /// Error under a field ("البريد الإلكتروني غير صحيح"). 12 / Medium / red.
  static TextStyle get fieldError => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: HesakColors.urgent,
  );

  /// Text on the big rounded buttons. 18 / Bold / white.
  static TextStyle get buttonLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: HesakColors.onPrimary,
  );

  /// Text inside the pink note box. 11.5 / Medium.
  static TextStyle get infoBanner => TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    color: HesakColors.infoBannerText,
    height: 1.4,
  );

  /// One password rule ("8 خانات على الأقل"). 11.5 / Regular.
  static TextStyle get passwordRule => TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    color: HesakColors.textSecondary,
  );

  /// Small grey text ("ليس لديك حساب؟"). 12.5 / Regular.
  static TextStyle get authHint => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: HesakColors.textMuted,
  );

  /// Small tappable link ("إنشاء حساب", "هل نسيت كلمة المرور؟"). 12.5 / Bold.
  static TextStyle get authLink => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: HesakColors.primaryDark,
  );

  /// Text on the main glass button ("إنشاء حساب"). 18 / Bold / dark purple.
  static TextStyle get glassButtonPrimaryLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: HesakColorsLight.primaryDark, // Always the dark purple: sits on the same light purple in فاتح and داكن
  );

  /// Text on the light glass button ("تسجيل الدخول"). 18 / Bold / white.
  static TextStyle get glassButtonSecondaryLabel => buttonLabel;


  // ---- Modes page ----

  /// Name of the selected mode under the circles ("العام"). 17 / Bold.
  static TextStyle get modeName => TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: HesakColors.textPrimary,
  );

  /// Label under a mode circle (not selected). 12 / Regular / grey.
  static TextStyle get modeCircleLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: HesakColors.textSecondary,
  );

  /// Label under the selected mode circle. 12.5 / Bold / dark.
  static TextStyle get modeCircleLabelSelected => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: HesakColors.textPrimary,
  );

  /// Letter shown in a mode circle that has no icon. 22 / Bold.
  static TextStyle get modeCircleLetter => TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: HesakColors.iconInactive,
  );

  /// Small tappable purple text ("عرض الكل", "إضافة فترة", "تحديد الكل"). 13 / Bold.
  static TextStyle get modeLink => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: HesakColors.modeSelected,
  );

  /// Days of a schedule period ("الأحد – الخميس"). 13 / Bold.
  static TextStyle get modePeriodDays => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: HesakColors.textPrimary,
  );

  /// Time of a schedule period / time field ("11:00 م"). 13 / Bold / purple.
  static TextStyle get modePeriodTime => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: HesakColors.modeSelected,
  );

  /// Label of a setting row ("التنبيه عند نداء اسمك", "من:"). 13.5 / Bold.
  static TextStyle get modeSettingLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    color: HesakColors.textPrimary,
  );

  /// Chip that is NOT selected (days, sounds, alert types). 12 / Regular / grey.
  static TextStyle get modeChip => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: HesakColors.textSecondary,
  );

  /// Chip that IS selected. 12 / Bold / purple.
  static TextStyle get modeChipSelected => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: HesakColors.modeSelected,
  );

  /// Selected day chip (white text on purple). 12 / Bold / white.
  static TextStyle get modeDayChipSelected => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: HesakColors.onPrimary,
  );

  /// "مفعّل" badge next to the active mode's name. 10.5 / Bold / purple.
  static TextStyle get modeBadge => TextStyle(
    fontFamily: fontFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: HesakColors.modeSelected,
  );

  /// Small buttons inside sections ("حفظ" / "إلغاء"). 13 / Bold.
  static TextStyle get modeSmallButton => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: HesakColors.onPrimary,
  );

  /// "حذف الوضع" and other red actions. 13.5 / Bold / red.
  static TextStyle get modeDanger => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    color: HesakColors.danger,
  );

  /// Title of a confirmation dialog ("حذف وضع السيارة؟"). 17 / Bold.
  static TextStyle get dialogTitle => TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: HesakColors.textPrimary,
  );

  /// Text of a confirmation dialog. 13 / Regular / grey.
  static TextStyle get dialogBody => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: HesakColors.textSecondary,
    height: 1.6,
  );

  /// Text of the small message at the bottom ("تمت إضافة ..."). 13 / Medium / white.
  static TextStyle get toast => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: HesakColors.onPrimary,
  );

  /// Section title on the modes pages ("جدولة الوضع", "الإعدادات العامة").
  /// A bit bigger than the labels inside the section. 16.5 / Bold.
  static TextStyle get modeSectionTitle => TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w700,
    color: HesakColors.textPrimary,
  );

  /// Name under a mode tile (not selected). 13 / Medium / dark (easy to read).
  static TextStyle get modeTileLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: HesakColors.textPrimary,
  );

  /// Name under the selected mode tile. 13.5 / Bold / purple.
  static TextStyle get modeTileLabelSelected => TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    color: HesakColors.modeSelected,
  );

  /// Mode name on the purple card header ("النوم"). 20 / Bold / white.
  static TextStyle get modeHeaderName => TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: HesakColors.onPrimary,
  );

  /// Schedule line on the purple card header. 12 / Regular / soft white.
  static TextStyle get modeHeaderSubtitle => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: HesakColors.onModeHeaderSoft,
  );

  /// Value in the settings summary ("4 أصوات", "مفعّل"). 12.5 / Regular / grey.
  static TextStyle get modeSummaryValue => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: HesakColors.textSecondary,
  );

  /// Small grey hints on the الأوضاع page ("اضغط للتفعيل", "اضغط زر الاستماع ..."). 12 / Regular / grey.
  static TextStyle get modeHint => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: HesakColors.textSecondary,
  );

  /// Mode name in the list rows of the الأوضاع page. 15 / Bold.
  static TextStyle get modeRowName => TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: HesakColors.textPrimary,
  );
}
