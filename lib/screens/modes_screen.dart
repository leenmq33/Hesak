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
//   - The SELECTED mode, always on top and NOT draggable: the same row as the
//     others but purple, with "مفعّل" / "غير مفعّل" (+ a hint line while listening is off).
//     Its schedule + settings summary are on الرئيسية (screens/home/home_mode_section.dart).
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
      backgroundColor: HesakColors.tabPageBackground, // Same lavender as the other tabs
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
          _ModesSelectedRow(mode: selected, isListening: store.isListening),

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
// Selected mode row (on top)
// ---------------------------------------------------------------------

/// The SELECTED mode: same row as the others (circle, name, schedule, star, pencil),
/// but filled with purple and not draggable.
///  - listening ON  -> deep purple + "مفعّل"
///  - listening OFF -> lighter purple + "غير مفعّل" + a hint line under it
/// Its schedule and settings summary live on الرئيسية now (HomeModeSection).
class _ModesSelectedRow extends StatelessWidget {
  final HesakModeConfig mode;
  final bool isListening;

  const _ModesSelectedRow({required this.mode, required this.isListening});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(HesakSizes.radiusCard);
    return ClipRRect(
      key: const Key('modes_selected_row'),
      borderRadius: radius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 10, 10),
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
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: HesakColors.modeHeaderOverlay),
                  child: Center(
                    child: mode.icon != null
                        ? Icon(mode.icon, size: 26, color: HesakColors.onPrimary)
                        : Text(mode.firstLetter, style: HesakTextStyles.modeCircleLetter.copyWith(color: HesakColors.onPrimary)),
                  ),
                ),
                const SizedBox(width: 12),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ModesStateBadge(isListening: isListening),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(mode.scheduleSummary, style: HesakTextStyles.modeHeaderSubtitle.copyWith(height: 1.5)),
                    ],
                  ),
                ),
                ModesStarButton(
                  key: const Key('modes_selected_star_button'),
                  isFavorite: mode.isFavorite,
                  isOnDark: true,
                  onTap: () => modesToggleFavorite(context, mode),
                ),
                const SizedBox(width: 8),
                // Pencil: edit page.
                Tooltip(
                  message: 'تعديل',
                  child: Material(
                    color: HesakColors.modeHeaderOverlay,
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: const Key('modes_selected_edit_button'),
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ModeEditorScreen(modeId: mode.id)),
                      ),
                      child: const SizedBox(
                        width: HesakSizes.modeStarButton,
                        height: HesakSizes.modeStarButton,
                        child: Icon(Icons.edit_rounded, size: 18, color: HesakColors.onPrimary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Listening is off: tell the user how to really turn the mode on.
          if (!isListening)
            Container(
              key: const Key('modes_listen_hint'),
              color: HesakColors.modeTileSelectedFill,
              padding: const EdgeInsets.symmetric(horizontal: HesakSizes.cardPaddingHorizontal, vertical: 9),
              child: const Text('اضغط زر الاستماع في الرئيسية لتفعيل الوضع', style: HesakTextStyles.modeHint),
            ),
        ],
      ),
    );
  }
}