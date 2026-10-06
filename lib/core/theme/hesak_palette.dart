import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'hesak_colors.dart';

// =====================================================================
//  HESAK PALETTE — light / dark (المظهر: فاتح / داكن)
//
//  The WHOLE app follows the appearance:
//  - Most screens use HesakColors.xxx, which gives the light or dark color
//    by itself (hesak_colors.dart).
//  - الإعدادات and the bottom bar use this palette (same idea, older code).
//  When the user changes فاتح / داكن, every screen builds again (see
//  HesakThemeController.setAppearance), so nothing stays in the old colors.
//
//  How to use the palette in a widget:
//    ListenableBuilder(
//      listenable: HesakThemeController.instance,
//      builder: (context, _) {
//        final palette = HesakPalette.current;
//        return Container(color: palette.background, ...);
//      },
//    )
//
//  NAMING: public types start with "Hesak". Light values come from
//  HesakColorsLight (so they always match the rest of the app).
// =====================================================================

/// The two appearances the user can pick in الإعدادات.
enum HesakAppearance { light, dark }

/// Holds the user's appearance choice and tells listeners when it changes.
class HesakThemeController extends ChangeNotifier {
  HesakThemeController._();
  static final HesakThemeController instance = HesakThemeController._();

  HesakAppearance _appearance = HesakAppearance.light;

  /// The current appearance.
  HesakAppearance get appearance => _appearance;

  /// true = dark appearance.
  bool get isDark => _appearance == HesakAppearance.dark;

  /// Key of the choice saved on the phone.
  static const String _phoneKey = 'hesak_appearance';

  /// Reads the last choice made ON THIS PHONE. Called once in main() before
  /// the app starts, so even the splash / sign-in pages open in that look
  /// (nobody is signed in yet, so the account's choice isn't known there).
  Future<void> loadFromPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_phoneKey) == HesakAppearance.dark.name) _appearance = HesakAppearance.dark;
    } catch (e) {
      debugPrint('loadFromPhone error: $e'); // Not saved yet / not available -> light
    }
    _applyStatusBar();
  }

  /// Changes the appearance and remembers it on the phone.
  /// The account copy is saved by AuthService.updateAppearance.
  void setAppearance(HesakAppearance appearance) {
    if (appearance == _appearance) return;
    _appearance = appearance;
    notifyListeners();
    _applyStatusBar();
    _rebuildWholeApp();
    _saveOnPhone(appearance);
  }

  /// Status bar icons: light on dark, dark on light.
  void _applyStatusBar() =>
      SystemChrome.setSystemUIOverlayStyle(isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark);

  Future<void> _saveOnPhone(HesakAppearance appearance) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_phoneKey, appearance.name);
    } catch (e) {
      debugPrint('saveOnPhone error: $e');
    }
  }

  /// Every screen reads its colors (HesakColors.xxx) while it builds. So after
  /// a change, we ask EVERY widget — the open page, the pages kept in the
  /// other tabs, open windows — to build again. Nothing is lost: the open
  /// pages, typed text and scroll position all stay.
  static void _rebuildWholeApp() {
    final Element? root = WidgetsBinding.instance.rootElement;
    if (root == null) return;
    void markForRebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(markForRebuild);
    }

    root.visitChildren(markForRebuild);
  }
}

/// The colors of one appearance. Same names in light and dark.
@immutable
class HesakPalette {
  // ---- Page ----
  final Color background; // Page background
  final Color surface; // Cards
  final Color surfaceBorder; // Card outline
  final Color divider; // Thin lines between rows
  final Color cardBorder; // Outline of the white content cards (الإعدادات)
  final Color cardShadow; // Soft shadow under those cards
  final Color rowLine; // Lines between the rows inside those cards
  final Color iconBox; // Small square behind a row icon

  // ---- Text & icons ----
  final Color title; // Page titles
  final Color textPrimary; // Main text
  final Color textSecondary; // Small / secondary text
  final Color iconInactive; // Unselected icons

  // ---- Purple accents ----
  final Color accent; // Selected items, main buttons, links
  final Color onAccent; // Text/icons on top of [accent]
  final Color accentSoft; // Light fill behind selected things / icon boxes
  final Color accentSoftBorder; // Outline of soft purple things
  final Color headerLines; // Header waves + divider

  // ---- Fields ----
  final Color fieldFill; // Text field fill
  final Color fieldHint; // Placeholder text / field icons

  // ---- Note box (pink) ----
  final Color noteFill;
  final Color noteBorder;
  final Color noteText;

  // ---- Status ----
  final Color danger; // Delete / log out / errors
  final Color success; // Green check

  // ---- Bottom bar ----
  final Color navBar; // Bar fill
  final Color navPill; // Pill behind the selected tab
  final Color navSelected; // Selected tab icon/label, active mode on the wheel
  final Color modeMenuBackdrop; // Half circle behind the mode wheel
  final Color modeMenuBackdropBorder;

  const HesakPalette({
    required this.background,
    required this.surface,
    required this.surfaceBorder,
    required this.divider,
    required this.cardBorder,
    required this.cardShadow,
    required this.rowLine,
    required this.iconBox,
    required this.title,
    required this.textPrimary,
    required this.textSecondary,
    required this.iconInactive,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.accentSoftBorder,
    required this.headerLines,
    required this.fieldFill,
    required this.fieldHint,
    required this.noteFill,
    required this.noteBorder,
    required this.noteText,
    required this.danger,
    required this.success,
    required this.navBar,
    required this.navPill,
    required this.navSelected,
    required this.modeMenuBackdrop,
    required this.modeMenuBackdropBorder,
  });

  /// فاتح — exactly the colors the app already uses.
  static const HesakPalette light = HesakPalette(
    background: HesakColorsLight.tabPageBackground, // Lavender like the other tabs
    surface: HesakColorsLight.surface,
    surfaceBorder: HesakColorsLight.surfaceBorder,
    divider: HesakColorsLight.listDivider,
    // Same white cards as الرئيسية (purple outline + soft shadow).
    cardBorder: HesakColorsLight.homeCardBorder,
    cardShadow: HesakColorsLight.homeCardShadow,
    rowLine: HesakColorsLight.settingsRowLine,
    iconBox: HesakColorsLight.settingsIconBox,
    title: HesakColorsLight.primaryDark,
    textPrimary: HesakColorsLight.textPrimary,
    textSecondary: HesakColorsLight.textSecondary,
    iconInactive: HesakColorsLight.iconInactive,
    accent: HesakColorsLight.primary,
    onAccent: HesakColorsLight.onPrimary,
    accentSoft: HesakColorsLight.primaryLight,
    accentSoftBorder: HesakColorsLight.primaryLightBorder,
    headerLines: HesakColorsLight.lavenderAccent,
    fieldFill: HesakColorsLight.fieldFill,
    fieldHint: HesakColorsLight.fieldHint,
    noteFill: HesakColorsLight.infoBannerFill,
    noteBorder: HesakColorsLight.infoBannerBorder,
    noteText: HesakColorsLight.infoBannerText,
    danger: HesakColorsLight.urgent,
    success: HesakColorsLight.passwordRuleMet,
    navBar: HesakColorsLight.navBar,
    navPill: HesakColorsLight.primaryLight,
    navSelected: HesakColorsLight.primaryMuted,
    modeMenuBackdrop: HesakColorsLight.modeMenuBackdrop,
    modeMenuBackdropBorder: HesakColorsLight.modeMenuBackdropBorder,
  );

  /// داكن — very dark purple (not pure black) so it still feels like Hesak.
  /// Accents are a LIGHTER purple so they stand out on the dark background.
  static const HesakPalette dark = HesakPalette(
    background: Color(0xFF17121D),
    surface: Color(0xFF221B2B),
    surfaceBorder: Color(0xFF342A40),
    divider: Color(0xFF342A40),
    cardBorder: Color(0xFF342A40),
    cardShadow: Color(0x33000000),
    rowLine: Color(0xFF342A40),
    iconBox: Color(0xFF3A2E4B),
    title: Color(0xFFD9C8F2),
    textPrimary: Color(0xFFF1ECF6),
    textSecondary: Color(0xFFB3A9C1),
    iconInactive: Color(0xFF8C8299),
    // Same purple as HesakColorsDark.primary, so الإعدادات matches the other pages.
    accent: HesakColorsDark.primary,
    onAccent: HesakColorsDark.onPrimary,
    accentSoft: Color(0xFF3A2E4B),
    accentSoftBorder: Color(0xFF55456B),
    headerLines: Color(0xFF6E5A8C),
    fieldFill: Color(0xFF2E2638),
    fieldHint: Color(0xFF9A90A8),
    noteFill: Color(0xFF3A2328),
    noteBorder: Color(0xFF8C4A55),
    noteText: Color(0xFFF2B8BF),
    danger: Color(0xFFF2B8B5),
    success: Color(0xFF7FC99C),
    navBar: Color(0xFF1F1827),
    navPill: Color(0xFF3A2E4B),
    navSelected: HesakColorsDark.primaryMuted,
    modeMenuBackdrop: Color(0xE6221B2B),
    modeMenuBackdropBorder: Color(0x6655456B),
  );

  /// The palette of the current appearance.
  static HesakPalette get current => HesakThemeController.instance.isDark ? dark : light;
}