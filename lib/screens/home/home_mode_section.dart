import 'package:flutter/material.dart';
import '../../core/data/hesak_mode_store.dart';
import '../../core/theme/hesak_colors.dart';
import '../../core/theme/hesak_sizes.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import '../modes/modes_widgets.dart';

// =====================================================================
//  HOME — CURRENT MODE SECTION (الرئيسية, under "الأصوات الحالية")
//
//  1) Card "الوضع الحالي" (purple header):
//       icon, "الوضع الحالي", name + "مفعّل" / "غير مفعّل", schedule line,
//       star (الأوضاع المفضلة), arrow ⌄ that opens / closes جدولة الوضع.
//       Listening OFF -> lighter purple + a hint line:
//       "اضغط زر الاستماع في الأعلى لتفعيل الوضع".
//     جدولة الوضع CAN be changed here (add / edit / delete periods).
//
//  2) White card "إعدادات وضع X" — 4 tiles, VIEW ONLY:
//       نوع التنبيه · الأصوات المفعّلة · التنبيه عند نداء اسمك · تكرار التنبيه
//     Changing these (and the name / icon / sounds) is only on the الأوضاع tab.
//
//  Data: HesakModeStore (mode + listening) and AuthService (call name).
//  NAMING: everything here starts with "Home". Keys: 'home_<name>'.
// =====================================================================

/// The current mode card + its settings summary.
class HomeModeSection extends StatefulWidget {
  const HomeModeSection({super.key});

  @override
  State<HomeModeSection> createState() => _HomeModeSectionState();
}

class _HomeModeSectionState extends State<HomeModeSection> {
  bool _isScheduleOpen = false; // Closed when the page opens

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([HesakModeStore.instance, AuthService.instance]),
      builder: (context, _) {
        final store = HesakModeStore.instance;
        final HesakModeConfig mode = store.selectedMode;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModeCard(mode, store.isListening),
            const SizedBox(height: HesakSizes.sectionGap),
            // White card (like "الأصوات الحالية"): "إعدادات وضع النوم" + the 4 tiles.
            Container(
              key: const Key('home_mode_settings_card'),
              padding: const EdgeInsets.fromLTRB(
                HesakSizes.cardPaddingHorizontal,
                HesakSizes.cardPaddingTop,
                HesakSizes.cardPaddingHorizontal,
                HesakSizes.cardPaddingBottom,
              ),
              decoration: BoxDecoration(
                color: HesakColors.surface,
                borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
                border: Border.all(color: HesakColors.surfaceBorder),
                boxShadow: [
                  BoxShadow(
                    color: HesakColors.primary.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The mode name exactly as the user typed it.
                  Text('إعدادات وضع ${mode.name}', style: HesakTextStyles.cardTitle),
                  const SizedBox(height: 10),
                  _HomeModeSettingsTiles(mode: mode),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Purple header (+ hint line when not listening) + the schedule when opened.
  Widget _buildModeCard(HesakModeConfig mode, bool isListening) {
    return Container(
      key: const Key('home_mode_card'),
      clipBehavior: Clip.antiAlias, // Keeps the purple header inside the rounded corners
      decoration: BoxDecoration(
        color: HesakColors.surface,
        borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
        border: Border.all(color: HesakColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(mode, isListening),
          if (!isListening)
            Container(
              key: const Key('home_mode_listen_hint'),
              color: HesakColors.modeTileSelectedFill,
              padding: const EdgeInsets.symmetric(horizontal: HesakSizes.cardPaddingHorizontal, vertical: 9),
              child: const Text('اضغط زر الاستماع في الأعلى لتفعيل الوضع', style: HesakTextStyles.modeHint),
            ),
          // جدولة الوضع (opens with the arrow). Saved right away, like on الأوضاع.
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            alignment: Alignment.topCenter,
            child: !_isScheduleOpen
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      HesakSizes.cardPaddingHorizontal,
                      12,
                      HesakSizes.cardPaddingHorizontal,
                      HesakSizes.cardPaddingBottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('جدولة الوضع', style: HesakTextStyles.modeSectionTitle),
                        const SizedBox(height: 8),
                        ModesScheduleEditor(
                          // New key per mode, so an open edit box doesn't carry over to another mode.
                          key: ValueKey('home_schedule_${mode.id}'),
                          modeId: mode.id,
                          periods: mode.periods,
                          onChanged: (periods) => HesakModeStore.instance.updateMode(mode.copyWith(periods: periods)),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Icon · "الوضع الحالي" · name + badge · schedule line · star · arrow.
  Widget _buildHeader(HesakModeConfig mode, bool isListening) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 10, 12),
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
            width: 48,
            height: 48,
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
                Text('الوضع الحالي', style: HesakTextStyles.modeHeaderSubtitle.copyWith(fontSize: 11)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        mode.name,
                        key: const Key('home_mode_name'),
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
          // Star (add to / remove from الأوضاع المفضلة) — allowed from الرئيسية.
          ModesStarButton(
            key: const Key('home_mode_star_button'),
            isFavorite: mode.isFavorite,
            isOnDark: true,
            onTap: () => modesToggleFavorite(context, mode),
          ),
          const SizedBox(width: 8),
          // Arrow: open / close جدولة الوضع.
          Tooltip(
            message: _isScheduleOpen ? 'إخفاء الجدولة' : 'عرض الجدولة',
            child: Material(
              color: HesakColors.modeHeaderOverlay,
              shape: const CircleBorder(),
              child: InkWell(
                key: const Key('home_mode_schedule_toggle'),
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _isScheduleOpen = !_isScheduleOpen),
                child: SizedBox(
                  width: HesakSizes.modeStarButton,
                  height: HesakSizes.modeStarButton,
                  child: AnimatedRotation(
                    turns: _isScheduleOpen ? 0.5 : 0, // ⌄ turns into ⌃
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: HesakColors.onPrimary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "إعدادات وضع X": 4 view-only tiles (2 x 2).
class _HomeModeSettingsTiles extends StatelessWidget {
  final HesakModeConfig mode;

  const _HomeModeSettingsTiles({required this.mode});

  @override
  Widget build(BuildContext context) {
    // Works only when the user has a الاسم للنداء; otherwise it shows as off.
    final bool hasCallName = AuthService.instance.currentCallName != null;
    final String callNameText = hasCallName && mode.isCallNameAlertOn ? 'مفعّل' : 'غير مفعّل';

    final alertTypes = [
      for (final type in HesakAlertType.values)
        if (mode.alertTypes.contains(type)) type,
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _HomeSettingTile(
                key: const Key('home_tile_alert_types'),
                label: 'نوع التنبيه',
                value: alertTypes.isEmpty
                    ? const Text('لا يوجد', style: HesakTextStyles.cardTitle)
                    : Row(
                        children: [
                          for (final type in alertTypes)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 6),
                              child: Tooltip(
                                message: type.label,
                                child: Icon(type.icon, size: 20, color: HesakColors.modeSelected),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HomeSettingTile(
                key: const Key('home_tile_sounds'),
                label: 'الأصوات المفعّلة',
                value: Text(modesSoundsCountText(mode.soundIds.length), style: HesakTextStyles.cardTitle),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _HomeSettingTile(
                key: const Key('home_tile_call_name'),
                label: 'التنبيه عند نداء اسمك',
                value: Text(callNameText, style: HesakTextStyles.cardTitle),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HomeSettingTile(
                key: const Key('home_tile_repeat'),
                label: 'تكرار التنبيه',
                value: Text(mode.alertRepeat.label, style: HesakTextStyles.cardTitle),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One light-purple tile: small grey label on top, the value under it.
class _HomeSettingTile extends StatelessWidget {
  final String label;
  final Widget value;

  const _HomeSettingTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: HesakColors.modeTileSelectedFill,
        borderRadius: BorderRadius.circular(HesakSizes.radiusInnerCard),
        border: Border.all(color: HesakColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: HesakTextStyles.modeHint, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          value,
        ],
      ),
    );
  }
}
