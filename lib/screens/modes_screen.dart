import 'package:flutter/material.dart';
import '../core/data/hesak_mode_store.dart';
import '../core/theme/hesak_colors.dart';
import '../core/theme/hesak_sizes.dart';
import '../core/theme/hesak_text_styles.dart';
import '../widgets/hesak_page_header.dart';
import 'modes/mode_editor_screen.dart';
import 'modes/modes_widgets.dart';

// =====================================================================
//  MODES PAGE (الأوضاع) — the tab in the bottom bar.
//
//  The tab has its OWN navigator, so the inner pages (إضافة وضع, تعديل وضع)
//  open INSIDE the tab and the bottom bar stays visible.
//
//  ONE page, top to bottom:
//   - The SELECTED mode, always on top, open, and NOT draggable:
//       purple header: icon, name, "مفعّل" / "غير مفعّل", schedule line, star
//       (+ a hint line under it while listening is off)
//       body: جدولة الوضع (saved right away) + ملخص الإعدادات
//       + "تعديل إعدادات الوضع ‹" (opens the edit page)
//   - A small grey hint: "اضغط للتفعيل" · "اسحب للترتيب"
//   - The other modes as closed rows: drag handle, icon, name, schedule, star, pencil.
//       tap a row = it becomes the selected mode (moves to the top)
//       pencil    = edit it WITHOUT selecting it
//       drag      = change the order (the wheel on the bar follows this order)
//   - "إضافة وضع جديد"
//
//  "مفعّل" = the selected mode is really working, which only happens while
//  the listen button on الرئيسية is ON (HesakModeStore.isListening).
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
    // Phone back button: go back inside the tab first (e.g. from تعديل وضع to الأوضاع).
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

/// The first page of the tab: header + selected mode card + the other modes.
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

            // Rebuilds whenever a mode changes (selected, starred, edited, listening ...).
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
class _ModesPageContent extends StatefulWidget {
  final HesakModeStore store;

  const _ModesPageContent({required this.store});

  @override
  State<_ModesPageContent> createState() => _ModesPageContentState();
}

class _ModesPageContentState extends State<_ModesPageContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Tap on a row: that mode becomes the selected one and the page goes up to show it.
  void _selectMode(String id) {
    widget.store.selectMode(id);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  /// Drag between the NOT selected modes. The selected mode keeps its place in the order.
  void _reorderOthers(List<HesakModeConfig> others, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1; // ReorderableListView counts the moved row
    final List<String> otherIds = others.map((m) => m.id).toList();
    final String movedId = otherIds.removeAt(oldIndex);
    otherIds.insert(newIndex.clamp(0, otherIds.length), movedId);

    final List<HesakModeConfig> all = widget.store.modes;
    final String selectedId = widget.store.selectedModeId;
    final int selectedIndex = all.indexWhere((m) => m.id == selectedId);
    final List<String> orderedIds = [...otherIds];
    if (selectedIndex != -1) orderedIds.insert(selectedIndex.clamp(0, orderedIds.length), selectedId);
    widget.store.setModesOrder(orderedIds);
  }

  @override
  Widget build(BuildContext context) {
    final HesakModeStore store = widget.store;
    final HesakModeConfig selected = store.selectedMode;
    final List<HesakModeConfig> others = store.modes.where((m) => m.id != selected.id).toList();

    return SingleChildScrollView(
      controller: _scrollController,
      // Bottom space keeps the content above the bottom bar.
      padding: const EdgeInsets.fromLTRB(
        HesakSizes.pagePadding,
        4,
        HesakSizes.pagePadding,
        HesakSizes.pageBottomSafeSpace,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- The selected mode: always on top, not draggable ----
          _ModesActiveModeCard(mode: selected, isListening: store.isListening),

          // ---- Hint + the other modes ----
          if (others.isNotEmpty) ...[
            const SizedBox(height: 22),
            const _ModesListHint(),
            const SizedBox(height: 10),
            ReorderableListView(
              // Lives inside the page's scroll: not scrollable by itself.
              shrinkWrap: true,
              padding: EdgeInsets.zero, // No hidden bottom gap (the bar height) before "إضافة وضع جديد"
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false, // Our own handle (⋮⋮) + long-press on the row
              onReorder: (oldIndex, newIndex) => _reorderOthers(others, oldIndex, newIndex),
              // The row being dragged: a little lifted with a soft shadow.
              proxyDecorator: (child, index, animation) => Material(
                color: Colors.transparent,
                elevation: 6,
                shadowColor: HesakColors.glassShadow,
                borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
                child: child,
              ),
              children: [
                for (int i = 0; i < others.length; i++)
                  ReorderableDelayedDragStartListener(
                    key: ValueKey('modes_row_${others[i].id}'),
                    index: i,
                    child: _ModesModeRow(
                      mode: others[i],
                      index: i,
                      onTap: () => _selectMode(others[i].id),
                    ),
                  ),
              ],
            ),
          ] else
            const SizedBox(height: 14),

          // ---- إضافة وضع جديد ----
          const _ModesAddCard(),
        ],
      ),
    );
  }
}

/// Small grey line: "👆 اضغط للتفعيل   ⋮⋮ اسحب للترتيب".
class _ModesListHint extends StatelessWidget {
  const _ModesListHint();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.touch_app_outlined, size: 16, color: HesakColors.iconInactive),
        SizedBox(width: 4),
        Text('اضغط للتفعيل', style: HesakTextStyles.modeHint),
        SizedBox(width: 18),
        Icon(Icons.drag_indicator_rounded, size: 16, color: HesakColors.iconInactive),
        SizedBox(width: 2),
        Text('اسحب للترتيب', style: HesakTextStyles.modeHint),
      ],
    );
  }
}

/// One NOT selected mode: ⋮⋮, circle, name + schedule, star, pencil.
/// Tap = select it. Pencil = edit it (stays not selected).
class _ModesModeRow extends StatelessWidget {
  final HesakModeConfig mode;
  final int index; // Its place in the list (for the drag handle)
  final VoidCallback onTap;

  const _ModesModeRow({required this.mode, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(HesakSizes.radiusCard);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: HesakColors.surface,
        shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: HesakColors.surfaceBorder)),
        child: InkWell(
          key: Key('modes_row_tap_${mode.id}'),
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 8, 10),
            child: Row(
              children: [
                // Drag handle: drag right away (the row itself needs a long press).
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                    child: Icon(Icons.drag_indicator_rounded, color: HesakColors.iconInactive, size: 22),
                  ),
                ),
                ModesModeCircle.forMode(mode, isSelected: false, size: 50),
                const SizedBox(width: 12),

                // Name + schedule.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mode.name, style: HesakTextStyles.modeRowName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(mode.scheduleSummary, style: HesakTextStyles.modeHint.copyWith(height: 1.5)),
                    ],
                  ),
                ),

                ModesStarButton(
                  key: Key('modes_row_star_${mode.id}'),
                  isFavorite: mode.isFavorite,
                  onTap: () => modesToggleFavorite(context, mode),
                ),
                const SizedBox(width: 8),

                // Pencil: edit without selecting.
                Tooltip(
                  message: 'تعديل',
                  child: Material(
                    color: HesakColors.surface,
                    shape: const CircleBorder(side: BorderSide(color: HesakColors.primaryLightBorder, width: 1.3)),
                    child: InkWell(
                      key: Key('modes_row_edit_${mode.id}'),
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ModeEditorScreen(modeId: mode.id)),
                      ),
                      child: const SizedBox(
                        width: HesakSizes.modeStarButton,
                        height: HesakSizes.modeStarButton,
                        child: Icon(Icons.edit_rounded, size: 18, color: HesakColors.modeSelected),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Last card: "إضافة وضع جديد".
class _ModesAddCard extends StatelessWidget {
  const _ModesAddCard();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(HesakSizes.radiusCard);
    return Material(
      color: HesakColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: HesakColors.primaryLightBorder, width: 1.3),
      ),
      child: InkWell(
        key: const Key('modes_add_card'),
        borderRadius: radius,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ModeEditorScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: HesakColors.primaryLightBorder, width: 1.5),
                ),
                child: const Icon(Icons.add_rounded, color: HesakColors.iconInactive, size: 26),
              ),
              const SizedBox(width: 12),
              const Text('إضافة وضع جديد', style: HesakTextStyles.modeLink),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Active mode card
// ---------------------------------------------------------------------

/// Purple header (icon, name, "مفعّل" / "غير مفعّل", schedule, star) + schedule +
/// settings summary + "تعديل إعدادات الوضع".
/// [isListening] false = lighter header, grey "غير مفعّل" and a hint line under the header.
class _ModesActiveModeCard extends StatelessWidget {
  final HesakModeConfig mode;
  final bool isListening;

  const _ModesActiveModeCard({required this.mode, required this.isListening});

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
          // Listening is off: tell the user how to really turn the mode on.
          if (!isListening)
            Container(
              key: const Key('modes_listen_hint'),
              color: HesakColors.modeTileSelectedFill,
              padding: const EdgeInsets.symmetric(horizontal: HesakSizes.cardPaddingHorizontal, vertical: 9),
              child: const Text('اضغط زر الاستماع في الرئيسية لتفعيل الوضع', style: HesakTextStyles.modeHint),
            ),
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
                  modeId: mode.id,
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

  /// Purple header: icon circle, name + "مفعّل" / "غير مفعّل", schedule line, star.
  /// Deep purple while listening, a lighter purple while not.
  Widget _buildHeader(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: isListening
              ? const [HesakColors.primaryMuted, HesakColors.primary]
              : const [HesakColors.modeHeaderIdleStart, HesakColors.modeHeaderIdleEnd],
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

          // Name + "مفعّل" / "غير مفعّل" + schedule line.
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
                    _ModesActiveBadge(isListening: isListening),
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

/// Small light pill: green dot + "مفعّل" while listening, grey dot + "غير مفعّل" otherwise.
class _ModesActiveBadge extends StatelessWidget {
  final bool isListening;

  const _ModesActiveBadge({required this.isListening});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('modes_state_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: HesakColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 7,
            height: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isListening ? HesakColors.activeDot : HesakColors.idleDot,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isListening ? 'مفعّل' : 'غير مفعّل',
            style: isListening ? HesakTextStyles.modeBadge : HesakTextStyles.modeBadge.copyWith(color: HesakColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
