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

  /// Cards (slightly lighter than the background).
  static const Color surface = Color(0xFFFEFDFB);

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
  // Splash screen only
  // ---------------------------------------------------------------

  /// Splash background gradient (top-left -> bottom-right).
  static const List<Color> splashGradient = [
    Color(0xFFF0E6FF),
    Color(0xFFFCF9FF),
    Color(0xFFF3E9FF),
  ];

  /// Splash decorative corner shape (top-left), used at 18% opacity.
  static const Color splashShapeTop = Color(0xFFBFA3E8);

  /// Splash decorative corner shape (bottom-right), used at 20% opacity.
  static const Color splashShapeBottom = Color(0xFFCAB3EE);
}
