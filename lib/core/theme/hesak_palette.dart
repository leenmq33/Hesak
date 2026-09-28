import 'package:flutter/material.dart';
import 'hesak_colors.dart';

// =====================================================================
//  HESAK PALETTE — light / dark (المظهر: فاتح / داكن)
//
//  TRIAL: for now only the الإعدادات page and the bottom bar follow the
//  appearance. The other pages still use HesakColors directly (always light).
//  When the team approves dark mode, every page will switch from
//  `HesakColors.xxx` to `HesakPalette.current.xxx` (one big change, done
//  together so nobody's work clashes).
//
//  How to use in a widget that should follow the appearance:
//    ListenableBuilder(
//      listenable: HesakThemeController.instance,
//      builder: (context, _) {
//        final palette = HesakPalette.current;
//        return Container(color: palette.background, ...);
//      },
//    )
//
//  NAMING: public types start with "Hesak". Light values come from
//  HesakColors (so they always match the rest of the app).
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

  /// Changes the appearance (every listening widget rebuilds).
  /// TODO: save the choice on the phone so it stays after restarting the app.
  void setAppearance(HesakAppearance appearance) {
    if (appearance == _appearance) return;
    _appearance = appearance;
    notifyListeners();
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
    background: HesakColors.background,
    surface: HesakColors.surface,
    surfaceBorder: HesakColors.surfaceBorder,
    divider: HesakColors.listDivider,
    title: HesakColors.primaryDark,
    textPrimary: HesakColors.textPrimary,
    textSecondary: HesakColors.textSecondary,
    iconInactive: HesakColors.iconInactive,
    accent: HesakColors.primary,
    onAccent: HesakColors.onPrimary,
    accentSoft: HesakColors.primaryLight,
    accentSoftBorder: HesakColors.primaryLightBorder,
    headerLines: HesakColors.lavenderAccent,
    fieldFill: HesakColors.fieldFill,
    fieldHint: HesakColors.fieldHint,
    noteFill: HesakColors.infoBannerFill,
    noteBorder: HesakColors.infoBannerBorder,
    noteText: HesakColors.infoBannerText,
    danger: HesakColors.urgent,
    success: HesakColors.passwordRuleMet,
    navBar: HesakColors.navBar,
    navPill: HesakColors.primaryLight,
    navSelected: HesakColors.primaryMuted,
    modeMenuBackdrop: HesakColors.modeMenuBackdrop,
    modeMenuBackdropBorder: HesakColors.modeMenuBackdropBorder,
  );

  /// داكن — very dark purple (not pure black) so it still feels like Hesak.
  /// Accents are a LIGHTER purple so they stand out on the dark background.
  static const HesakPalette dark = HesakPalette(
    background: Color(0xFF17121D),
    surface: Color(0xFF221B2B),
    surfaceBorder: Color(0xFF342A40),
    divider: Color(0xFF342A40),
    title: Color(0xFFD9C8F2),
    textPrimary: Color(0xFFF1ECF6),
    textSecondary: Color(0xFFB3A9C1),
    iconInactive: Color(0xFF8C8299),
    accent: Color(0xFFB79BE0),
    onAccent: Color(0xFF1E1628),
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
    navSelected: Color(0xFFB79BE0),
    modeMenuBackdrop: Color(0xE6221B2B),
    modeMenuBackdropBorder: Color(0x6655456B),
  );

  /// The palette of the current appearance.
  static HesakPalette get current => HesakThemeController.instance.isDark ? dark : light;
}
