import 'package:flutter/material.dart';
import '../../core/data/hesak_mode_store.dart';
import '../../core/theme/hesak_colors.dart';
import '../../core/theme/hesak_sizes.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import '../modes/modes_widgets.dart';

// =====================================================================
//  HOME — CURRENT MODE CARD (الرئيسية, under الأصوات الحالية)
//
//  ONE purple card that belongs to the mode:
//    1) Header: icon · "وضع X" + مفعّل / غير مفعّل · star (yellow when favorite)
//    2) 2 matte white tiles, view only — changed on الأوضاع:
//         نوع التنبيه · نداء اسمك (purple round icon in the middle)
//    3) Glass "الجدولة · <line>" box with an arrow ⌄ that opens جدولة الوضع
//       (add / edit / delete periods, saved right away).
//
//  Listening OFF -> light purple card (same purple as الأوضاع).
//  Listening ON  -> very dark purple card.
//  The schedule box is see-through purple; the 2 tiles are matte white.
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
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: isListening ? HesakColors.homeModeCardActive : HesakColors.homeModeCardIdle,
            ),
            borderRadius: BorderRadius.circular(HesakSizes.radiusCard + 2),
            border: Border.all(color: HesakColors.homeModeCardBorder),
            boxShadow: [
              BoxShadow(
                color: HesakColors.primaryDark.withValues(alpha: isListening ? 0.35 : 0.18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(mode, isListening),
              const SizedBox(height: 12),
              _HomeModeSettingsTiles(key: const Key('home_mode_settings'), mode: mode, isListening: isListening),
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
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Row(
        children: [
          // Icon (or first letter) in a see-through rounded square.
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: HesakColors.homeGlassIcon,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: mode.icon != null
                  ? Icon(mode.icon, size: 24, color: HesakColors.onHomeGlass)
                  : Text(mode.firstLetter, style: HesakTextStyles.modeCircleLetter.copyWith(color: HesakColors.onHomeGlass)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'وضع ${mode.name}',
                    key: const Key('home_mode_name'),
                    style: HesakTextStyles.modeHeaderName.copyWith(color: HesakColors.onHomeGlass),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ModesStateBadge(isListening: isListening),
              ],
            ),
          ),
          // Star (add to / remove from الأوضاع المفضلة). Always on purple here.
          ModesStarButton(
            key: const Key('home_mode_star_button'),
            isFavorite: mode.isFavorite,
            isOnDark: true,
            onTap: () => modesToggleFavorite(context, mode),
          ),
        ],
      ),
    );
  }

  /// Glass box: "الجدولة · بدون جدولة" + round arrow. Opens جدولة الوضع.
  Widget _buildScheduleBox(HesakModeConfig mode) {
    return Container(
      key: const Key('home_mode_schedule_box'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HesakColors.homeGlassFill,
        borderRadius: BorderRadius.circular(HesakSizes.radiusInnerCard + 2),
        border: Border.all(color: HesakColors.homeGlassBorder),
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
                  const Icon(Icons.calendar_month_outlined, size: 20, color: HesakColors.onHomeGlass),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'الجدولة',
                            style: HesakTextStyles.itemTitle.copyWith(color: HesakColors.onHomeGlass),
                          ),
                          TextSpan(
                            text: '  ·  ${mode.scheduleLine}',
                            style: HesakTextStyles.modeHint.copyWith(color: HesakColors.onHomeGlassSoft),
                          ),
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
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: HesakColors.homeGlassIcon),
                      child: AnimatedRotation(
                        turns: _isScheduleOpen ? 0.5 : 0, // ⌄ turns into ⌃
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: HesakColors.onHomeGlass),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // جدولة الوضع (opens with the arrow). Saved right away, like on الأوضاع.
          // Shown on a soft lavender panel so the editor stays easy to read.
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            alignment: Alignment.topCenter,
            child: !_isScheduleOpen
                ? const SizedBox(width: double.infinity)
                : Container(
                    margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: HesakColors.homeCardGradient.last,
                      borderRadius: BorderRadius.circular(HesakSizes.radiusInnerCard),
                    ),
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

/// The mode's 2 view-only settings: نوع التنبيه · نداء اسمك.
class _HomeModeSettingsTiles extends StatelessWidget {
  final HesakModeConfig mode;
  final bool isListening; // Darker icon circles while listening

  const _HomeModeSettingsTiles({super.key, required this.mode, required this.isListening});

  @override
  Widget build(BuildContext context) {
    // Works only when the user has a الاسم للنداء; otherwise it shows as off.
    final bool hasCallName = AuthService.instance.currentCallName != null;
    final String callNameText = hasCallName && mode.isCallNameAlertOn ? 'مفعّل' : 'غير مفعّل';

    // The chosen alert types (fixed order of HesakAlertType), shown as icons.
    final List<HesakAlertType> alertTypes = [
      for (final type in HesakAlertType.values)
        if (mode.alertTypes.contains(type)) type,
    ];

    // Same height for both tiles (icons vs. text).
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _HomeSettingTile(
            key: const Key('home_tile_alert_types'),
            icon: Icons.vibration_rounded,
            label: 'نوع التنبيه',
            // Icons instead of words (اهتزاز / إشعار / وميض). None -> "لا يوجد".
            value: alertTypes.isEmpty ? 'لا يوجد' : alertTypes.map((t) => t.label).join(' + '),
            valueIcons: alertTypes.map((t) => t.icon).toList(),
            isListening: isListening,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _HomeSettingTile(
            key: const Key('home_tile_call_name'),
            icon: Icons.person_outline_rounded,
            label: 'نداء اسمك',
            value: callNameText,
            isListening: isListening,
          ),
        ),
      ],
      ),
    );
  }
}

/// One matte white tile: purple round icon in the middle, then the small
/// label ("نوع التنبيه"), then its value under it ("اهتزاز + وميض").
class _HomeSettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value; // Also read by screen readers when icons are shown

  /// When not empty, these icons are shown instead of [value] (نوع التنبيه).
  final List<IconData> valueIcons;
  final bool isListening;

  const _HomeSettingTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueIcons = const [],
    required this.isListening,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: HesakColors.surface, // Matte white
        borderRadius: BorderRadius.circular(HesakSizes.radiusInnerCard + 2),
        border: Border.all(color: HesakColors.surfaceBorder),
      ),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening ? HesakColors.primary : HesakColors.modeHeaderIdleEnd,
            ),
            child: Icon(icon, size: 20, color: HesakColors.onHomeGlass),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: HesakTextStyles.modeHint,
          ),
          const SizedBox(height: 4),
          if (valueIcons.isEmpty)
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HesakTextStyles.cardTitle,
            )
          else
            Semantics(
              label: value,
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < valueIcons.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Icon(valueIcons[i], size: 24, color: HesakColors.textPrimary),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}