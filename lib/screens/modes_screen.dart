import 'package:flutter/material.dart';
import '../core/data/hesak_mode_store.dart';
import '../core/theme/hesak_colors.dart';
import '../core/theme/hesak_sizes.dart';
import '../core/theme/hesak_text_styles.dart';
import '../widgets/hesak_page_header.dart';
import 'modes/mode_editor_screen.dart';
import 'modes/modes_all_screen.dart';
import 'modes/modes_widgets.dart';

// =====================================================================
//  MODES PAGE (الأوضاع) — the tab in the bottom bar.
//
//  The tab has its OWN navigator, so the inner pages (عرض الكل, إضافة وضع,
//  تعديل وضع) open INSIDE the tab and the bottom bar stays visible.
//
//  Main page, top to bottom:
//   - "عرض الكل ‹" (left) + a row of mode tiles. Tap a tile = make it active.
//     The selected tile has a purple frame. Last tile "إضافة" opens the add page.
//   - ONE card with everything about the active mode:
//       purple header: icon, name, "مفعّل الآن", schedule line, star
//       body: جدولة الوضع (saved right away) + ملخص الإعدادات
//       + "تعديل إعدادات الوضع ‹" (opens the edit page)
//
//  Data: HesakModeStore (lib/core/data/hesak_mode_store.dart).
//  Shared pieces: modes/modes_widgets.dart.
//
//  NAMING: everything here starts with "Modes". Keys: 'modes_<name>'.
//  This page does NOT build the bottom bar — HesakMainShell does that.
// =====================================================================

/// The الأوضاع tab (with its own navigator for the inner pages).
class ModesScreen extends StatelessWidget {
  /// true while the الأوضاع tab is the one on screen. The phone back button
  /// only goes back inside this tab while it's shown.
  final bool isActive;

  const ModesScreen({super.key, this.isActive = true});

  /// The navigator of this tab (inner pages open here, under the bottom bar).
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'modes_navigator');

  /// Opens "إضافة وضع" inside this tab (used by "إضافة +" on the bar wheel).
  static void openAddModePage() {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const ModeEditorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Phone back button: go back inside the tab first (e.g. from عرض الكل to الأوضاع).
    return NavigatorPopHandler(
      enabled: isActive,
      onPop: () => navigatorKey.currentState?.maybePop(),
      child: Navigator(
        key: navigatorKey,
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => const _ModesHomePage(),
        ),
      ),
    );
  }
}

/// The first page of the tab: header + tiles + active mode card.
class _ModesHomePage extends StatelessWidget {
  const _ModesHomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HesakColors.background,
      body: SafeArea(
        bottom: false, // The bottom bar handles the bottom edge
        child: Column(
          children: [
            // Shared header: logo + waves + page title + divider.
            const HesakPageHeader(title: 'الأوضاع'),

            // Rebuilds whenever a mode changes (selected, starred, edited ...).
            Expanded(
              child: ListenableBuilder(
                listenable: HesakModeStore.instance,
                // Not const on purpose: a const widget would never rebuild.
                builder: (context, _) => _ModesPageContent(store: HesakModeStore.instance),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything under the header.
class _ModesPageContent extends StatelessWidget {
  final HesakModeStore store;

  const _ModesPageContent({required this.store});

  @override
  Widget build(BuildContext context) {
    final HesakModeConfig selected = store.selectedMode;

    return SingleChildScrollView(
      // Bottom space keeps the content above the bottom bar.
      padding: const EdgeInsets.fromLTRB(
        HesakSizes.pagePadding,
        0,
        HesakSizes.pagePadding,
        HesakSizes.pageBottomSafeSpace,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- "عرض الكل ‹" (left side) ----
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const Key('modes_show_all_button'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ModesAllScreen()),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('عرض الكل', style: HesakTextStyles.modeLink),
                  SizedBox(width: 2),
                  // "Forward" arrow: points left in Arabic.
                  Icon(Icons.arrow_forward_ios_rounded, size: 13, color: HesakColors.modeSelected),
                ],
              ),
            ),
          ),

          // ---- Mode tiles (the order the user set in عرض الكل) ----
          _ModesTilesRow(
            modes: store.modes,
            selectedModeId: selected.id,
            onSelect: store.selectMode,
          ),
          const SizedBox(height: 14),

          // ---- Everything about the active mode, in one card ----
          _ModesActiveModeCard(mode: selected),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Tiles row
// ---------------------------------------------------------------------

/// Row of mode tiles (scrolls sideways when there are many) + "إضافة".
class _ModesTilesRow extends StatelessWidget {
  final List<HesakModeConfig> modes;
  final String selectedModeId;
  final ValueChanged<String> onSelect;

  static const double _tileWidth = 80;

  const _ModesTilesRow({required this.modes, required this.selectedModeId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final mode in modes)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _ModesTile(
                key: Key('modes_tile_${mode.id}'),
                width: _tileWidth,
                isSelected: mode.id == selectedModeId,
                onTap: () => onSelect(mode.id),
                icon: mode.icon,
                letter: mode.firstLetter,
                label: mode.name,
              ),
            ),

          // "إضافة" -> add page (dashed-look purple outline).
          _ModesTile(
            key: const Key('modes_tile_add'),
            width: _tileWidth,
            isSelected: false,
            isAddTile: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ModeEditorScreen()),
            ),
            icon: Icons.add_rounded,
            letter: '+',
            label: 'إضافة',
          ),
        ],
      ),
    );
  }
}

/// One tile: icon (or first letter) + name. Selected = purple frame + light fill.
class _ModesTile extends StatelessWidget {
  final double width;
  final bool isSelected;
  final bool isAddTile;
  final VoidCallback onTap;
  final IconData? icon;
  final String letter;
  final String label;

  const _ModesTile({
    super.key,
    required this.width,
    required this.isSelected,
    required this.onTap,
    required this.icon,
    required this.letter,
    required this.label,
    this.isAddTile = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color contentColor = isSelected || isAddTile ? HesakColors.modeSelected : HesakColors.iconInactive;
    final radius = BorderRadius.circular(18);

    return SizedBox(
      width: width,
      child: Material(
        color: isSelected ? HesakColors.modeTileSelectedFill : HesakColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: isSelected
                ? HesakColors.modeSelected
                : (isAddTile ? HesakColors.primaryLightBorder : HesakColors.surfaceBorder),
            width: isSelected ? 2 : 1.3,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 28,
                  child: Center(
                    child: icon != null
                        ? Icon(icon, size: 26, color: contentColor)
                        : Text(letter, style: HesakTextStyles.modeCircleLetter.copyWith(color: contentColor, fontSize: 20)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: isSelected || isAddTile ? HesakTextStyles.modeTileLabelSelected : HesakTextStyles.modeTileLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Active mode card
// ---------------------------------------------------------------------

/// Purple header (icon, name, "مفعّل الآن", schedule, star) + schedule +
/// settings summary + "تعديل إعدادات الوضع".
class _ModesActiveModeCard extends StatelessWidget {
  final HesakModeConfig mode;

  const _ModesActiveModeCard({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('modes_active_mode_card'),
      clipBehavior: Clip.antiAlias, // Keeps the purple header inside the rounded corners
      decoration: BoxDecoration(
        color: HesakColors.surface,
        borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
        border: Border.all(color: HesakColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Padding(
            padding: const EdgeInsets.all(HesakSizes.cardPaddingHorizontal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---- جدولة الوضع (saved right away) ----
                const Text('جدولة الوضع', style: HesakTextStyles.modeSectionTitle),
                const SizedBox(height: 8),
                ModesScheduleEditor(
                  // New key per mode, so an open edit box doesn't carry over to another mode.
                  key: ValueKey('modes_schedule_${mode.id}'),
                  periods: mode.periods,
                  // Saved right away. The schedule widget shows its own message.
                  onChanged: (periods) => HesakModeStore.instance.updateMode(mode.copyWith(periods: periods)),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: HesakColors.listDivider),
                ),

                // ---- ملخص الإعدادات ----
                const Text('ملخص الإعدادات', style: HesakTextStyles.modeSectionTitle),
                const SizedBox(height: 8),
                _summaryRow(
                  'نوع التنبيه',
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final type in HesakAlertType.values)
                        if (mode.alertTypes.contains(type))
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 6),
                            child: Tooltip(
                              message: type.label,
                              child: Icon(type.icon, size: 19, color: HesakColors.modeSelected),
                            ),
                          ),
                    ],
                  ),
                ),
                _summaryRow(
                  'الأصوات المفعّلة',
                  Text(_soundsCountText(mode.soundIds.length), style: HesakTextStyles.modeSummaryValue),
                ),
                _summaryRow(
                  'التنبيه عند نداء اسمك',
                  Text(mode.isCallNameAlertOn ? 'مفعّل' : 'متوقف', style: HesakTextStyles.modeSummaryValue),
                ),

                // ---- Open the edit page ----
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('modes_edit_settings_button'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ModeEditorScreen(modeId: mode.id)),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    side: const BorderSide(color: HesakColors.modeSelected, width: 1.4),
                    shape: const StadiumBorder(),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Sliders icon (not a gear — the gear is "الإعدادات" in the bottom bar).
                      Icon(Icons.tune_rounded, size: 18, color: HesakColors.modeSelected),
                      SizedBox(width: 6),
                      Text('تعديل إعدادات الوضع', style: HesakTextStyles.modeLink),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 12, color: HesakColors.modeSelected),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Purple header: icon circle, name + "مفعّل الآن", schedule line, star.
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [HesakColors.primaryMuted, HesakColors.primary],
        ),
      ),
      child: Row(
        children: [
          // Icon (or first letter) in a see-through white circle.
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: HesakColors.modeHeaderOverlay),
            child: Center(
              child: mode.icon != null
                  ? Icon(mode.icon, size: 30, color: HesakColors.onPrimary)
                  : Text(
                      mode.firstLetter,
                      style: HesakTextStyles.modeCircleLetter.copyWith(color: HesakColors.onPrimary),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + "مفعّل الآن" + schedule line.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        mode.name,
                        key: const Key('modes_selected_name'),
                        style: HesakTextStyles.modeHeaderName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _ModesActiveBadge(),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.schedule_rounded, size: 14, color: HesakColors.onModeHeaderSoft),
                    ),
                    const SizedBox(width: 4),
                    Expanded(child: Text(mode.scheduleLine, style: HesakTextStyles.modeHeaderSubtitle)),
                  ],
                ),
              ],
            ),
          ),

          // Star (add to / remove from الأوضاع المفضلة).
          ModesStarButton(
            key: const Key('modes_selected_star_button'),
            isFavorite: mode.isFavorite,
            isOnDark: true,
            onTap: () => modesToggleFavorite(context, mode),
          ),
        ],
      ),
    );
  }

  /// One summary line: label on the right, value on the left.
  Widget _summaryRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: HesakTextStyles.modeSettingLabel)),
          value,
        ],
      ),
    );
  }

  /// "صوت واحد" / "صوتان" / "4 أصوات" / "12 صوتًا" (Arabic counting).
  static String _soundsCountText(int count) {
    if (count == 0) return 'لا يوجد';
    if (count == 1) return 'صوت واحد';
    if (count == 2) return 'صوتان';
    if (count <= 10) return '$count أصوات';
    return '$count صوتًا';
  }
}

/// Small light pill with a green dot: "مفعّل الآن".
class _ModesActiveBadge extends StatelessWidget {
  const _ModesActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: HesakColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 7,
            height: 7,
            child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: HesakColors.activeDot)),
          ),
          SizedBox(width: 4),
          Text('مفعّل الآن', style: HesakTextStyles.modeBadge),
        ],
      ),
    );
  }
}
