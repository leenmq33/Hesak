import 'package:flutter/material.dart';
import '../../core/data/hesak_mode_store.dart';
import '../../core/theme/hesak_colors.dart';
import '../../core/theme/hesak_sizes.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../widgets/hesak_page_header.dart';
import 'mode_editor_screen.dart';
import 'modes_widgets.dart';

// =====================================================================
//  ALL MODES (عرض الكل) — opened from "عرض الكل" on the الأوضاع page.
//
//  One list of all modes. Long-press + drag a card to change the order
//  (the bar wheel shows the starred modes in this same order).
//  One card per mode: circle, name (+ "مفعّل" on the active one),
//  its schedule, star, delete. Tapping a card opens the edit page.
//  The last card "إضافة وضع جديد" opens the add page.
//  The general mode (العام) has no delete button.
//
//  NAMING: everything here starts with "ModesAll". Keys: 'modes_all_<name>'.
// =====================================================================

class ModesAllScreen extends StatelessWidget {
  const ModesAllScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HesakColors.background,
      body: SafeArea(
        bottom: false, // The bottom bar (from HesakMainShell) covers the bottom edge
        child: Column(
          children: [
            HesakPageHeader(title: 'الأوضاع', onBack: () => Navigator.pop(context)),
            Expanded(
              child: ListenableBuilder(
                listenable: HesakModeStore.instance,
                builder: (context, _) {
                  final store = HesakModeStore.instance;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                        HesakSizes.pagePadding, 4, HesakSizes.pagePadding, HesakSizes.pageBottomSafeSpace),
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text('عرض الكل', textAlign: TextAlign.center, style: HesakTextStyles.cardTitle),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'اضغط مطوّلًا على الوضع واسحبه لتغيير ترتيبه',
                          textAlign: TextAlign.center,
                          style: HesakTextStyles.caption,
                        ),
                      ),

                      // ---- All modes, drag to reorder ----
                      _ModesAllList(modes: store.modes, selectedModeId: store.selectedModeId),

                      const SizedBox(height: 4),
                      const _ModesAllAddCard(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// All the mode cards. Long-press a card and drag to change the order.
class _ModesAllList extends StatelessWidget {
  final List<HesakModeConfig> modes;
  final String selectedModeId;

  const _ModesAllList({required this.modes, required this.selectedModeId});

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      // Lives inside the page's list: not scrollable by itself.
      shrinkWrap: true,
      padding: EdgeInsets.zero, // No hidden bottom gap before "إضافة وضع جديد"
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false, // We use long-press on the whole card instead
      onReorder: (oldIndex, newIndex) => HesakModeStore.instance.reorderModes(
        oldIndex: oldIndex,
        newIndex: newIndex,
      ),
      // The card being dragged: a little lifted with a soft shadow.
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        elevation: 6,
        shadowColor: HesakColors.glassShadow,
        borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
        child: child,
      ),
      children: [
        for (int i = 0; i < modes.length; i++)
          ReorderableDelayedDragStartListener(
            key: ValueKey('modes_all_card_${modes[i].id}'),
            index: i,
            child: _ModesAllCard(mode: modes[i], isActive: modes[i].id == selectedModeId),
          ),
      ],
    );
  }
}

/// One mode: circle, name, schedule, star, delete. Tap = edit.
class _ModesAllCard extends StatelessWidget {
  final HesakModeConfig mode;
  final bool isActive;

  const _ModesAllCard({super.key, required this.mode, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: HesakColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
          side: const BorderSide(color: HesakColors.surfaceBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ModeEditorScreen(modeId: mode.id)),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 6, 12),
            child: Row(
              children: [
                ModesModeCircle.forMode(mode, isSelected: isActive, size: 54),
                const SizedBox(width: 12),

                // Name (+ "مفعّل") and schedule.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(mode.name, style: HesakTextStyles.itemTitle, overflow: TextOverflow.ellipsis),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: HesakColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('مفعّل', style: HesakTextStyles.modeBadge),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(mode.scheduleSummary, style: HesakTextStyles.body.copyWith(height: 1.5)),
                    ],
                  ),
                ),

                ModesStarButton(
                  key: Key('modes_all_star_${mode.id}'),
                  isFavorite: mode.isFavorite,
                  onTap: () => modesToggleFavorite(context, mode),
                ),

                // Delete (not for the general mode).
                if (!mode.isGeneral)
                  IconButton(
                    key: Key('modes_all_delete_${mode.id}'),
                    onPressed: () => modesDeleteWithConfirm(context, mode),
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: HesakColors.danger,
                    tooltip: 'حذف',
                  )
                else
                  const SizedBox(width: 48), // Keeps the stars lined up
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Last card: "إضافة وضع جديد".
class _ModesAllAddCard extends StatelessWidget {
  const _ModesAllAddCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HesakColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
        side: const BorderSide(color: HesakColors.primaryLightBorder, width: 1.3),
      ),
      child: InkWell(
        key: const Key('modes_all_add_card'),
        borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ModeEditorScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: HesakColors.primaryLightBorder, width: 1.5),
                ),
                child: const Icon(Icons.add_rounded, color: HesakColors.iconInactive, size: 28),
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
