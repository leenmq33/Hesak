import 'package:flutter/material.dart';
import '../../core/data/hesak_mode_store.dart';
import '../../core/data/hesak_sounds.dart';
import '../../core/theme/hesak_colors.dart';
import '../../core/theme/hesak_sizes.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import '../../widgets/hesak_page_header.dart';
import '../settings/settings_widgets.dart' show showSettingsCallNameSheet;
import 'modes_widgets.dart';
import '../../widgets/hesak_confirm_dialog.dart';
import '../../widgets/hesak_toast.dart';

// =====================================================================
//  MODE EDITOR — one page for BOTH:
//   * Edit a mode   (ModeEditorScreen(modeId: 'sleep'))
//   * Add a new one (ModeEditorScreen())
//
//  EDIT page, top to bottom:
//   circle with a pencil (opens name + icon sheet) -> name ->
//   جدولة الوضع (saved right away) -> الإعدادات العامة -> إعدادات الأصوات
//   -> "حذف الوضع" (not for العام).
//   الإعدادات العامة / الأصوات show "حفظ" + "إلغاء" only after a change.
//   Leaving with unsaved changes asks first.
//
//  ADD page, top to bottom:
//   icon + name -> الإعدادات العامة -> الأصوات (emergency only at first)
//   -> جدولة الوضع (last) -> "إنشاء الوضع".
//   It starts EMPTY: no icon, no alert type, no repeat, call-name alert off.
//   Required before "إنشاء الوضع": name + at least one alert type + repeat.
//   Until then the button is faded and a grey line says what's missing.
//
//  NAMING: everything here starts with "ModeEditor". Keys: 'mode_editor_<name>'.
// =====================================================================

class ModeEditorScreen extends StatefulWidget {
  /// The mode to edit. null = add a new mode.
  final String? modeId;

  const ModeEditorScreen({super.key, this.modeId});

  @override
  State<ModeEditorScreen> createState() => _ModeEditorScreenState();
}

class _ModeEditorScreenState extends State<ModeEditorScreen> {
  final HesakModeStore _store = HesakModeStore.instance;

  bool get _isNew => widget.modeId == null;

  // ---- Drafts (what the user is changing, not saved yet) ----
  late bool _draftCallNameAlert;
  late Set<HesakAlertType> _draftAlertTypes;
  HesakAlertRepeat? _draftAlertRepeat; // null = not picked yet (add page)
  late Set<String> _draftSoundIds;

  // Add page only:
  IconData? _draftIcon;
  bool _isIconPicked = false; // Nothing is highlighted until the user picks
  late final String _newModeId = _store.newModeId(); // Also used to check schedule clashes
  final _nameController = TextEditingController();
  String? _nameError;
  List<HesakSchedulePeriod> _draftPeriods = [];
  bool _hasTouchedNewMode = false; // Something was changed on the add page

  /// The saved mode (edit page). null on the add page, or if it was deleted.
  HesakModeConfig? get _savedMode => _isNew ? null : _store.modeById(widget.modeId!);

  @override
  void initState() {
    super.initState();
    final saved = _savedMode;
    if (saved != null) {
      _resetGeneralDraft(saved);
      _resetSoundsDraft(saved);
    } else {
      // New mode: the user picks everything.
      _draftCallNameAlert = false;
      _draftAlertTypes = {};
      _draftAlertRepeat = null;
      _draftSoundIds = {...hesakEmergencySoundIds}; // Emergency only at first
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _resetGeneralDraft(HesakModeConfig saved) {
    _draftCallNameAlert = saved.isCallNameAlertOn;
    _draftAlertTypes = {...saved.alertTypes};
    _draftAlertRepeat = saved.alertRepeat;
  }

  void _resetSoundsDraft(HesakModeConfig saved) {
    _draftSoundIds = {...saved.soundIds};
  }

  // ---- What changed (edit page) ----

  bool _isGeneralChanged(HesakModeConfig saved) =>
      _draftCallNameAlert != saved.isCallNameAlertOn ||
      !modesSameSet(_draftAlertTypes, saved.alertTypes) ||
      _draftAlertRepeat != saved.alertRepeat;

  bool _isSoundsChanged(HesakModeConfig saved) => !modesSameSet(_draftSoundIds, saved.soundIds);

  bool get _hasUnsavedChanges {
    if (_isNew) return _hasTouchedNewMode;
    final saved = _savedMode;
    if (saved == null) return false;
    return _isGeneralChanged(saved) || _isSoundsChanged(saved);
  }

  // ---- Actions ----

  void _saveGeneral(HesakModeConfig saved) {
    _store.updateMode(saved.copyWith(
      isCallNameAlertOn: _draftCallNameAlert,
      alertTypes: {..._draftAlertTypes},
      alertRepeat: _draftAlertRepeat,
    ));
    showHesakToast(context, 'تم حفظ التعديلات');
  }

  void _saveSounds(HesakModeConfig saved) {
    _store.updateMode(saved.copyWith(soundIds: {..._draftSoundIds}));
    showHesakToast(context, 'تم حفظ التعديلات');
  }

  // ---- Add page: what's still missing ----

  bool get _isNameMissing => _nameController.text.trim().isEmpty;
  bool get _isAlertTypeMissing => _draftAlertTypes.isEmpty;
  bool get _isRepeatMissing => _draftAlertRepeat == null;
  bool get _canCreate => !_isNameMissing && !_isAlertTypeMissing && !_isRepeatMissing;

  void _createMode() {
    if (!_canCreate) return;
    final problem = modesNameProblem(_nameController.text);
    if (problem != null) {
      setState(() => _nameError = problem);
      return;
    }
    final name = _nameController.text.trim();
    _store.addMode(HesakModeConfig(
      id: _newModeId,
      name: name,
      icon: _draftIcon,
      periods: _draftPeriods,
      isCallNameAlertOn: _draftCallNameAlert,
      alertTypes: {..._draftAlertTypes},
      alertRepeat: _draftAlertRepeat!,
      soundIds: {..._draftSoundIds},
    ));
    showHesakToast(context, 'تم إنشاء وضع $name');
    _hasTouchedNewMode = false; // Nothing left unsaved
    Navigator.pop(context);
  }

  Future<void> _deleteMode(HesakModeConfig saved) async {
    final isDeleted = await modesDeleteWithConfirm(context, saved);
    if (isDeleted && mounted) Navigator.pop(context);
  }

  /// Back arrow / phone back button: ask first if something isn't saved.
  Future<void> _handleBack() async {
    if (!_hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }
    final bool shouldLeave = await showHesakConfirmDialog(
      context,
      title: 'هل تريد الخروج بدون حفظ؟',
      message: 'ستُفقد التعديلات التي أجريتها',
      confirmLabel: 'خروج',
      icon: Icons.warning_amber_rounded,
    );
    if (shouldLeave && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // We decide in _handleBack
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: HesakColors.tabPageBackground, // Same lavender as the 4 tabs
        body: SafeArea(
          bottom: false, // The bottom bar (from HesakMainShell) covers the bottom edge
          child: Column(
            children: [
              HesakPageHeader(title: _isNew ? 'إضافة وضع' : 'الأوضاع', onBack: _handleBack),
              Expanded(
                child: ListenableBuilder(
                  // Also rebuilds when الاسم للنداء is added (the call-name switch unlocks).
                  listenable: Listenable.merge([_store, AuthService.instance]),
                  builder: (context, _) => _isNew ? _buildAddPage() : _buildEditPage(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // EDIT page
  // =====================================================================

  Widget _buildEditPage() {
    final saved = _savedMode;
    if (saved == null) return const SizedBox.shrink(); // Deleted, page is closing

    final bool isGeneralChanged = _isGeneralChanged(saved);
    final bool isSoundsChanged = _isSoundsChanged(saved);

    // Column (not ListView) so the sections keep their state when scrolled off screen.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(HesakSizes.pagePadding, 4, HesakSizes.pagePadding, HesakSizes.pageBottomSafeSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // Space under the header line, so the circle doesn't touch it.
        const SizedBox(height: 18),
        // ---- Circle with pencil (one button edits name + icon) ----
        Center(
          child: GestureDetector(
            key: const Key('mode_editor_edit_icon_name_button'),
            onTap: () => showModesIconNameSheet(context, saved),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ModesModeCircle.forMode(saved, isSelected: true, size: HesakSizes.modeCircleLarge),
                PositionedDirectional(
                  bottom: -2,
                  end: -2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HesakColors.surface,
                      border: Border.all(color: HesakColors.primaryLightBorder, width: 1.5),
                    ),
                    child: const Icon(Icons.edit_rounded, size: 16, color: HesakColors.modeSelected),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(saved.name, textAlign: TextAlign.center, style: HesakTextStyles.modeName),
        const SizedBox(height: 16),

        // ---- جدولة الوضع (first on the edit page, saved right away) ----
        ModesSectionCard(
          title: 'جدولة الوضع',
          icon: Icons.calendar_month_outlined,
          child: ModesScheduleEditor(
            modeId: saved.id,
            periods: saved.periods,
            // Saved right away. The schedule widget shows its own message.
            onChanged: (periods) => _store.updateMode(saved.copyWith(periods: periods)),
          ),
        ),

        // ---- الإعدادات العامة ----
        ModesSectionCard(
          title: 'الإعدادات العامة',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGeneralFields(),
              if (isGeneralChanged)
                ModesSaveCancelRow(
                  keyPrefix: 'mode_editor_general',
                  onSave: () => _saveGeneral(saved),
                  onCancel: () => setState(() => _resetGeneralDraft(saved)),
                ),
            ],
          ),
        ),

        // ---- إعدادات الأصوات ----
        ModesSectionCard(
          title: 'إعدادات الأصوات',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSoundsPicker(),
              if (isSoundsChanged) ...[
                // A line across the section, so "حفظ" / "إلغاء" clearly belong to
                // ALL the sounds (not only the last category).
                const SizedBox(height: 22),
                const Divider(height: 1, thickness: 1.2, color: HesakColors.primaryLightBorder),
                const SizedBox(height: 4),
                ModesSaveCancelRow(
                  keyPrefix: 'mode_editor_sounds',
                  onSave: () => _saveSounds(saved),
                  onCancel: () => setState(() => _resetSoundsDraft(saved)),
                ),
              ],
            ],
          ),
        ),

        // ---- Delete (not for العام) ----
        const SizedBox(height: 8),
        if (saved.isGeneral)
          const Text(
            'الوضع العام هو الوضع الأساسي ولا يمكن حذفه',
            textAlign: TextAlign.center,
            style: HesakTextStyles.caption,
          )
        else
          Center(
            child: TextButton.icon(
              key: const Key('mode_editor_delete_button'),
              onPressed: () => _deleteMode(saved),
              icon: const Icon(Icons.delete_outline_rounded, color: HesakColors.danger),
              label: const Text('حذف الوضع', style: HesakTextStyles.modeDanger),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // ADD page
  // =====================================================================

  Widget _buildAddPage() {
    // Column (not ListView) so the sections keep their state when scrolled off screen.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(HesakSizes.pagePadding, 4, HesakSizes.pagePadding, HesakSizes.pageBottomSafeSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // ---- Icon + name (in a white card, like the sections under it) ----
        Container(
          padding: const EdgeInsets.all(HesakSizes.cardPaddingHorizontal),
          decoration: BoxDecoration(
            color: HesakColors.surface,
            borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
            border: Border.all(color: HesakColors.homeCardBorder),
            boxShadow: const [BoxShadow(color: HesakColors.homeCardShadow, blurRadius: 18, offset: Offset(0, 6))],
          ),
          child: ModesIconNamePicker(
          icon: _draftIcon,
          isIconPicked: _isIconPicked,
          onIconChanged: (icon) => setState(() {
            _draftIcon = icon;
            _isIconPicked = true;
            _hasTouchedNewMode = true;
          }),
          nameController: _nameController,
          nameError: _nameError,
          onNameChanged: (_) => setState(() {
            _nameError = null;
            _hasTouchedNewMode = true;
          }),
          ),
        ),
        const SizedBox(height: HesakSizes.sectionGap),

        ModesSectionCard(title: 'الإعدادات العامة', child: _buildGeneralFields()),
        ModesSectionCard(title: 'إعدادات الأصوات', child: _buildSoundsPicker()),

        // ---- جدولة الوضع (last on the add page) ----
        ModesSectionCard(
          title: 'جدولة الوضع',
          icon: Icons.calendar_month_outlined,
          child: ModesScheduleEditor(
            modeId: _newModeId,
            periods: _draftPeriods,
            onChanged: (periods) => setState(() {
              _draftPeriods = periods;
              _hasTouchedNewMode = true;
            }),
          ),
        ),

        const SizedBox(height: 8),
        // Faded until the name, an alert type and the repeat are picked.
        ModesPillButton(
          key: const Key('mode_editor_create_button'),
          label: 'إنشاء الوضع',
          height: HesakSizes.buttonHeight,
          onTap: _canCreate ? _createMode : null,
        ),
        if (!_canCreate) _buildMissingHint(),
        ],
      ),
    );
  }

  // =====================================================================
  // Shared pieces (edit + add)
  // =====================================================================

  /// Grey line under "إنشاء الوضع": what's still missing (the missing parts in bold purple).
  ///  e.g. "اكتب اسم الوضع واختر نوع التنبيه وتكرار التنبيه لإنشاء الوضع"
  Widget _buildMissingHint() {
    const TextStyle missingStyle = TextStyle(fontWeight: FontWeight.w700, color: HesakColors.modeSelected);
    final List<String> toPick = [
      if (_isAlertTypeMissing) 'نوع التنبيه',
      if (_isRepeatMissing) 'تكرار التنبيه',
    ];

    final List<InlineSpan> spans = [];
    if (_isNameMissing) {
      spans.add(const TextSpan(text: 'اكتب '));
      spans.add(const TextSpan(text: 'اسم الوضع', style: missingStyle));
      if (toPick.isNotEmpty) spans.add(const TextSpan(text: ' و'));
    }
    if (toPick.isNotEmpty) {
      spans.add(const TextSpan(text: 'اختر '));
      for (int i = 0; i < toPick.length; i++) {
        if (i > 0) spans.add(const TextSpan(text: ' و'));
        spans.add(TextSpan(text: toPick[i], style: missingStyle));
      }
    }
    spans.add(const TextSpan(text: ' لإنشاء الوضع'));

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text.rich(
        TextSpan(children: spans),
        key: const Key('mode_editor_missing_hint'),
        textAlign: TextAlign.center,
        style: HesakTextStyles.modeHint.copyWith(height: 1.6),
      ),
    );
  }

  Widget _buildGeneralFields() {
    return ModesGeneralSettingsFields(
      isCallNameAlertOn: _draftCallNameAlert,
      alertTypes: _draftAlertTypes,
      alertRepeat: _draftAlertRepeat,
      canClearAlertTypes: _isNew, // A new mode may un-pick all (then it can't be created yet)
      // No الاسم للنداء yet -> the switch is locked, with "إضافة الاسم" (opens the sheet here).
      isCallNameAvailable: AuthService.instance.currentCallName != null,
      onAddCallName: () => showSettingsCallNameSheet(context),
      onCallNameAlertChanged: (value) => setState(() {
        _draftCallNameAlert = value;
        _hasTouchedNewMode = true;
      }),
      onAlertTypesChanged: (types) => setState(() {
        _draftAlertTypes = types;
        _hasTouchedNewMode = true;
      }),
      onAlertRepeatChanged: (repeat) => setState(() {
        _draftAlertRepeat = repeat;
        _hasTouchedNewMode = true;
      }),
    );
  }

  Widget _buildSoundsPicker() {
    return ModesSoundsPicker(
      selectedIds: _draftSoundIds,
      onChanged: (ids) => setState(() {
        _draftSoundIds = ids;
        _hasTouchedNewMode = true;
      }),
    );
  }
}
