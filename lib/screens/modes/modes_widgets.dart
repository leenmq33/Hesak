import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/data/hesak_mode_store.dart';
import '../../core/data/hesak_modes.dart';
import '../../core/data/hesak_sounds.dart';
import '../../core/theme/hesak_colors.dart';
import '../../core/theme/hesak_sizes.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../widgets/hesak_confirm_dialog.dart';
import '../../widgets/hesak_toast.dart';

// =====================================================================
//  MODES WIDGETS — building blocks shared by the الأوضاع pages:
//    modes_screen.dart (main page),
//    mode_editor_screen.dart (edit / add a mode).
//
//  NAMING: everything here starts with "Modes". Keys: 'modes_<name>'.
//  Colors / text styles / sizes come ONLY from lib/core/theme.
//
//  Text rule: a mode name is shown EXACTLY as the user typed it ("النوم").
//  The word "وضع" is only added inside messages ("تمت إضافة وضع النوم ...").
// =====================================================================

// ---------------------------------------------------------------------
// Messages (the toast + confirm dialog are shared: lib/widgets/)
// ---------------------------------------------------------------------

/// Stars / un-stars a mode and shows the message.
void modesToggleFavorite(BuildContext context, HesakModeConfig mode) {
  final bool isNowFavorite = HesakModeStore.instance.toggleFavorite(mode.id);
  showHesakToast(
    context,
    isNowFavorite
        ? 'تمت إضافة وضع ${mode.name} إلى الأوضاع المفضلة'
        : 'تمت إزالة وضع ${mode.name} من الأوضاع المفضلة',
    icon: isNowFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
  );
}

/// Asks, deletes the mode, shows the message. Returns true if deleted.
Future<bool> modesDeleteWithConfirm(BuildContext context, HesakModeConfig mode) async {
  final bool isConfirmed = await showHesakConfirmDialog(
    context,
    title: 'هل تريد حذف وضع ${mode.name}؟',
    message: 'سيتم حذف الوضع وكل إعداداته،\nولا يمكن التراجع عن ذلك.',
    confirmLabel: 'حذف',
    icon: Icons.delete_outline_rounded,
  );
  if (!isConfirmed || !context.mounted) return false;
  HesakModeStore.instance.deleteMode(mode.id);
  showHesakToast(context, 'تم حذف وضع ${mode.name}', icon: Icons.delete_outline_rounded);
  return true;
}

/// Why a mode name is not OK, or null. [exceptId] = the mode being renamed.
String? modesNameProblem(String name, {String? exceptId}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'أدخل اسم الوضع';
  if (trimmed.length > 20) return 'الاسم طويل (20 حرفًا كحد أقصى)';
  final isTaken = HesakModeStore.instance.modes.any((m) => m.id != exceptId && m.name.trim() == trimmed);
  if (isTaken) return 'يوجد وضع بنفس الاسم';
  return null;
}

// ---------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------

/// Rounded button: filled purple ("حفظ") or outlined ("إلغاء").
/// Faded and not tappable when [onTap] is null.
class ModesPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isFilled;
  final Color color;
  final double height;

  const ModesPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isFilled = true,
    this.color = HesakColors.modeSelected,
    this.height = 42,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: isFilled ? color : HesakColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: isFilled ? BorderSide.none : BorderSide(color: color, width: 1.4),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: height,
            child: Center(
              child: Text(
                label,
                style: isFilled
                    ? HesakTextStyles.modeSmallButton
                    : HesakTextStyles.modeSmallButton.copyWith(color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "حفظ" + "إلغاء" under a section. Shown only when the section has changes.
class ModesSaveCancelRow extends StatelessWidget {
  final VoidCallback? onSave;
  final VoidCallback onCancel;
  final String keyPrefix; // e.g. 'modes_sounds' -> modes_sounds_save_button

  const ModesSaveCancelRow({super.key, required this.onSave, required this.onCancel, required this.keyPrefix});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: ModesPillButton(key: Key('${keyPrefix}_save_button'), label: 'حفظ', onTap: onSave, height: 38),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: ModesPillButton(
              key: Key('${keyPrefix}_cancel_button'),
              label: 'إلغاء',
              isFilled: false,
              onTap: onCancel,
              height: 38,
            ),
          ),
        ],
      ),
    );
  }
}

/// Round star button (الأوضاع المفضلة):
///  - favorite: deep purple circle + filled white star
///  - not favorite: light grey circle + grey outlined star
/// [isOnDark] = see-through white circle, for the purple mode card header.
class ModesStarButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  final bool isOnDark;

  const ModesStarButton({super.key, required this.isFavorite, required this.onTap, this.isOnDark = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isFavorite ? 'إزالة من الأوضاع المفضلة' : 'إضافة إلى الأوضاع المفضلة',
      child: Material(
        color: isOnDark
            ? HesakColors.modeHeaderOverlay
            : (isFavorite ? HesakColors.modeSelected : HesakColors.modeUnselectedFill),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: HesakSizes.modeStarButton,
            height: HesakSizes.modeStarButton,
            // The star pops a little when it changes.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                key: ValueKey(isFavorite),
                color: isOnDark || isFavorite ? HesakColors.onPrimary : HesakColors.iconInactive,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Mode circle
// ---------------------------------------------------------------------

/// A mode's round icon. Selected = deep purple with a white icon,
/// not selected = grey. No icon = the first letter of the name.
class ModesModeCircle extends StatelessWidget {
  final IconData? icon;
  final String letter;
  final bool isSelected;
  final double size;

  const ModesModeCircle({
    super.key,
    required this.icon,
    required this.letter,
    required this.isSelected,
    this.size = HesakSizes.modeCircle,
  });

  /// Shortcut for a mode.
  ModesModeCircle.forMode(HesakModeConfig mode, {super.key, required this.isSelected, this.size = HesakSizes.modeCircle})
      : icon = mode.icon,
        letter = mode.firstLetter;

  @override
  Widget build(BuildContext context) {
    final Color contentColor = isSelected ? HesakColors.onPrimary : HesakColors.iconInactive;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? HesakColors.modeSelected : HesakColors.modeUnselectedFill,
        // Soft light-purple ring around the selected one.
        boxShadow: isSelected
            ? const [BoxShadow(color: HesakColors.modeSelectedRing, spreadRadius: 4)]
            : null,
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, color: contentColor, size: size * 0.46)
            : Text(
                letter,
                style: HesakTextStyles.modeCircleLetter.copyWith(color: contentColor, fontSize: size * 0.38),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Section card (opens / closes)
// ---------------------------------------------------------------------

/// White rounded card with a title; tapping the title opens / closes it.
class ModesSectionCard extends StatefulWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  const ModesSectionCard({super.key, required this.title, required this.child, this.initiallyExpanded = true});

  @override
  State<ModesSectionCard> createState() => _ModesSectionCardState();
}

class _ModesSectionCardState extends State<ModesSectionCard> {
  late bool _isExpanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: HesakSizes.sectionGap),
      decoration: BoxDecoration(
        color: HesakColors.surface,
        borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
        border: Border.all(color: HesakColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title row (tap to open / close).
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                HesakSizes.cardPaddingHorizontal, 14, HesakSizes.cardPaddingHorizontal, 14),
              child: Row(
                children: [
                  // Bigger than the labels inside, so it reads as the section title.
                  Expanded(child: Text(widget.title, style: HesakTextStyles.modeSectionTitle)),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: HesakColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // Content (slides open / closed).
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      HesakSizes.cardPaddingHorizontal, 0, HesakSizes.cardPaddingHorizontal, HesakSizes.cardPaddingBottom),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Chips
// ---------------------------------------------------------------------

/// Rounded chip for sounds / alert types / repeat.
/// [isLocked] = grey with a lock (emergency sounds), can't be tapped.
class ModesChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isLocked;

  const ModesChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onTap,
    this.icon,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color fill = isLocked
        ? HesakColors.modeUnselectedFill
        : (isSelected ? HesakColors.primaryLight : HesakColors.surface);
    final Color border = isLocked
        ? HesakColors.modeUnselectedFill
        : (isSelected ? HesakColors.modeSelected : HesakColors.primaryLightBorder);
    final TextStyle textStyle = isSelected && !isLocked ? HesakTextStyles.modeChipSelected : HesakTextStyles.modeChip;
    final IconData? shownIcon = isLocked ? Icons.lock_rounded : icon;

    return Material(
      color: fill,
      shape: StadiumBorder(side: BorderSide(color: border, width: 1.3)),
      child: InkWell(
        onTap: isLocked ? null : onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (shownIcon != null) ...[
                Icon(shownIcon, size: isLocked ? 13 : 16, color: textStyle.color),
                const SizedBox(width: 5),
              ],
              Text(label, style: textStyle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Day chip ("أحد"): purple with white text when picked.
class ModesDayChip extends StatelessWidget {
  final HesakWeekday day;
  final bool isSelected;
  final VoidCallback onTap;

  const ModesDayChip({super.key, required this.day, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? HesakColors.modeSelected : HesakColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: isSelected ? HesakColors.modeSelected : HesakColors.primaryLightBorder, width: 1.3),
      ),
      child: InkWell(
        key: Key('modes_day_${day.name}'),
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            day.shortLabel,
            style: isSelected ? HesakTextStyles.modeDayChipSelected : HesakTextStyles.modeChip,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Schedule (جدولة الوضع): saved periods + add / edit one
// ---------------------------------------------------------------------

/// The list of schedule periods. Each saved period has edit + delete.
/// "إضافة فترة" opens a box to pick days + from/to time, with "حفظ" / "إلغاء".
/// Every change is sent to [onChanged] (the page decides when it's saved).
/// This widget shows the message itself: "تمت إضافة الفترة" / "تم تعديل الفترة" /
/// "تم حذف الفترة".
/// [modeId] = the mode these periods belong to. Two modes can't share the same
/// time, so a new period is also checked against every OTHER mode.
class ModesScheduleEditor extends StatefulWidget {
  final String modeId;
  final List<HesakSchedulePeriod> periods;
  final ValueChanged<List<HesakSchedulePeriod>> onChanged;

  const ModesScheduleEditor({super.key, required this.modeId, required this.periods, required this.onChanged});

  @override
  State<ModesScheduleEditor> createState() => _ModesScheduleEditorState();
}

class _ModesScheduleEditorState extends State<ModesScheduleEditor> {
  static const int _newPeriodIndex = -1;

  int? _editingIndex; // null = not editing, -1 = new period, 0.. = editing that period
  String? _clashMessage; // Red message when the time clashes with another period
  Set<HesakWeekday> _draftDays = {};
  TimeOfDay _draftStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _draftEnd = const TimeOfDay(hour: 6, minute: 0);

  /// If the periods change from somewhere else while a period is open,
  /// close the edit box (its index may point to another period now).
  @override
  void didUpdateWidget(ModesScheduleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_editingIndex != null && !listEquals(oldWidget.periods, widget.periods)) {
      _editingIndex = null;
      _clashMessage = null;
    }
  }

  void _startEditing(int index) {
    setState(() {
      _editingIndex = index;
      _clashMessage = null;
      if (index == _newPeriodIndex) {
        _draftDays = {};
        _draftStart = const TimeOfDay(hour: 22, minute: 0);
        _draftEnd = const TimeOfDay(hour: 6, minute: 0);
      } else {
        final period = widget.periods[index];
        _draftDays = {...period.days};
        _draftStart = period.start;
        _draftEnd = period.end;
      }
    });
  }

  void _cancelEditing() => setState(() {
        _editingIndex = null;
        _clashMessage = null;
      });

  /// true when editing a saved period and nothing was changed yet ("حفظ" stays faded).
  bool get _isUnchangedEdit {
    final index = _editingIndex;
    if (index == null || index == _newPeriodIndex) return false;
    final original = widget.periods[index];
    return setEquals(_draftDays, original.days) && _draftStart == original.start && _draftEnd == original.end;
  }

  /// Saves the period:
  ///  - Same time + same days as a saved period -> not saved, "هذه الفترة موجودة مسبقًا".
  ///  - Same time as another period -> its days are added to that period (one card, no duplicates).
  ///  - Clashes with another period on the same day -> not saved, red message instead.
  ///  - Clashes with a period of ANOTHER mode -> not saved, "هذه الفترة تتعارض مع وضع X".
  void _saveEditing() {
    final int editingIndex = _editingIndex!;
    final candidate = HesakSchedulePeriod(days: {..._draftDays}, start: _draftStart, end: _draftEnd);

    // Another period with exactly the same time -> merge into it.
    int sameTimeIndex = -1;
    for (int i = 0; i < widget.periods.length; i++) {
      final p = widget.periods[i];
      if (i != editingIndex && p.start == candidate.start && p.end == candidate.end) {
        sameTimeIndex = i;
        break;
      }
    }

    // Clash check against every other period (not itself, not the one we merge into).
    final others = [
      for (int i = 0; i < widget.periods.length; i++)
        if (i != editingIndex && i != sameTimeIndex) widget.periods[i],
    ];
    final clashDay = hesakFirstClashDay(candidate, others);
    if (clashDay != null) {
      setState(() => _clashMessage = 'هذا الوقت يتعارض مع فترة موجودة يوم ${clashDay.label}');
      return;
    }

    // Same time AND all its days are already there -> nothing new to add.
    if (sameTimeIndex != -1 && widget.periods[sameTimeIndex].days.containsAll(candidate.days)) {
      setState(() => _clashMessage = 'هذه الفترة موجودة مسبقًا');
      return;
    }

    // Another mode already has this time -> that mode keeps it.
    final HesakModeConfig? otherMode = HesakModeStore.instance.modeClashingWith(candidate, modeId: widget.modeId);
    if (otherMode != null) {
      setState(() => _clashMessage = 'هذه الفترة تتعارض مع وضع ${otherMode.name}');
      return;
    }

    final updated = [...widget.periods];
    final bool isMerged = sameTimeIndex != -1;
    if (isMerged) {
      final target = updated[sameTimeIndex];
      updated[sameTimeIndex] = HesakSchedulePeriod(
        days: {...target.days, ...candidate.days},
        start: target.start,
        end: target.end,
      );
      if (editingIndex != _newPeriodIndex) updated.removeAt(editingIndex); // The edited one joined the other
    } else if (editingIndex == _newPeriodIndex) {
      updated.add(candidate);
    } else {
      updated[editingIndex] = candidate;
    }

    setState(() {
      _editingIndex = null;
      _clashMessage = null;
    });
    widget.onChanged(updated);

    // New period (even when it joined a period with the same time) -> "تمت إضافة الفترة".
    // Edited period -> "تم تعديل الفترة".
    showHesakToast(context, editingIndex == _newPeriodIndex ? 'تمت إضافة الفترة' : 'تم تعديل الفترة');
  }

  Future<void> _deletePeriod(int index) async {
    final period = widget.periods[index];
    final bool isConfirmed = await showHesakConfirmDialog(
      context,
      title: 'هل تريد حذف الفترة؟',
      message: '${period.daysText}\n${period.timeText}',
      confirmLabel: 'حذف',
      icon: Icons.delete_outline_rounded,
    );
    if (!isConfirmed || !mounted) return;
    widget.onChanged([...widget.periods]..removeAt(index));
    showHesakToast(context, 'تم حذف الفترة', icon: Icons.delete_outline_rounded);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.periods.isEmpty && _editingIndex == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('لا توجد فترات بعد', textAlign: TextAlign.center, style: HesakTextStyles.caption),
          ),

        // Saved periods (the one being edited turns into the edit box).
        for (int i = 0; i < widget.periods.length; i++)
          _editingIndex == i ? _buildEditBox(isNew: false) : _buildPeriodCard(i),

        // New period box, or the "إضافة فترة" button.
        if (_editingIndex == _newPeriodIndex)
          _buildEditBox(isNew: true)
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Opacity(
              opacity: _editingIndex == null ? 1 : 0.4, // Finish the open edit first
              child: OutlinedButton.icon(
                key: const Key('modes_schedule_add_period_button'),
                onPressed: _editingIndex == null ? () => _startEditing(_newPeriodIndex) : null,
                icon: const Icon(Icons.add_rounded, size: 18, color: HesakColors.modeSelected),
                label: const Text('إضافة فترة', style: HesakTextStyles.modeLink),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  side: const BorderSide(color: HesakColors.primaryLightBorder, width: 1.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HesakSizes.radiusInnerCard)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// A saved period: days + time, with edit and delete.
  Widget _buildPeriodCard(int index) {
    final period = widget.periods[index];
    return Container(
      key: Key('modes_schedule_period_$index'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: HesakColors.background,
        borderRadius: BorderRadius.circular(HesakSizes.radiusInnerCard),
        border: Border.all(color: HesakColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(period.daysText, style: HesakTextStyles.modePeriodDays),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 15, color: HesakColors.modeSelected),
                    const SizedBox(width: 4),
                    Text(period.timeText, style: HesakTextStyles.modePeriodTime),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('modes_schedule_edit_period_$index'),
            onPressed: _editingIndex == null ? () => _startEditing(index) : null,
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: HesakColors.textSecondary,
            tooltip: 'تعديل',
          ),
          IconButton(
            key: Key('modes_schedule_delete_period_$index'),
            onPressed: _editingIndex == null ? () => _deletePeriod(index) : null,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: HesakColors.danger,
            tooltip: 'حذف',
          ),
        ],
      ),
    );
  }

  /// Box to pick days + time (new period or editing one).
  Widget _buildEditBox({required bool isNew}) {
    final bool hasDays = _draftDays.isNotEmpty;

    return Container(
      key: const Key('modes_schedule_edit_box'),
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HesakColors.primaryLight.withOpacity(0.45),
        borderRadius: BorderRadius.circular(HesakSizes.radiusInnerCard),
        border: Border.all(color: HesakColors.modeSelected, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isNew ? 'فترة جديدة' : 'تعديل الفترة', style: HesakTextStyles.modeLink),
          const SizedBox(height: 10),

          // Days
          const Text('الأيام:', style: HesakTextStyles.modeSettingLabel),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final day in HesakWeekday.values)
                ModesDayChip(
                  day: day,
                  isSelected: _draftDays.contains(day),
                  onTap: () => setState(() {
                    _draftDays.contains(day) ? _draftDays.remove(day) : _draftDays.add(day);
                    _clashMessage = null;
                  }),
                ),
            ],
          ),
          if (!hasDays)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('اختر يومًا واحدًا على الأقل', style: HesakTextStyles.caption),
            ),

          // Time
          const SizedBox(height: 12),
          ModesTimeField(
            key: const Key('modes_schedule_start_time'),
            label: 'من:',
            pickerTitle: 'وقت البداية',
            time: _draftStart,
            onChanged: (time) => setState(() {
              _draftStart = time;
              _clashMessage = null;
            }),
          ),
          const SizedBox(height: 8),
          ModesTimeField(
            key: const Key('modes_schedule_end_time'),
            label: 'إلى:',
            pickerTitle: 'وقت النهاية',
            time: _draftEnd,
            onChanged: (time) => setState(() {
              _draftEnd = time;
              _clashMessage = null;
            }),
          ),

          // Clash message (red).
          if (_clashMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: HesakColors.danger),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _clashMessage!,
                      key: const Key('modes_schedule_clash_message'),
                      style: HesakTextStyles.fieldError,
                    ),
                  ),
                ],
              ),
            ),

          // "حفظ" works only when there's at least one day AND something changed.
          ModesSaveCancelRow(
            keyPrefix: 'modes_schedule_period',
            onSave: hasDays && !_isUnchangedEdit ? _saveEditing : null,
            onCancel: _cancelEditing,
          ),
        ],
      ),
    );
  }
}

/// "من:  [🕐 11:00 م]" — tapping the time opens the phone's clock picker.
/// The same picker everywhere (الأوضاع, تعديل وضع, إضافة وضع), all in Hesak colors.
class ModesTimeField extends StatelessWidget {
  final String label;
  final String pickerTitle; // Title on top of the picker: "وقت البداية" / "وقت النهاية"
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  const ModesTimeField({
    super.key,
    required this.label,
    required this.pickerTitle,
    required this.time,
    required this.onChanged,
  });

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: time,
      // Same title on the clock AND the keyboard view.
      helpText: pickerTitle,
      confirmText: 'تأكيد',
      cancelText: 'إلغاء',
      builder: (context, child) => Theme(data: _hesakTimePickerTheme(Theme.of(context)), child: child!),
    );
    if (picked != null && context.mounted) onChanged(picked);
  }

  /// Hesak colors for the whole picker (no pink / red): ص / م, the chosen hour,
  /// the clock hand, the frame and the buttons.
  static ThemeData _hesakTimePickerTheme(ThemeData base) {
    Color selectedOr(Set<WidgetState> states, Color selected, Color other) =>
        states.contains(WidgetState.selected) ? selected : other;

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: HesakColors.modeSelected,
        onPrimary: HesakColors.onPrimary,
        primaryContainer: HesakColors.primaryLight,
        onPrimaryContainer: HesakColors.modeSelected,
        // Material uses these for ص / م — that's where the pink came from.
        tertiary: HesakColors.modeSelected,
        tertiaryContainer: HesakColors.primaryLight,
        onTertiaryContainer: HesakColors.modeSelected,
        surface: HesakColors.surface,
        onSurface: HesakColors.textPrimary,
        outline: HesakColors.primaryLightBorder,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: HesakColors.surface,
        helpTextStyle: HesakTextStyles.modeSectionTitle,
        hourMinuteColor: WidgetStateColor.resolveWith(
          (states) => selectedOr(states, HesakColors.primaryLight, HesakColors.modeUnselectedFill),
        ),
        hourMinuteTextColor: WidgetStateColor.resolveWith(
          (states) => selectedOr(states, HesakColors.modeSelected, HesakColors.textPrimary),
        ),
        dayPeriodColor: WidgetStateColor.resolveWith(
          (states) => selectedOr(states, HesakColors.primaryLight, Colors.transparent),
        ),
        dayPeriodTextColor: WidgetStateColor.resolveWith(
          (states) => selectedOr(states, HesakColors.modeSelected, HesakColors.textSecondary),
        ),
        dayPeriodBorderSide: const BorderSide(color: HesakColors.primaryLightBorder),
        dialBackgroundColor: HesakColors.modeUnselectedFill,
        dialHandColor: HesakColors.modeSelected,
        dialTextColor: WidgetStateColor.resolveWith(
          (states) => selectedOr(states, HesakColors.onPrimary, HesakColors.textPrimary),
        ),
        entryModeIconColor: HesakColors.modeSelected,
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: HesakColors.modeSelected),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: HesakColors.modeSelected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 48, child: Text(label, style: HesakTextStyles.modeSettingLabel)),
        Material(
          color: HesakColors.primaryLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: HesakColors.primaryLightBorder),
          ),
          child: InkWell(
            onTap: () => _pickTime(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded, size: 17, color: HesakColors.modeSelected),
                  const SizedBox(width: 6),
                  Text(hesakFormatTime(time), style: HesakTextStyles.modePeriodTime),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// General settings (الإعدادات العامة)
// ---------------------------------------------------------------------

/// Call-name alert switch, alert types (pick 1+), repeat (pick 1).
/// [alertRepeat] null / [alertTypes] empty = nothing picked yet (إضافة وضع starts empty).
/// [canClearAlertTypes] true = the last alert type can be un-picked (إضافة وضع).
class ModesGeneralSettingsFields extends StatelessWidget {
  final bool isCallNameAlertOn;
  final Set<HesakAlertType> alertTypes;
  final HesakAlertRepeat? alertRepeat;
  final bool canClearAlertTypes;
  final ValueChanged<bool> onCallNameAlertChanged;
  final ValueChanged<Set<HesakAlertType>> onAlertTypesChanged;
  final ValueChanged<HesakAlertRepeat> onAlertRepeatChanged;

  const ModesGeneralSettingsFields({
    super.key,
    required this.isCallNameAlertOn,
    required this.alertTypes,
    required this.alertRepeat,
    required this.onCallNameAlertChanged,
    required this.onAlertTypesChanged,
    required this.onAlertRepeatChanged,
    this.canClearAlertTypes = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- التنبيه عند نداء اسمك ----
        Row(
          children: [
            const Expanded(child: Text('التنبيه عند نداء اسمك', style: HesakTextStyles.modeSettingLabel)),
            Switch(
              key: const Key('modes_call_name_switch'),
              value: isCallNameAlertOn,
              onChanged: onCallNameAlertChanged,
              thumbColor: const WidgetStatePropertyAll(HesakColors.onPrimary),
              trackColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? HesakColors.modeSelected
                    : HesakColors.passwordRuleUnmet,
              ),
              trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
          ],
        ),

        // ---- نوع التنبيه (one or more) ----
        const SizedBox(height: 10),
        const Text('نوع التنبيه', style: HesakTextStyles.modeSettingLabel),
        const SizedBox(height: 2),
        const Text('يمكنك اختيار أكثر من نوع', style: HesakTextStyles.caption),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in HesakAlertType.values)
              ModesChip(
                key: Key('modes_alert_type_${type.name}'),
                label: type.label,
                icon: type.icon,
                isSelected: alertTypes.contains(type),
                onTap: () {
                  final updated = {...alertTypes};
                  if (updated.contains(type)) {
                    // A saved mode keeps at least one way to alert.
                    if (updated.length == 1 && !canClearAlertTypes) return;
                    updated.remove(type);
                  } else {
                    updated.add(type);
                  }
                  onAlertTypesChanged(updated);
                },
              ),
          ],
        ),

        // ---- تكرار التنبيه (one) ----
        const SizedBox(height: 14),
        const Text('تكرار التنبيه', style: HesakTextStyles.modeSettingLabel),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final repeat in HesakAlertRepeat.values)
              ModesChip(
                key: Key('modes_alert_repeat_${repeat.name}'),
                label: repeat.label,
                isSelected: alertRepeat == repeat,
                onTap: () => onAlertRepeatChanged(repeat),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Sounds (إعدادات الأصوات)
// ---------------------------------------------------------------------

/// Search + sections that open / close. Each section: its sounds as chips,
/// with "تحديد الكل" / "إلغاء الكل". Emergency sounds are shown locked (always on).
class ModesSoundsPicker extends StatefulWidget {
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  const ModesSoundsPicker({super.key, required this.selectedIds, required this.onChanged});

  @override
  State<ModesSoundsPicker> createState() => _ModesSoundsPickerState();
}

class _ModesSoundsPickerState extends State<ModesSoundsPicker> {
  final _searchController = TextEditingController();
  final Set<HesakSoundCategory> _openCategories = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _query => _searchController.text.trim();

  /// Sends the new selection (emergency sounds are always kept).
  void _emit(Set<String> ids) => widget.onChanged({...ids, ...hesakEmergencySoundIds});

  void _toggleSound(String id) {
    final updated = {...widget.selectedIds};
    updated.contains(id) ? updated.remove(id) : updated.add(id);
    _emit(updated);
  }

  void _setAll(HesakSoundCategory category, bool isOn) {
    final ids = hesakSoundsIn(category).map((s) => s.id);
    final updated = {...widget.selectedIds};
    isOn ? updated.addAll(ids) : updated.removeAll(ids);
    _emit(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Search ----
        TextField(
          key: const Key('modes_sounds_search_field'),
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: HesakTextStyles.fieldInput,
          decoration: InputDecoration(
            hintText: 'ابحث عن صوت...',
            hintStyle: HesakTextStyles.fieldHint,
            prefixIcon: const Icon(Icons.search_rounded, color: HesakColors.fieldHint),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    onPressed: () => setState(() => _searchController.clear()),
                    icon: const Icon(Icons.close_rounded, color: HesakColors.fieldHint),
                    tooltip: 'مسح البحث',
                  ),
            filled: true,
            fillColor: HesakColors.navBar,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HesakSizes.radiusInnerCard),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // ---- Sections ----
        for (final category in HesakSoundCategory.values) ..._buildCategory(category),

        if (_query.isNotEmpty && !hesakSounds.any((s) => s.label.contains(_query)))
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('لا يوجد صوت بهذا الاسم', textAlign: TextAlign.center, style: HesakTextStyles.caption),
          ),
      ],
    );
  }

  List<Widget> _buildCategory(HesakSoundCategory category) {
    final allSounds = hesakSoundsIn(category);
    // While searching: only matching sounds, and matching sections open by themselves.
    final sounds = _query.isEmpty ? allSounds : allSounds.where((s) => s.label.contains(_query)).toList();
    if (sounds.isEmpty) return const [];

    final bool isOpen = _query.isNotEmpty || _openCategories.contains(category);
    final int selectedCount = allSounds.where((s) => widget.selectedIds.contains(s.id)).length;
    final bool isAllSelected = selectedCount == allSounds.length;
    final bool isNoneSelected = selectedCount == 0;

    return [
      const Divider(height: 1, color: HesakColors.listDivider),

      // Section title row: icon, name, "2 من 5", arrow (tap to open / close).
      InkWell(
        key: Key('modes_sounds_category_${category.name}'),
        onTap: _query.isNotEmpty
            ? null
            : () => setState(() {
                  _openCategories.contains(category)
                      ? _openCategories.remove(category)
                      : _openCategories.add(category);
                }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(category.icon, size: 20, color: HesakColors.modeSelected),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        category.label,
                        style: HesakTextStyles.modeSettingLabel,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$selectedCount من ${allSounds.length}', style: HesakTextStyles.caption),
                  ],
                ),
              ),
              if (category.isLocked)
                const Padding(
                  padding: EdgeInsetsDirectional.only(end: 4),
                  child: Icon(Icons.lock_rounded, size: 16, color: HesakColors.iconInactive),
                ),
              if (_query.isEmpty)
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: HesakColors.textSecondary),
                ),
            ],
          ),
        ),
      ),

      // Section content.
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: !isOpen
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (category.isLocked)
                      // Why emergency sounds can't be turned off.
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.lock_rounded, size: 13, color: HesakColors.textSecondary),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'أصوات الطوارئ تعمل دائمًا في كل الأوضاع لسلامتك، ولا يمكن إيقافها.',
                                style: HesakTextStyles.body,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_query.isEmpty)
                      // "تحديد الكل" (if not all picked) / "إلغاء الكل" (if some picked).
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!isAllSelected)
                              TextButton(
                                key: Key('modes_sounds_select_all_${category.name}'),
                                onPressed: () => _setAll(category, true),
                                child: const Text('تحديد الكل', style: HesakTextStyles.modeLink),
                              ),
                            if (!isNoneSelected)
                              TextButton(
                                key: Key('modes_sounds_clear_all_${category.name}'),
                                onPressed: () => _setAll(category, false),
                                child: const Text('إلغاء الكل', style: HesakTextStyles.modeLink),
                              ),
                          ],
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final sound in sounds)
                          ModesChip(
                            key: Key('modes_sound_${sound.id}'),
                            label: sound.label,
                            isLocked: category.isLocked,
                            isSelected: widget.selectedIds.contains(sound.id),
                            onTap: () => _toggleSound(sound.id),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    ];
  }
}

// ---------------------------------------------------------------------
// Icon + name picker (edit sheet and add page)
// ---------------------------------------------------------------------

/// Grid of icons (first = no icon -> first letter) + the name field.
/// [isIconPicked] false = nothing is highlighted yet (the add page starts like this).
class ModesIconNamePicker extends StatelessWidget {
  final IconData? icon;
  final bool isIconPicked;
  final ValueChanged<IconData?> onIconChanged;
  final TextEditingController nameController;
  final String? nameError;
  final ValueChanged<String> onNameChanged;

  const ModesIconNamePicker({
    super.key,
    required this.icon,
    required this.onIconChanged,
    required this.nameController,
    required this.nameError,
    required this.onNameChanged,
    this.isIconPicked = true,
  });

  @override
  Widget build(BuildContext context) {
    final String letter = nameController.text.trim().isEmpty ? '؟' : nameController.text.trim().characters.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('الأيقونة:', style: HesakTextStyles.modeSectionTitle),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          // Zero padding on purpose: without it, the grid adds the screen's bottom
          // safe space (here the whole bottom bar height) = a big gap under the icons.
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            // No icon: shows the first letter of the name.
            _iconOption(context, null, letter),
            for (final choice in hesakModeIconChoices) _iconOption(context, choice, letter),
          ],
        ),
        const SizedBox(height: 10), // Keeps the name close to the icons
        const Text('اسم الوضع:', style: HesakTextStyles.modeSectionTitle),
        const SizedBox(height: 8),
        TextField(
          key: const Key('modes_name_field'),
          controller: nameController,
          onChanged: onNameChanged,
          maxLength: 20,
          style: HesakTextStyles.fieldInput,
          decoration: InputDecoration(
            hintText: 'مثال: الصلاة',
            hintStyle: HesakTextStyles.fieldHint,
            counterText: '', // Hide "0/20"
            errorText: nameError,
            errorStyle: HesakTextStyles.fieldError,
            filled: true,
            fillColor: HesakColors.fieldFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HesakSizes.radiusField),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconOption(BuildContext context, IconData? choice, String letter) {
    final bool isSelected = isIconPicked && icon == choice;
    return GestureDetector(
      key: Key('modes_icon_option_${choice?.codePoint ?? 'none'}'),
      onTap: () => onIconChanged(choice),
      // Every option looks the same: grey when not picked, purple when picked.
      // The "no icon" option shows the first letter of the name (or ؟).
      child: ModesModeCircle(icon: choice, letter: letter, isSelected: isSelected, size: 44),
    );
  }
}

/// Bottom sheet to change a mode's icon + name together. Saves to the store.
Future<void> showModesIconNameSheet(BuildContext context, HesakModeConfig mode) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // Can grow when the keyboard opens
    useRootNavigator: true, // Above the bottom bar
    backgroundColor: HesakColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (sheetContext) => _ModesIconNameSheet(mode: mode),
  );
}

class _ModesIconNameSheet extends StatefulWidget {
  final HesakModeConfig mode;

  const _ModesIconNameSheet({required this.mode});

  @override
  State<_ModesIconNameSheet> createState() => _ModesIconNameSheetState();
}

class _ModesIconNameSheetState extends State<_ModesIconNameSheet> {
  late IconData? _icon = widget.mode.icon;
  late final _nameController = TextEditingController(text: widget.mode.name);
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// true when the name or the icon is different from the saved one.
  bool get _hasChanges => _nameController.text.trim() != widget.mode.name || _icon != widget.mode.icon;

  void _save() {
    final problem = modesNameProblem(_nameController.text, exceptId: widget.mode.id);
    if (problem != null) {
      setState(() => _nameError = problem);
      return;
    }
    final name = _nameController.text.trim();
    HesakModeStore.instance.updateMode(
      widget.mode.copyWith(name: name, icon: _icon, clearIcon: _icon == null),
    );
    showHesakToast(context, 'تم حفظ التعديلات'); // Shows on the page under the sheet
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      // Moves up with the keyboard.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: HesakColors.passwordRuleUnmet,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ModesIconNamePicker(
                icon: _icon,
                onIconChanged: (icon) => setState(() => _icon = icon),
                nameController: _nameController,
                nameError: _nameError,
                onNameChanged: (_) => setState(() => _nameError = null),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    // Faded until the name or the icon really changes.
                    child: ModesPillButton(
                      key: const Key('modes_sheet_save_button'),
                      label: 'حفظ',
                      onTap: _hasChanges ? _save : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ModesPillButton(
                      key: const Key('modes_sheet_cancel_button'),
                      label: 'إلغاء',
                      isFilled: false,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// true when two sets have the same items (used to know if a section changed).
bool modesSameSet<T>(Set<T> a, Set<T> b) => setEquals(a, b);
