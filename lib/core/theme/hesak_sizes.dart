/// ALL shared sizes (spacing, corner radius, icon sizes) live here,
/// so every page has the same margins and roundness.
///
/// Rules for the team:
/// - Use `HesakSizes.xxx` instead of typing numbers for padding / radius.
/// - Numbers that belong to ONE special widget only (like the listen
///   button's 170) can stay inside that widget.
class HesakSizes {
  HesakSizes._(); // Use HesakSizes.xxx directly

  // ---- Page spacing ----

  /// Left/right space between the screen edge and the content.
  static const double pagePadding = 24;

  /// Space at the bottom of a scrolling page so content isn't hidden under the nav bar.
  static const double pageBottomSafeSpace = 130;

  /// Standard gap between two cards / sections.
  static const double sectionGap = 12;

  // ---- Corner radius ----

  /// Cards.
  static const double radiusCard = 22;

  /// Chips (pill shape).
  static const double radiusChip = 22;

  /// Small icon boxes inside cards.
  static const double radiusIconBox = 12;

  /// Bottom navigation bar corners.
  static const double radiusNavBar = 28;

  // ---- Cards ----

  /// Inside padding of a card (left/right).
  static const double cardPaddingHorizontal = 14;

  /// Inside padding of a card (top).
  static const double cardPaddingTop = 12;

  /// Inside padding of a card (bottom).
  static const double cardPaddingBottom = 14;

  // ---- Icons ----

  /// Square box that holds an icon inside a card row.
  static const double iconBox = 42;

  /// Icon inside that box.
  static const double iconInBox = 23;

  /// Icon inside a chip.
  static const double iconInChip = 17;

  /// Nav bar tab icon.
  static const double iconNavTab = 26;

  // ---- Header ----

  /// Height of the logo + waves area at the top of every page.
  static const double headerHeight = 100;
}
