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
