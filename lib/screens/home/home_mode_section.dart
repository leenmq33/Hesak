import 'package:flutter/material.dart';
import '../../core/data/hesak_mode_store.dart';
import '../../core/theme/hesak_colors.dart';
import '../../core/theme/hesak_sizes.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import '../modes/modes_widgets.dart';

// =====================================================================
//  HOME — CURRENT MODE CARD (الرئيسية, under the listen button)
//
//  ONE card that belongs to the mode:
//    1) Header: icon · "وضع X" + مفعّل / غير مفعّل · star (yellow when favorite)
//    2) 4 settings tiles, always shown (view only — changed on الأوضاع):
//         نوع التنبيه · الأصوات · نداء اسمك · التكرار
//    3) "الجدولة · <line>" box with an arrow ⌄ that opens جدولة الوضع
//       (add / edit / delete periods, saved right away).
//
//  Listening OFF -> light lavender card (the mode is not on yet).
//  Listening ON  -> dark purple card (the mode is on). Tiles stay white.
//
//  Data: HesakModeStore (mode + listening) and AuthService (call name).
//  NAMING: everything here starts with "Home". Keys: 'home_<name>'.
// =====================================================================

/// The current mode card.
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
        final bool isListening = store.isListening;

        return AnimatedContainer(
          key: const Key('home_mode_card'),
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: isListening ? null : HesakColors.homeModeCardIdle,
            gradient: isListening
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [HesakColors.buttonPrimary, HesakColors.primary],
                  )
                : null,
            borderRadius: BorderRadius.circular(HesakSizes.radiusCard + 2),
            border: Border.all(color: isListening ? HesakColors.primary : HesakColors.homeModeCardIdleBorder),
            boxShadow: [
              BoxShadow(
                color: HesakColors.primary.withOpacity(isListening ? 0.30 : 0.08),
                blurRadius: isListening ? 26 : 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(mode, isListening),
              const SizedBox(height: 12),
              _HomeModeSettingsTiles(key: const Key('home_mode_settings'), mode: mode),
              const SizedBox(height: 10),
              _buildScheduleBox(mode),
            ],
          ),
        );
      },
    );
  }

  /// Icon · "وضع X" + badge · star.
  Widget _buildHeader(HesakModeConfig mode, bool isListening) {
    final Color mainText = isListening ? HesakColors.onPrimary : HesakColors.textPrimary;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Row(
        children: [
          // Icon (or first letter) in a rounded square.
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isListening ? HesakColors.modeHeaderOverlay : HesakColors.primary,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: mode.icon != null
                  ? Icon(mode.icon, size: 24, color: HesakColors.onPrimary)
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
                        'وضع ${mode.name}',
                        key: const Key('home_mode_name'),
                        style: HesakTextStyles.modeHeaderName.copyWith(color: mainText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ModesStateBadge(isListening: isListening),
                  ],
                ),
              ],
            ),
          ),
          // Star (add to / remove from الأوضاع المفضلة).
          ModesStarButton(
            key: const Key('home_mode_star_button'),
            isFavorite: mode.isFavorite,
            isOnDark: isListening,
            onTap: () => modesToggleFavorite(context, mode),
          ),
        ],
      ),
    );
  }

  /// White box: "الجدولة · بدون جدولة" + round arrow. Opens جدولة الوضع.
  Widget _buildScheduleBox(HesakModeConfig mode) {
    return Container(
      key: const Key('home_mode_schedule_box'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HesakColors.surface,
        borderRadius: BorderRadius.circular(HesakSizes.radiusInnerCard + 2),
        border: Border.all(color: HesakColors.homeModeCardIdleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The whole row is tappable, not only the arrow.
          InkWell(
            key: const Key('home_mode_schedule_toggle'),
            onTap: () => setState(() => _isScheduleOpen = !_isScheduleOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 20, color: HesakColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'الجدولة', style: HesakTextStyles.itemTitle),
                          TextSpan(text: '  ·  ${mode.scheduleLine}', style: HesakTextStyles.modeHint),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Semantics(
                    label: _isScheduleOpen ? 'إخفاء الجدولة' : 'عرض الجدولة',
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: HesakColors.primaryLight),
                      child: AnimatedRotation(
                        turns: _isScheduleOpen ? 0.5 : 0, // ⌄ turns into ⌃
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: HesakColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // جدولة الوضع (opens with the arrow). Saved right away, like on الأوضاع.
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            alignment: Alignment.topCenter,
            child: !_isScheduleOpen
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: ModesScheduleEditor(
                      // New key per mode, so an open edit box doesn't carry over to another mode.
                      key: ValueKey('home_schedule_${mode.id}'),
                      modeId: mode.id,
                      periods: mode.periods,
                      onChanged: (periods) => HesakModeStore.instance.updateMode(mode.copyWith(periods: periods)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The mode's 4 view-only settings (2 x 2).
class _HomeModeSettingsTiles extends StatelessWidget {
  final HesakModeConfig mode;

  const _HomeModeSettingsTiles({super.key, required this.mode});

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
                icon: Icons.vibration_rounded,
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
                icon: Icons.graphic_eq_rounded,
                label: 'الأصوات',
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
                icon: Icons.person_outline_rounded,
                label: 'نداء اسمك',
                value: Text(callNameText, style: HesakTextStyles.cardTitle),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HomeSettingTile(
                key: const Key('home_tile_repeat'),
                icon: Icons.repeat_rounded,
                label: 'التكرار',
                value: Text(mode.alertRepeat.label, style: HesakTextStyles.cardTitle),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One white tile: small icon box, grey label, the value under it.
class _HomeSettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget value;

  const _HomeSettingTile({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HesakColors.surface,
        borderRadius: BorderRadius.circular(HesakSizes.radiusInnerCard + 2),
        border: Border.all(color: HesakColors.homeModeCardIdleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: HesakColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: HesakColors.primary),
          ),
          const SizedBox(height: 8),
          Text(label, style: HesakTextStyles.modeHint, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          value,
        ],
      ),
    );
  }
}