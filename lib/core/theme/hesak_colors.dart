import 'package:flutter/material.dart';

/// ALL colors used in the Hesak app live here.
///
/// Rules for the team:
/// - Never write `Color(0xFF......)` inside a screen. Use `HesakColors.xxx`.
/// - Need a new color? Add it here first (with a comment), then use it.
/// - Names describe the ROLE of the color (what it's for), not how it looks.
class HesakColors {
  HesakColors._(); // Prevents creating an instance: use HesakColors.xxx directly

  // ---------------------------------------------------------------
  // Brand purples
  // ---------------------------------------------------------------

  /// Darkest purple: page titles, greeting, splash tagline. Close to the logo color.
  static const Color primaryDark = Color(0xFF3F2A73);

  /// Main purple: big buttons (listen button), chip text, icons inside boxes.
  static const Color primary = Color(0xFF553C6E);

  /// Softer purple: nav bar middle (mode) button and the selected tab icon.
  static const Color primaryMuted = Color(0xFF6A4F8F);

  /// Light purple fill: chips, icon boxes, selected tab pill, mode wheel circles.
  static const Color primaryLight = Color(0xFFE9E1F4);

  /// Border for light purple things (chips, mode wheel circles).
  static const Color primaryLightBorder = Color(0xFFCBBDE0);

  /// Lavender accent: the thin divider under page titles.
  static const Color lavenderAccent = Color(0xFFB7A6DD);

  /// Very light lavender: the decorative waves in the header.
  static const Color headerWaves = Color(0xFFC4B5EC);

  // ---------------------------------------------------------------
  // Backgrounds & surfaces
  // ---------------------------------------------------------------

  /// Main page background (warm off-white).
  static const Color background = Color(0xFFF9F7F5);

  /// Cards, search bar, tabs (a soft matte white, not bright white).
  static const Color surface = Color(0xFFF8F6F7);

  /// Very soft outline around cards.
  static const Color surfaceBorder = Color(0xFFEDE8EF);

  /// Bottom navigation bar background (a touch darker than the page).
  static const Color navBar = Color(0xFFF3EFF4);

  /// Thin lines between rows inside a card.
  static const Color listDivider = Color(0xFFEAE4EE);

  /// See-through half-circle behind the mode wheel (~70% opacity).
  static const Color modeMenuBackdrop = Color(0xB3F7F3FB);

  /// Thin outline of that half-circle (~40% opacity).
  static const Color modeMenuBackdropBorder = Color(0x66CBBDE0);

  // ---------------------------------------------------------------
  // Text & icons
  // ---------------------------------------------------------------

  /// Main text: card titles, item titles, "اضغط للاستماع".
  static const Color textPrimary = Color(0xFF2E2440);

  /// Secondary text: subtitles / descriptions.
  static const Color textSecondary = Color(0xFF7D7390);

  /// Faded text: times like "منذ ساعة", hints.
  static const Color textMuted = Color(0xFFB0A8BD);

  /// Unselected icons (nav bar tabs).
  static const Color iconInactive = Color(0xFFA59DB3);

  /// Text/icons on purple backgrounds.
  static const Color onPrimary = Colors.white;

  // ---------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------

  /// Urgent / new: "الآن" on a new alert, errors.
  static const Color urgent = Color(0xFFB3261E);

  // ---------------------------------------------------------------
  // Splash + sign in / sign up screens
  // ---------------------------------------------------------------

  /// Purple background, lighter at the top (splash, welcome).
  static const Color authGradientLight = Color(0xFFADA1BB);

  /// Purple background, darker at the bottom (splash, welcome).
  static const Color authGradientDark = Color(0xFF76638B);

    /// Splash background gradient (top-left -> bottom-right), as agreed in the guide.
  static const List<Color> splashGradient = [
    Color(0xFFF0E6FF),
    Color(0xFFFCF9FF),
    Color(0xFFF3E9FF),
  ];
  /// Main button (إنشاء حساب, تسجيل الدخول, التالي, حفظ).
  static const Color buttonPrimary = Color(0xFF6B5578);

  /// Lighter purple button (not used on the welcome screen anymore — the
  /// welcome buttons are glass now). Kept for other pages that need it.
  static const Color buttonSecondary = Color(0xFFB4A8C2);

  /// Text on the lighter second button.
  static const Color onButtonSecondary = Color(0xFFF6F2F9);

  /// Grey fill of text fields (email, password ...).
  static const Color fieldFill = Color(0xFFE8E7E8);

  /// Placeholder text and icons inside text fields.
  static const Color fieldHint = Color(0xFF8E8A93);

  /// Light pink box with a note (e.g. "سيستخدم حِسّك هذا الصوت...").
  static const Color infoBannerFill = Color(0xFFFFF5F5);

  /// Border of the note box.
  static const Color infoBannerBorder = Color(0xFFE3A1A8);

  /// Text and icon of the note box.
  static const Color infoBannerText = Color(0xFFA33A45);

  /// Password rule that is met (green dot with a check).
  static const Color passwordRuleMet = Color(0xFF5BAE7F);

  /// Password rule that is not met yet (empty grey dot).
  static const Color passwordRuleUnmet = Color(0xFFD9D6DD);

  // ---- Moving (breathing) background of the sign in / sign up screens ----
  // Only our purples: the background slowly shifts between these tones.

  /// Top color of the moving background, moment A (= the light purple).
  static const Color authBreathTopA = authGradientLight;

  /// Top color of the moving background, moment B (a touch deeper purple).
  static const Color authBreathTopB = Color(0xFF9C8DB0);

  /// Bottom color of the moving background, moment A (= the dark purple).
  static const Color authBreathBottomA = authGradientDark;

  /// Bottom color of the moving background, moment B (= the button purple).
  static const Color authBreathBottomB = buttonPrimary;

  /// Soft light blobs that drift slowly over the moving background (~25% opacity).
  static const Color authBreathGlow = Color(0x40E9E1F4);

  /// Edge of those blobs (same color, fully transparent) so they fade out softly.
  static const Color authBreathGlowEdge = Color(0x00E9E1F4);

  // ---- Glass buttons on the welcome screen ----

  /// "إنشاء حساب" (main): thick white glass (~62% opacity).
  static const Color glassPrimaryFill = Color(0x9EFFFFFF);

  /// Border of the main glass button (~90% white).
  static const Color glassPrimaryBorder = Color(0xE6FFFFFF);

  /// "تسجيل الدخول" (second): very light glass (~10% white).
  static const Color glassSecondaryFill = Color(0x1AFFFFFF);

  /// Border of the second glass button (~55% white).
  static const Color glassSecondaryBorder = Color(0x8CFFFFFF);

  /// Soft purple shadow under the main glass button.
  static const Color glassShadow = Color(0x333F2A73);

  /// Splash decorative corner shape (top-left), used at 18% opacity.
  static const Color splashShapeTop = Color(0xFFBFA3E8);

  /// Splash decorative corner shape (bottom-right), used at 20% opacity.
  static const Color splashShapeBottom = Color(0xFFCAB3EE);

  // ---------------------------------------------------------------
  // Modes page (الأوضاع)
  // ---------------------------------------------------------------

  /// Selected mode circle, selected chips, save buttons on the modes page.
  /// Same deep purple as the listen button, so "selected / important" looks the same everywhere.
  static const Color modeSelected = primary;

  /// Soft ring around the selected mode circle.
  static const Color modeSelectedRing = primaryLight;

  /// Grey fill of a mode circle that is NOT selected.
  static const Color modeUnselectedFill = Color(0xFFECEAEF);

  /// Dark background of the small message at the bottom ("تمت إضافة ...").
  static const Color toastBackground = textPrimary;

  /// Delete buttons / delete confirmation (same red as errors).
  static const Color danger = urgent;

  /// Very light purple fill of the selected mode tile (top row of the modes page).
  static const Color modeTileSelectedFill = Color(0xFFF7F3FB);

  /// See-through white on the purple mode card header (icon circle, star button) (~18%).
  static const Color modeHeaderOverlay = Color(0x2EFFFFFF);

  /// Soft white text on the purple mode card header (schedule line) (~90%).
  static const Color onModeHeaderSoft = Color(0xE6FFFFFF);

  /// Green dot of "مفعّل الآن".
  static const Color activeDot = passwordRuleMet;

  /// Mode card header while listening is OFF (غير مفعّل): a lighter purple.
  static const Color modeHeaderIdleStart = Color(0xFF9585B0);
  static const Color modeHeaderIdleEnd = Color(0xFF7D6A9A);

  /// Grey dot in the "غير مفعّل" badge.
  static const Color idleDot = iconInactive;

  // ---------------------------------------------------------------
  // Home page (الرئيسية)
  // ---------------------------------------------------------------

  /// Light lavender page background of الرئيسية (under the purple top).
  static const Color homePageBackground = Color(0xFFF6F3F9);

  /// Middle tone of the purple top (between the dark purple and the lavender).
  static const Color homeHeroMiddle = Color(0xFF8F7FA3);

  /// Purple top of الرئيسية: dark purple at the top, fades into the lavender page.
  static const List<Color> homeHeroGradient = [
    primary,
    buttonPrimary,
    homeHeroMiddle,
    primaryLightBorder,
    homePageBackground,
  ];

  /// Where each color of [homeHeroGradient] sits (0 = top, 1 = bottom).
  static const List<double> homeHeroGradientStops = [0.0, 0.28, 0.55, 0.78, 1.0];

  /// Header waves + divider on the purple top (~40% white).
  static const Color homeHeaderLinesOnPurple = Color(0x66FFFFFF);

  /// Soft white circles (halos) around the listen button (~12% white).
  static const Color homeHaloFill = Color(0x1FFFFFFF);

  /// Outline of those halos (~40% white).
  static const Color homeHaloBorder = Color(0x66FFFFFF);

  /// Empty part of the turning ring while listening (~25% white).
  static const Color homeListenTrack = Color(0x40FFFFFF);

  /// White listen button (before listening): white -> very light lavender.
  static const List<Color> homeListenButtonIdle = [surface, modeTileSelectedFill, primaryLight];

  /// Purple listen button (while listening).
  static const List<Color> homeListenButtonActive = [primaryMuted, primary];

  /// Dark soft shadow under the listen button.
  static const Color homeListenShadow = Color(0x47201430);

  /// Light red box behind an urgent alert icon (e.g. إنذار حريق).
  static const Color homeUrgentIconFill = Color(0xFFFBE9E7);

  /// Current mode card while listening is OFF (light lavender).
  static const Color homeModeCardIdle = Color(0xFFF3EEF9);

  /// Outline of the mode card, its tiles and the schedule box.
  static const Color homeModeCardIdleBorder = Color(0xFFE6DEF0);

  /// Yellow of a favorite mode's star (الأوضاع المفضلة), on light and purple.
  static const Color favoriteStar = Color(0xFFF2C14E);

  /// Light lavender background of the 4 main tabs
  /// (الرئيسية bottom, المحادثات, الأوضاع, الإعدادات in فاتح).
  static const Color tabPageBackground = homePageBackground;

  /// Purple-ish band behind the listen button (الرئيسية), from under the
  /// greeting: light header -> lavender -> soft purple -> lavender page.
  static const List<Color> homeListenBandGradient = [
    background,
    Color(0xFFF5F1F8),
    primaryLight,
    primaryLightBorder,
    Color(0xFFA897BD),
    Color(0xFFA897BD),
    primaryLightBorder,
    tabPageBackground,
  ];

  /// Where each color of [homeListenBandGradient] sits (0 = top of the page).
  static const List<double> homeListenBandStops = [0.0, 0.22, 0.29, 0.37, 0.47, 0.60, 0.73, 0.88];
}