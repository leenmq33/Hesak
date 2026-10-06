import 'package:flutter/material.dart';

import 'hesak_palette.dart';

/// ALL colors used in the Hesak app live here.
///
/// Rules for the team:
/// - Never write `Color(0xFF......)` inside a screen. Use `HesakColors.xxx`.
/// - Need a new color? Add it here first (with a comment), then use it.
/// - Names describe the ROLE of the color (what it's for), not how it looks.
///
/// LIGHT + DARK (المظهر: فاتح / داكن):
/// - [HesakColorsLight] = the light colors (below, with the comments).
/// - [HesakColorsDark]  = the same names with the dark colors.
/// - [HesakColors]      = what the screens use: it gives the light OR the dark
///   color, depending on the user's choice in الإعدادات. So screens never ask
///   "is it dark?" — they just write `HesakColors.xxx`.
/// - New color? Add it to BOTH classes, then add its line in [HesakColors].
/// - Because the color can change, `HesakColors.xxx` is not `const`:
///   don't write `const` in front of a widget that uses it.
class HesakColorsLight {
  HesakColorsLight._(); // Prevents creating an instance

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

  /// Very light lavender page background behind the cards (الرئيسية and the other tabs).
  /// The cards on top are the darker purple, so they stand out.
  static const Color homePageBackground = Color(0xFFF6F3F9);

  /// Light lavender at the very top (behind the logo + greeting) — not white.
  static const Color homeHeaderTint = Color(0xFFF2EEF6);

  /// Long soft band behind the listen button: header tint -> purple behind
  /// the button -> back to the page background. No hard line anywhere.
  static const List<Color> homeListenBandGradient = [
    homeHeaderTint,
    Color(0xFFEFE9F6),
    Color(0xFFE5DBF0),
    Color(0xFFD4C6E7),
    Color(0xFFBFAED9),
    Color(0xFFAE9BCB),
    Color(0xFFAA97C8),
    Color(0xFFB8A7D3),
    Color(0xFFCBBDE1),
    Color(0xFFE6DDF1),
    homePageBackground,
  ];

  /// Where each color of [homeListenBandGradient] sits (0 = top of the page).
  static const List<double> homeListenBandStops = [
    0.0, 0.18, 0.27, 0.35, 0.42, 0.49, 0.54, 0.63, 0.74, 0.85, 1.0,
  ];

  /// Header waves + divider on a purple background (~40% white). (Kept for the header option.)
  static const Color homeHeaderLinesOnPurple = Color(0x66FFFFFF);

  // ---- Listen button ----

  /// One soft circle around the button before listening (~16% light lavender).
  static const Color homeHaloFill = Color(0x29F6F2F9);

  /// Outline of that circle and of the rings while listening (~50%).
  static const Color homeHaloBorder = Color(0x80F6F2F9);

  /// Empty part of the turning ring while listening (~30%).
  static const Color homeListenTrack = Color(0x4DF6F2F9);

  /// Light lavender of the button / rings (never pure white).
  static const Color homeListenLight = Color(0xFFF6F2F9);

  /// Button before listening: light lavender (not white).
  static const List<Color> homeListenButtonIdle = [homeListenLight, Color(0xFFEDE6F4), Color(0xFFE1D6EE)];

  /// Button while listening: very dark purple.
  static const List<Color> homeListenButtonActive = [primary, primaryDark];

  /// Dark soft shadow under the listen button.
  static const Color homeListenShadow = Color(0x47201430);

  // ---- Cards (الأصوات الحالية · محادثات اليوم · التنبيهات) ----

  /// Soft lavender (used behind the open schedule editor on the mode card).
  static const List<Color> homeCardGradient = [Color(0xFFECE6F3), Color(0xFFE6DEF0)];

  /// Thin purple outline of the cards.
  static const Color homeCardBorder = Color(0xFFCDBFDE);

  /// Deeper soft shadow under the cards.
  static const Color homeCardShadow = Color(0x243F2A73);

  // All 3 cards (الأصوات الحالية · محادثات اليوم · التنبيهات) are matte white
  // (HesakColors.surface); what's inside them is light purple.

  /// Things inside a white card: sound chips, conversation rows, alert icon boxes.
  static const Color homeItemFill = Color(0xFFE6DEF0);

  /// Thin outline of the sound chips.
  static const Color homeChipBorder = Color(0xFFDED3EC);

  /// Thin lines between the alerts.
  static const Color homeCardDivider = Color(0xFFEAE3F2);

  /// Icon box inside a conversation row (one step darker than the row).
  static const Color homeCardIconBox = Color(0xFFD3C6E3);

  /// Box behind an urgent alert icon (e.g. إنذار حريق).
  static const Color homeUrgentIconFill = Color(0xFFEED5D8);

  // ---- Alerts (التنبيهات): white boxes with a colored line on the side ----

  /// Fill of each alert box.
  static const Color homeAlertFill = Color(0xFFFFFFFF);

  /// Very soft shadow under each alert box.
  static const Color homeAlertShadow = Color(0x0F3F2A73);

  /// Box behind a normal alert icon (same light lavender as الإعدادات).
  static const Color homeAlertIconFill = Color(0xFFEFE8F7);

  /// Side line of a normal alert (urgent ones use [urgent]).
  static const Color homeAlertLine = primary;

  // ---- Mode card ----

  /// Mode card while listening is OFF (same light purple as الأوضاع).
  static const List<Color> homeModeCardIdle = [modeHeaderIdleStart, modeHeaderIdleEnd];

  /// Mode card while listening is ON: very dark purple.
  static const List<Color> homeModeCardActive = [primary, primaryDark];

  /// Thin dark outline of the mode card (~35%).
  static const Color homeModeCardBorder = Color(0x593F2A73);

  /// See-through glass boxes on the mode card (tiles, schedule) (~14% white).
  static const Color homeGlassFill = Color(0x24FFFFFF);

  /// Outline of the glass boxes (~22% white).
  static const Color homeGlassBorder = Color(0x38FFFFFF);

  /// Icon circles on the glass boxes (~20% white).
  static const Color homeGlassIcon = Color(0x33FFFFFF);

  /// Text / icons on the mode card (light lavender, not white).
  static const Color onHomeGlass = Color(0xFFF3EEF8);

  /// Small text on the mode card (~75%).
  static const Color onHomeGlassSoft = Color(0xBFF3EEF8);

  /// Yellow of a favorite mode's star (الأوضاع المفضلة), on light and purple.
  static const Color favoriteStar = Color(0xFFF2C14E);

  /// Background of the 4 main tabs (الرئيسية, المحادثات, الأوضاع, الإعدادات in فاتح).
  static const Color tabPageBackground = homePageBackground;

  /// المحادثات list cards: lavender on the icon side fading to light
  /// on the other side (start -> end).
  static const List<Color> chatsCardGradient = [Color(0xFFE3D9F0), Color(0xFFF6F2FA)];

  /// Thin outline of the المحادثات list cards.
  static const Color chatsCardBorder = Color(0xFFD8CCE8);

  /// Inside one conversation: very light purple (same as the pages), so the
  /// purple voice messages stand out from it.
  static const Color chatsConversationBackground = tabPageBackground;

  // =====================================================================
  //  ROUND 5 — الأوضاع rows, the details under the arrow, the schedule,
  //  and the white cards of تعديل / إضافة وضع and الإعدادات.
  // =====================================================================

  // ---- الأوضاع: the NOT selected modes ----

  /// Lavender gradient of a not selected mode card (start -> end):
  /// the SAME as the المحادثات cards (lavender on the icon side, fading to light).
  static const List<Color> modesCardGradient = chatsCardGradient;

  /// Thin outline of the mode cards and of the white boxes under the arrow.
  static const Color modesCardBorder = Color(0xFFDCD1EA);

  /// White circle behind the icon of a not selected mode (and the small buttons).
  static const Color modesIconCircle = Color(0xFFFFFFFF);

  // ---- الأوضاع: under the arrow ⌄ ----

  /// "إعدادات الوضع" box (white).
  static const Color modesDetailsFill = Color(0xFFFFFFFF);

  /// One small view-only tile inside "إعدادات الوضع".
  static const Color modesInfoTileFill = Color(0xFFF7F3FB);

  /// "جدولة الوضع" header: a darker lavender, so it looks different from the settings.
  static const Color modesScheduleHeaderFill = Color(0xFFEDE4F7);

  /// Outline of the "جدولة الوضع" box.
  static const Color modesScheduleBorder = primaryLightBorder;

  /// Inside the open "جدولة الوضع" box.
  static const Color modesScheduleBodyFill = Color(0xFFF6F1FB);

  // ---- الأوضاع: "اضغط زر الاستماع ..." strip under the selected mode ----

  static const Color modesHintStripFill = Color(0xFFE4D9F1);
  static const Color modesHintStripLine = primaryLightBorder;
  static const Color modesHintStripText = primary;

  // ---- The schedule periods (same shape everywhere) ----

  /// A period box inside a WHITE card (تعديل / إضافة وضع).
  static const Color schedulePeriodFill = Color(0xFFF3EEF9);
  static const Color schedulePeriodBorder = Color(0xFFD9CCEC);

  /// A period box on a lavender background (الأوضاع) = white.
  static const Color schedulePeriodOnLavenderFill = Color(0xFFFFFFFF);

  /// Dashed outline of "إضافة فترة".
  static const Color scheduleAddBorder = primaryLightBorder;

  // ---- White content cards (تعديل / إضافة وضع، الإعدادات) ----

  /// Line under the title of a card that opens (جدولة الوضع، الإعدادات العامة ...).
  static const Color cardTitleLine = Color(0xFFDCD1EA);

  /// Lines between the rows of الإعدادات.
  static const Color settingsRowLine = Color(0xFFE6DEF0);

  /// Small square behind a row icon in الإعدادات.
  static const Color settingsIconBox = Color(0xFFEFE8F7);

  // ---- الرئيسية: mode card tiles + schedule periods ----

  /// Tiles (نوع التنبيه، نداء اسمك) and period boxes while listening is OFF.
  static const Color homeTileFillIdle = Color(0xFFFFFFFF);

  /// The same while listening is ON (a little lavender on the dark card).
  static const Color homeTileFillActive = Color(0xFFF1ECF7);

  /// Outline of those tiles / period boxes.
  static const Color homeTileBorder = Color(0xFFC9B8E0);

  /// Line under "الجدولة" when the glass box is open.
  static const Color homeGlassLine = Color(0x40FFFFFF);
}

/// The dark colors (خيار أ — بنفسجي ليلي). Same names as [HesakColorsLight].
/// Colors that sit on purple (glass, white text on purple, the star, the
/// sign-in purple background) stay the same as light.
class HesakColorsDark {
  HesakColorsDark._();

  static const Color primaryDark = Color(0xFFD9C8F2);
  static const Color primary = Color(0xFF9474C4);
  static const Color primaryMuted = Color(0xFFA88BD6);
  static const Color primaryLight = Color(0xFF3A2E4B);
  static const Color primaryLightBorder = Color(0xFF55456B);
  static const Color lavenderAccent = Color(0xFF6E5A8C);
  static const Color headerWaves = Color(0xFF4A3D5E);
  static const Color background = Color(0xFF17121D);
  static const Color surface = Color(0xFF221B2B);
  static const Color surfaceBorder = Color(0xFF342A40);
  static const Color navBar = Color(0xFF1F1827);
  static const Color listDivider = Color(0xFF342A40);
  static const Color modeMenuBackdrop = Color(0xE6221B2B);
  static const Color modeMenuBackdropBorder = Color(0x6655456B);
  static const Color textPrimary = Color(0xFFF1ECF6);
  static const Color textSecondary = Color(0xFFB3A9C1);
  static const Color textMuted = Color(0xFF8C8299);
  static const Color iconInactive = Color(0xFF8C8299);
  static const Color onPrimary = HesakColorsLight.onPrimary;
  static const Color urgent = Color(0xFFF28B85);
  static const Color authGradientLight = HesakColorsLight.authGradientLight;
  static const Color authGradientDark = HesakColorsLight.authGradientDark;
  static const List<Color> splashGradient = HesakColorsLight.splashGradient;
  static const Color buttonPrimary = HesakColorsLight.buttonPrimary;
  static const Color buttonSecondary = HesakColorsLight.buttonSecondary;
  static const Color onButtonSecondary = HesakColorsLight.onButtonSecondary;
  static const Color fieldFill = Color(0xFF2E2638);
  static const Color fieldHint = Color(0xFF9A90A8);
  static const Color infoBannerFill = Color(0xFF3A2328);
  static const Color infoBannerBorder = Color(0xFF8C4A55);
  static const Color infoBannerText = Color(0xFFF2B8BF);
  static const Color passwordRuleMet = Color(0xFF7FC99C);
  static const Color passwordRuleUnmet = Color(0xFF4A4054);
  static const Color authBreathTopA = HesakColorsLight.authBreathTopA;
  static const Color authBreathTopB = HesakColorsLight.authBreathTopB;
  static const Color authBreathBottomA = HesakColorsLight.authBreathBottomA;
  static const Color authBreathBottomB = HesakColorsLight.authBreathBottomB;
  static const Color authBreathGlow = HesakColorsLight.authBreathGlow;
  static const Color authBreathGlowEdge = HesakColorsLight.authBreathGlowEdge;
  static const Color glassPrimaryFill = HesakColorsLight.glassPrimaryFill;
  static const Color glassPrimaryBorder = HesakColorsLight.glassPrimaryBorder;
  static const Color glassSecondaryFill = HesakColorsLight.glassSecondaryFill;
  static const Color glassSecondaryBorder = HesakColorsLight.glassSecondaryBorder;
  static const Color glassShadow = HesakColorsLight.glassShadow;
  static const Color splashShapeTop = HesakColorsLight.splashShapeTop;
  static const Color splashShapeBottom = HesakColorsLight.splashShapeBottom;
  static const Color modeSelected = primary;
  static const Color modeSelectedRing = primaryLight;
  static const Color modeUnselectedFill = Color(0xFF2E2638);
  static const Color toastBackground = Color(0xFF3A2E4B);
  static const Color danger = urgent;
  static const Color modeTileSelectedFill = Color(0xFF2A2234);
  static const Color modeHeaderOverlay = HesakColorsLight.modeHeaderOverlay;
  static const Color onModeHeaderSoft = HesakColorsLight.onModeHeaderSoft;
  static const Color activeDot = passwordRuleMet;
  static const Color modeHeaderIdleStart = Color(0xFF4A3B63);
  static const Color modeHeaderIdleEnd = Color(0xFF3B2F4E);
  static const Color idleDot = iconInactive;
  static const Color homePageBackground = Color(0xFF17121D);
  static const Color homeHeaderTint = Color(0xFF1F1827);
  static const List<Color> homeListenBandGradient = [homeHeaderTint, Color(0xFF211A2A), Color(0xFF261E31), Color(0xFF2E243B), Color(0xFF382C47), Color(0xFF3F3150), Color(0xFF413252), Color(0xFF3A2D49), Color(0xFF30263D), Color(0xFF221B2C), homePageBackground];
  static const List<double> homeListenBandStops = HesakColorsLight.homeListenBandStops;
  static const Color homeHeaderLinesOnPurple = HesakColorsLight.homeHeaderLinesOnPurple;
  static const Color homeHaloFill = HesakColorsLight.homeHaloFill;
  static const Color homeHaloBorder = HesakColorsLight.homeHaloBorder;
  static const Color homeListenTrack = HesakColorsLight.homeListenTrack;
  static const Color homeListenLight = HesakColorsLight.homeListenLight;
  static const List<Color> homeListenButtonIdle = HesakColorsLight.homeListenButtonIdle;
  static const List<Color> homeListenButtonActive = [Color(0xFF6A4F8F), Color(0xFF3F2A73)];
  static const Color homeListenShadow = Color(0x66000000);
  static const List<Color> homeCardGradient = [Color(0xFF2A2234), Color(0xFF241D2D)];
  static const Color homeCardBorder = Color(0xFF342A40);
  static const Color homeCardShadow = Color(0x33000000);
  static const Color homeItemFill = Color(0xFF2E2638);
  static const Color homeChipBorder = Color(0xFF3E3349);
  static const Color homeCardDivider = Color(0xFF342A40);
  static const Color homeCardIconBox = Color(0xFF3B2F4E);
  static const Color homeUrgentIconFill = Color(0xFF4A2A30);
  static const Color homeAlertFill = Color(0xFF2A2234);
  static const Color homeAlertShadow = Color(0x00000000);
  static const Color homeAlertIconFill = Color(0xFF3A2E4B);
  static const Color homeAlertLine = primary;
  static const List<Color> homeModeCardIdle = [Color(0xFF3B2F4E), Color(0xFF2A2138)];
  static const List<Color> homeModeCardActive = [Color(0xFF553C6E), Color(0xFF2E1F55)];
  static const Color homeModeCardBorder = Color(0xFF342A40);
  static const Color homeGlassFill = HesakColorsLight.homeGlassFill;
  static const Color homeGlassBorder = HesakColorsLight.homeGlassBorder;
  static const Color homeGlassIcon = HesakColorsLight.homeGlassIcon;
  static const Color onHomeGlass = HesakColorsLight.onHomeGlass;
  static const Color onHomeGlassSoft = HesakColorsLight.onHomeGlassSoft;
  static const Color favoriteStar = HesakColorsLight.favoriteStar;
  static const Color tabPageBackground = homePageBackground;
  static const List<Color> chatsCardGradient = [Color(0xFF2E2440), Color(0xFF221B2B)];
  static const Color chatsCardBorder = Color(0xFF342A40);
  static const Color chatsConversationBackground = tabPageBackground;
  static const List<Color> modesCardGradient = chatsCardGradient; // Same as المحادثات
  static const Color modesCardBorder = Color(0xFF3E3349);
  static const Color modesIconCircle = Color(0xFF3A2E4B);
  static const Color modesDetailsFill = Color(0xFF221B2B);
  static const Color modesInfoTileFill = Color(0xFF2A2234);
  static const Color modesScheduleHeaderFill = Color(0xFF33293F);
  static const Color modesScheduleBorder = primaryLightBorder;
  static const Color modesScheduleBodyFill = Color(0xFF261F2F);
  static const Color modesHintStripFill = Color(0xFF33293F);
  static const Color modesHintStripLine = primaryLightBorder;
  static const Color modesHintStripText = Color(0xFFD9C8F2);
  static const Color schedulePeriodFill = Color(0xFF2A2234);
  static const Color schedulePeriodBorder = Color(0xFF3E3349);
  static const Color schedulePeriodOnLavenderFill = Color(0xFF2E2638);
  static const Color scheduleAddBorder = primaryLightBorder;
  static const Color cardTitleLine = Color(0xFF342A40);
  static const Color settingsRowLine = Color(0xFF342A40);
  static const Color settingsIconBox = Color(0xFF3A2E4B);
  static const Color homeTileFillIdle = Color(0xFF2A2234);
  static const Color homeTileFillActive = Color(0xFF241C30);
  static const Color homeTileBorder = Color(0xFF4A3D5E);
  static const Color homeGlassLine = HesakColorsLight.homeGlassLine;
}

/// What the screens use: the light or dark color of the current appearance.
class HesakColors {
  HesakColors._(); // Use HesakColors.xxx directly

  static bool get _isDark => HesakThemeController.instance.isDark;

  static Color get primaryDark => _isDark ? HesakColorsDark.primaryDark : HesakColorsLight.primaryDark;
  static Color get primary => _isDark ? HesakColorsDark.primary : HesakColorsLight.primary;
  static Color get primaryMuted => _isDark ? HesakColorsDark.primaryMuted : HesakColorsLight.primaryMuted;
  static Color get primaryLight => _isDark ? HesakColorsDark.primaryLight : HesakColorsLight.primaryLight;
  static Color get primaryLightBorder => _isDark ? HesakColorsDark.primaryLightBorder : HesakColorsLight.primaryLightBorder;
  static Color get lavenderAccent => _isDark ? HesakColorsDark.lavenderAccent : HesakColorsLight.lavenderAccent;
  static Color get headerWaves => _isDark ? HesakColorsDark.headerWaves : HesakColorsLight.headerWaves;
  static Color get background => _isDark ? HesakColorsDark.background : HesakColorsLight.background;
  static Color get surface => _isDark ? HesakColorsDark.surface : HesakColorsLight.surface;
  static Color get surfaceBorder => _isDark ? HesakColorsDark.surfaceBorder : HesakColorsLight.surfaceBorder;
  static Color get navBar => _isDark ? HesakColorsDark.navBar : HesakColorsLight.navBar;
  static Color get listDivider => _isDark ? HesakColorsDark.listDivider : HesakColorsLight.listDivider;
  static Color get modeMenuBackdrop => _isDark ? HesakColorsDark.modeMenuBackdrop : HesakColorsLight.modeMenuBackdrop;
  static Color get modeMenuBackdropBorder => _isDark ? HesakColorsDark.modeMenuBackdropBorder : HesakColorsLight.modeMenuBackdropBorder;
  static Color get textPrimary => _isDark ? HesakColorsDark.textPrimary : HesakColorsLight.textPrimary;
  static Color get textSecondary => _isDark ? HesakColorsDark.textSecondary : HesakColorsLight.textSecondary;
  static Color get textMuted => _isDark ? HesakColorsDark.textMuted : HesakColorsLight.textMuted;
  static Color get iconInactive => _isDark ? HesakColorsDark.iconInactive : HesakColorsLight.iconInactive;
  static Color get onPrimary => _isDark ? HesakColorsDark.onPrimary : HesakColorsLight.onPrimary;
  static Color get urgent => _isDark ? HesakColorsDark.urgent : HesakColorsLight.urgent;
  static Color get authGradientLight => _isDark ? HesakColorsDark.authGradientLight : HesakColorsLight.authGradientLight;
  static Color get authGradientDark => _isDark ? HesakColorsDark.authGradientDark : HesakColorsLight.authGradientDark;
  static List<Color> get splashGradient => _isDark ? HesakColorsDark.splashGradient : HesakColorsLight.splashGradient;
  static Color get buttonPrimary => _isDark ? HesakColorsDark.buttonPrimary : HesakColorsLight.buttonPrimary;
  static Color get buttonSecondary => _isDark ? HesakColorsDark.buttonSecondary : HesakColorsLight.buttonSecondary;
  static Color get onButtonSecondary => _isDark ? HesakColorsDark.onButtonSecondary : HesakColorsLight.onButtonSecondary;
  static Color get fieldFill => _isDark ? HesakColorsDark.fieldFill : HesakColorsLight.fieldFill;
  static Color get fieldHint => _isDark ? HesakColorsDark.fieldHint : HesakColorsLight.fieldHint;
  static Color get infoBannerFill => _isDark ? HesakColorsDark.infoBannerFill : HesakColorsLight.infoBannerFill;
  static Color get infoBannerBorder => _isDark ? HesakColorsDark.infoBannerBorder : HesakColorsLight.infoBannerBorder;
  static Color get infoBannerText => _isDark ? HesakColorsDark.infoBannerText : HesakColorsLight.infoBannerText;
  static Color get passwordRuleMet => _isDark ? HesakColorsDark.passwordRuleMet : HesakColorsLight.passwordRuleMet;
  static Color get passwordRuleUnmet => _isDark ? HesakColorsDark.passwordRuleUnmet : HesakColorsLight.passwordRuleUnmet;
  static Color get authBreathTopA => _isDark ? HesakColorsDark.authBreathTopA : HesakColorsLight.authBreathTopA;
  static Color get authBreathTopB => _isDark ? HesakColorsDark.authBreathTopB : HesakColorsLight.authBreathTopB;
  static Color get authBreathBottomA => _isDark ? HesakColorsDark.authBreathBottomA : HesakColorsLight.authBreathBottomA;
  static Color get authBreathBottomB => _isDark ? HesakColorsDark.authBreathBottomB : HesakColorsLight.authBreathBottomB;
  static Color get authBreathGlow => _isDark ? HesakColorsDark.authBreathGlow : HesakColorsLight.authBreathGlow;
  static Color get authBreathGlowEdge => _isDark ? HesakColorsDark.authBreathGlowEdge : HesakColorsLight.authBreathGlowEdge;
  static Color get glassPrimaryFill => _isDark ? HesakColorsDark.glassPrimaryFill : HesakColorsLight.glassPrimaryFill;
  static Color get glassPrimaryBorder => _isDark ? HesakColorsDark.glassPrimaryBorder : HesakColorsLight.glassPrimaryBorder;
  static Color get glassSecondaryFill => _isDark ? HesakColorsDark.glassSecondaryFill : HesakColorsLight.glassSecondaryFill;
  static Color get glassSecondaryBorder => _isDark ? HesakColorsDark.glassSecondaryBorder : HesakColorsLight.glassSecondaryBorder;
  static Color get glassShadow => _isDark ? HesakColorsDark.glassShadow : HesakColorsLight.glassShadow;
  static Color get splashShapeTop => _isDark ? HesakColorsDark.splashShapeTop : HesakColorsLight.splashShapeTop;
  static Color get splashShapeBottom => _isDark ? HesakColorsDark.splashShapeBottom : HesakColorsLight.splashShapeBottom;
  static Color get modeSelected => _isDark ? HesakColorsDark.modeSelected : HesakColorsLight.modeSelected;
  static Color get modeSelectedRing => _isDark ? HesakColorsDark.modeSelectedRing : HesakColorsLight.modeSelectedRing;
  static Color get modeUnselectedFill => _isDark ? HesakColorsDark.modeUnselectedFill : HesakColorsLight.modeUnselectedFill;
  static Color get toastBackground => _isDark ? HesakColorsDark.toastBackground : HesakColorsLight.toastBackground;
  static Color get danger => _isDark ? HesakColorsDark.danger : HesakColorsLight.danger;
  static Color get modeTileSelectedFill => _isDark ? HesakColorsDark.modeTileSelectedFill : HesakColorsLight.modeTileSelectedFill;
  static Color get modeHeaderOverlay => _isDark ? HesakColorsDark.modeHeaderOverlay : HesakColorsLight.modeHeaderOverlay;
  static Color get onModeHeaderSoft => _isDark ? HesakColorsDark.onModeHeaderSoft : HesakColorsLight.onModeHeaderSoft;
  static Color get activeDot => _isDark ? HesakColorsDark.activeDot : HesakColorsLight.activeDot;
  static Color get modeHeaderIdleStart => _isDark ? HesakColorsDark.modeHeaderIdleStart : HesakColorsLight.modeHeaderIdleStart;
  static Color get modeHeaderIdleEnd => _isDark ? HesakColorsDark.modeHeaderIdleEnd : HesakColorsLight.modeHeaderIdleEnd;
  static Color get idleDot => _isDark ? HesakColorsDark.idleDot : HesakColorsLight.idleDot;
  static Color get homePageBackground => _isDark ? HesakColorsDark.homePageBackground : HesakColorsLight.homePageBackground;
  static Color get homeHeaderTint => _isDark ? HesakColorsDark.homeHeaderTint : HesakColorsLight.homeHeaderTint;
  static List<Color> get homeListenBandGradient => _isDark ? HesakColorsDark.homeListenBandGradient : HesakColorsLight.homeListenBandGradient;
  static List<double> get homeListenBandStops => _isDark ? HesakColorsDark.homeListenBandStops : HesakColorsLight.homeListenBandStops;
  static Color get homeHeaderLinesOnPurple => _isDark ? HesakColorsDark.homeHeaderLinesOnPurple : HesakColorsLight.homeHeaderLinesOnPurple;
  static Color get homeHaloFill => _isDark ? HesakColorsDark.homeHaloFill : HesakColorsLight.homeHaloFill;
  static Color get homeHaloBorder => _isDark ? HesakColorsDark.homeHaloBorder : HesakColorsLight.homeHaloBorder;
  static Color get homeListenTrack => _isDark ? HesakColorsDark.homeListenTrack : HesakColorsLight.homeListenTrack;
  static Color get homeListenLight => _isDark ? HesakColorsDark.homeListenLight : HesakColorsLight.homeListenLight;
  static List<Color> get homeListenButtonIdle => _isDark ? HesakColorsDark.homeListenButtonIdle : HesakColorsLight.homeListenButtonIdle;
  static List<Color> get homeListenButtonActive => _isDark ? HesakColorsDark.homeListenButtonActive : HesakColorsLight.homeListenButtonActive;
  static Color get homeListenShadow => _isDark ? HesakColorsDark.homeListenShadow : HesakColorsLight.homeListenShadow;
  static List<Color> get homeCardGradient => _isDark ? HesakColorsDark.homeCardGradient : HesakColorsLight.homeCardGradient;
  static Color get homeCardBorder => _isDark ? HesakColorsDark.homeCardBorder : HesakColorsLight.homeCardBorder;
  static Color get homeCardShadow => _isDark ? HesakColorsDark.homeCardShadow : HesakColorsLight.homeCardShadow;
  static Color get homeItemFill => _isDark ? HesakColorsDark.homeItemFill : HesakColorsLight.homeItemFill;
  static Color get homeChipBorder => _isDark ? HesakColorsDark.homeChipBorder : HesakColorsLight.homeChipBorder;
  static Color get homeCardDivider => _isDark ? HesakColorsDark.homeCardDivider : HesakColorsLight.homeCardDivider;
  static Color get homeCardIconBox => _isDark ? HesakColorsDark.homeCardIconBox : HesakColorsLight.homeCardIconBox;
  static Color get homeUrgentIconFill => _isDark ? HesakColorsDark.homeUrgentIconFill : HesakColorsLight.homeUrgentIconFill;
  static Color get homeAlertFill => _isDark ? HesakColorsDark.homeAlertFill : HesakColorsLight.homeAlertFill;
  static Color get homeAlertShadow => _isDark ? HesakColorsDark.homeAlertShadow : HesakColorsLight.homeAlertShadow;
  static Color get homeAlertIconFill => _isDark ? HesakColorsDark.homeAlertIconFill : HesakColorsLight.homeAlertIconFill;
  static Color get homeAlertLine => _isDark ? HesakColorsDark.homeAlertLine : HesakColorsLight.homeAlertLine;
  static List<Color> get homeModeCardIdle => _isDark ? HesakColorsDark.homeModeCardIdle : HesakColorsLight.homeModeCardIdle;
  static List<Color> get homeModeCardActive => _isDark ? HesakColorsDark.homeModeCardActive : HesakColorsLight.homeModeCardActive;
  static Color get homeModeCardBorder => _isDark ? HesakColorsDark.homeModeCardBorder : HesakColorsLight.homeModeCardBorder;
  static Color get homeGlassFill => _isDark ? HesakColorsDark.homeGlassFill : HesakColorsLight.homeGlassFill;
  static Color get homeGlassBorder => _isDark ? HesakColorsDark.homeGlassBorder : HesakColorsLight.homeGlassBorder;
  static Color get homeGlassIcon => _isDark ? HesakColorsDark.homeGlassIcon : HesakColorsLight.homeGlassIcon;
  static Color get onHomeGlass => _isDark ? HesakColorsDark.onHomeGlass : HesakColorsLight.onHomeGlass;
  static Color get onHomeGlassSoft => _isDark ? HesakColorsDark.onHomeGlassSoft : HesakColorsLight.onHomeGlassSoft;
  static Color get favoriteStar => _isDark ? HesakColorsDark.favoriteStar : HesakColorsLight.favoriteStar;
  static Color get tabPageBackground => _isDark ? HesakColorsDark.tabPageBackground : HesakColorsLight.tabPageBackground;
  static List<Color> get chatsCardGradient => _isDark ? HesakColorsDark.chatsCardGradient : HesakColorsLight.chatsCardGradient;
  static Color get chatsCardBorder => _isDark ? HesakColorsDark.chatsCardBorder : HesakColorsLight.chatsCardBorder;
  static Color get chatsConversationBackground => _isDark ? HesakColorsDark.chatsConversationBackground : HesakColorsLight.chatsConversationBackground;
  static List<Color> get modesCardGradient => _isDark ? HesakColorsDark.modesCardGradient : HesakColorsLight.modesCardGradient;
  static Color get modesCardBorder => _isDark ? HesakColorsDark.modesCardBorder : HesakColorsLight.modesCardBorder;
  static Color get modesIconCircle => _isDark ? HesakColorsDark.modesIconCircle : HesakColorsLight.modesIconCircle;
  static Color get modesDetailsFill => _isDark ? HesakColorsDark.modesDetailsFill : HesakColorsLight.modesDetailsFill;
  static Color get modesInfoTileFill => _isDark ? HesakColorsDark.modesInfoTileFill : HesakColorsLight.modesInfoTileFill;
  static Color get modesScheduleHeaderFill => _isDark ? HesakColorsDark.modesScheduleHeaderFill : HesakColorsLight.modesScheduleHeaderFill;
  static Color get modesScheduleBorder => _isDark ? HesakColorsDark.modesScheduleBorder : HesakColorsLight.modesScheduleBorder;
  static Color get modesScheduleBodyFill => _isDark ? HesakColorsDark.modesScheduleBodyFill : HesakColorsLight.modesScheduleBodyFill;
  static Color get modesHintStripFill => _isDark ? HesakColorsDark.modesHintStripFill : HesakColorsLight.modesHintStripFill;
  static Color get modesHintStripLine => _isDark ? HesakColorsDark.modesHintStripLine : HesakColorsLight.modesHintStripLine;
  static Color get modesHintStripText => _isDark ? HesakColorsDark.modesHintStripText : HesakColorsLight.modesHintStripText;
  static Color get schedulePeriodFill => _isDark ? HesakColorsDark.schedulePeriodFill : HesakColorsLight.schedulePeriodFill;
  static Color get schedulePeriodBorder => _isDark ? HesakColorsDark.schedulePeriodBorder : HesakColorsLight.schedulePeriodBorder;
  static Color get schedulePeriodOnLavenderFill => _isDark ? HesakColorsDark.schedulePeriodOnLavenderFill : HesakColorsLight.schedulePeriodOnLavenderFill;
  static Color get scheduleAddBorder => _isDark ? HesakColorsDark.scheduleAddBorder : HesakColorsLight.scheduleAddBorder;
  static Color get cardTitleLine => _isDark ? HesakColorsDark.cardTitleLine : HesakColorsLight.cardTitleLine;
  static Color get settingsRowLine => _isDark ? HesakColorsDark.settingsRowLine : HesakColorsLight.settingsRowLine;
  static Color get settingsIconBox => _isDark ? HesakColorsDark.settingsIconBox : HesakColorsLight.settingsIconBox;
  static Color get homeTileFillIdle => _isDark ? HesakColorsDark.homeTileFillIdle : HesakColorsLight.homeTileFillIdle;
  static Color get homeTileFillActive => _isDark ? HesakColorsDark.homeTileFillActive : HesakColorsLight.homeTileFillActive;
  static Color get homeTileBorder => _isDark ? HesakColorsDark.homeTileBorder : HesakColorsLight.homeTileBorder;
  static Color get homeGlassLine => _isDark ? HesakColorsDark.homeGlassLine : HesakColorsLight.homeGlassLine;
}
