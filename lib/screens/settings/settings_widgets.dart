import 'package:flutter/material.dart';
import '../../core/theme/hesak_palette.dart';
import '../../core/theme/hesak_sizes.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../auth/auth_widgets.dart' show AuthValidators;

// =====================================================================
//  SETTINGS WIDGETS — building blocks for the الإعدادات pages
//  (settings_screen.dart, settings_password_screen.dart,
//   settings_email_screen.dart).
//
//  Everything here follows the appearance (فاتح / داكن): colors come from
//  HesakPalette.current, text styles from HesakTextStyles + palette colors.
//
//  NAMING: everything here starts with "Settings". Keys: 'settings_<name>'.
// =====================================================================

// (The toast + confirm dialog are shared by the whole app: lib/widgets/hesak_toast.dart,
//  lib/widgets/hesak_confirm_dialog.dart.)

// ---------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------

/// Rounded button: filled ("حفظ") or outlined ("إلغاء" / "تسجيل الخروج").
/// Faded + not tappable when [onTap] is null. Shows a spinner while [isLoading].
class SettingsButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isFilled;
  final bool isLoading;
  final Color? color; // null = the appearance's accent purple
  final IconData? icon;
  final double height;

  const SettingsButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isFilled = true,
    this.isLoading = false,
    this.color,
    this.icon,
    this.height = HesakSizes.buttonHeight,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HesakPalette.current;
    final Color main = color ?? palette.accent;
    final Color content = isFilled ? palette.onAccent : main;
    final radius = BorderRadius.circular(height / 2);

    return Opacity(
      opacity: onTap == null && !isLoading ? 0.45 : 1,
      child: Material(
        color: isFilled ? main : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: isFilled ? BorderSide.none : BorderSide(color: main, width: 1.5),
        ),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: radius,
          child: SizedBox(
            height: height,
            child: Center(
              child: isLoading
                  ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: content))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 19, color: content),
                          const SizedBox(width: 6),
                        ],
                        Text(label, style: HesakTextStyles.modeSmallButton.copyWith(color: content, fontSize: 15)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Sections & rows
// ---------------------------------------------------------------------

/// Small grey title above a group ("الحساب", "التفضيلات").
class SettingsSectionTitle extends StatelessWidget {
  final String title;

  const SettingsSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    // Listens by itself, so it updates on فاتح / داكن even when created with const.
    return ListenableBuilder(
      listenable: HesakThemeController.instance,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
        child: Text(title, style: HesakTextStyles.modeSectionTitle.copyWith(color: HesakPalette.current.textSecondary, fontSize: 14)),
      ),
    );
  }
}

/// Rounded card holding rows, with thin lines between them.
class SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final palette = HesakPalette.current;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
        border: Border.all(color: palette.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: palette.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One row: icon box, title (+ value under it), something at the end.
/// Tappable when [onTap] is given (then it shows a "forward" arrow if no [trailing]).
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsRow({super.key, required this.icon, required this.title, this.value, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = HesakPalette.current;
    final Widget? end = trailing ??
        (onTap != null
            // "Forward" arrow: points left in Arabic.
            ? Icon(Icons.arrow_forward_ios_rounded, size: 15, color: palette.iconInactive)
            : null);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            // Icon in a soft purple rounded box.
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(HesakSizes.radiusIconBox),
              ),
              child: Icon(icon, size: 20, color: palette.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: HesakTextStyles.itemTitle.copyWith(color: palette.textPrimary)),
                  if (value != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HesakTextStyles.body.copyWith(color: palette.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
            if (end != null) ...[const SizedBox(width: 8), end],
          ],
        ),
      ),
    );
  }
}

/// Two (or more) options side by side, the picked one is a raised white pill.
/// Used for الصوت (ذكر / أنثى) and المظهر (فاتح / داكن).
class SettingsSegmented<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final IconData Function(T)? iconOf;
  final ValueChanged<T> onChanged;
  final String keyPrefix; // e.g. 'settings_voice' -> settings_voice_male

  const SettingsSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    required this.keyPrefix,
    this.iconOf,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HesakPalette.current;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: palette.fieldFill, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final value in values)
            GestureDetector(
              key: Key('${keyPrefix}_${value is Enum ? value.name : value}'), // e.g. settings_voice_male
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: value == selected ? palette.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: value == selected
                      ? [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (iconOf != null) ...[
                      Icon(iconOf!(value), size: 15, color: value == selected ? palette.accent : palette.textSecondary),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      labelOf(value),
                      style: (value == selected ? HesakTextStyles.modeChipSelected : HesakTextStyles.modeChip)
                          .copyWith(color: value == selected ? palette.accent : palette.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pink note with an info icon (same idea as the note in إنشاء حساب).
class SettingsNote extends StatelessWidget {
  final String text;

  const SettingsNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    // Listens by itself, so it updates on فاتح / داكن even when created with const.
    return ListenableBuilder(
      listenable: HesakThemeController.instance,
      builder: (context, _) => _buildNote(),
    );
  }

  Widget _buildNote() {
    final palette = HesakPalette.current;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.noteFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.noteBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: palette.noteText),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: HesakTextStyles.infoBanner.copyWith(color: palette.noteText))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Fields
// ---------------------------------------------------------------------

/// Label + rounded field (+ red error under it).
/// Passwords are hidden with a lock button; emails and passwords are typed left-to-right.
class SettingsTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool isPassword;
  final bool isEmail;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;

  const SettingsTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.icon,
    this.isPassword = false,
    this.isEmail = false,
    this.errorText,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
  });

  @override
  State<SettingsTextField> createState() => _SettingsTextFieldState();
}

class _SettingsTextFieldState extends State<SettingsTextField> {
  late bool _isTextHidden = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    final palette = HesakPalette.current;
    final bool hasError = widget.errorText != null;

    Widget? endIcon;
    if (widget.isPassword) {
      endIcon = IconButton(
        onPressed: () => setState(() => _isTextHidden = !_isTextHidden),
        icon: Icon(_isTextHidden ? Icons.lock_outline_rounded : Icons.lock_open_rounded),
        color: palette.fieldHint,
        tooltip: _isTextHidden ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
      );
    } else if (widget.icon != null) {
      endIcon = Icon(widget.icon, color: palette.fieldHint);
    }

    OutlineInputBorder border(Color? color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(HesakSizes.radiusField),
          borderSide: color == null ? BorderSide.none : BorderSide(color: color, width: 1.2),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(widget.label, style: HesakTextStyles.fieldLabel.copyWith(color: palette.textPrimary)),
        ),
        TextField(
          controller: widget.controller,
          obscureText: _isTextHidden,
          onChanged: widget.onChanged,
          textInputAction: widget.textInputAction,
          keyboardType: widget.isEmail ? TextInputType.emailAddress : TextInputType.text,
          textDirection: widget.isPassword || widget.isEmail ? TextDirection.ltr : null,
          style: HesakTextStyles.fieldInput.copyWith(color: palette.textPrimary),
          cursorColor: palette.accent,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: HesakTextStyles.fieldHint.copyWith(color: palette.fieldHint),
            filled: true,
            fillColor: palette.fieldFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: endIcon,
            border: border(null),
            enabledBorder: border(hasError ? palette.danger : null),
            focusedBorder: border(hasError ? palette.danger : palette.accentSoftBorder),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 4, left: 4),
            child: Text(widget.errorText!, style: HesakTextStyles.fieldError.copyWith(color: palette.danger)),
          ),
      ],
    );
  }
}

/// The password rules (same as إنشاء حساب); each dot turns green when met.
class SettingsPasswordRules extends StatelessWidget {
  final String password;

  const SettingsPasswordRules({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final palette = HesakPalette.current;
    return Padding(
      padding: const EdgeInsets.only(top: 10, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final rule in AuthValidators.passwordRules(password))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: rule.isMet ? palette.success : Colors.transparent,
                      border: Border.all(color: rule.isMet ? palette.success : palette.iconInactive, width: 1.5),
                    ),
                    child: rule.isMet ? Icon(Icons.check_rounded, size: 10, color: palette.surface) : null,
                  ),
                  const SizedBox(width: 8),
                  Text(rule.label, style: HesakTextStyles.passwordRule.copyWith(color: palette.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// One-field bottom sheet (الاسم / الاسم للنداء)
// ---------------------------------------------------------------------

/// Bottom sheet with one name field + حفظ / إلغاء.
/// "حفظ" is faded until the text really changes AND is valid (Arabic letters only,
/// same rule as sign up). [onSave] does the saving; the sheet closes when it returns true.
Future<void> showSettingsNameSheet(
  BuildContext context, {
  required String title,
  required String? note,
  required String fieldLabel,
  required String hint,
  required String initialValue,
  required Future<bool> Function(String value) onSave,
}) {
  final palette = HesakPalette.current;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // Moves up with the keyboard
    useRootNavigator: true, // Above the bottom bar
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (_) => _SettingsNameSheet(
      title: title,
      note: note,
      fieldLabel: fieldLabel,
      hint: hint,
      initialValue: initialValue,
      onSave: onSave,
    ),
  );
}

class _SettingsNameSheet extends StatefulWidget {
  final String title;
  final String? note;
  final String fieldLabel;
  final String hint;
  final String initialValue;
  final Future<bool> Function(String value) onSave;

  const _SettingsNameSheet({
    required this.title,
    required this.note,
    required this.fieldLabel,
    required this.hint,
    required this.initialValue,
    required this.onSave,
  });

  @override
  State<_SettingsNameSheet> createState() => _SettingsNameSheetState();
}

class _SettingsNameSheetState extends State<_SettingsNameSheet> {
  late final _controller = TextEditingController(text: widget.initialValue);
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _text => _controller.text.trim();

  /// Red message while typing something wrong (not shown when empty).
  String? get _error => _text.isEmpty ? null : AuthValidators.nameProblem(_text);

  bool get _canSave => _text != widget.initialValue.trim() && AuthValidators.isValidName(_text) && !_isSaving;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final bool isDone = await widget.onSave(_text);
    if (!mounted) return;
    if (isDone) {
      Navigator.pop(context);
    } else {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = HesakPalette.current;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                  decoration: BoxDecoration(color: palette.accentSoftBorder, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 14),
              Text(widget.title, textAlign: TextAlign.center, style: HesakTextStyles.dialogTitle.copyWith(color: palette.textPrimary)),
              if (widget.note != null) ...[
                const SizedBox(height: 12),
                SettingsNote(widget.note!),
              ],
              SettingsTextField(
                key: const Key('settings_sheet_name_field'),
                label: widget.fieldLabel,
                controller: _controller,
                hint: widget.hint,
                errorText: _error,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SettingsButton(
                      key: const Key('settings_sheet_save_button'),
                      label: 'حفظ',
                      height: 44,
                      isLoading: _isSaving,
                      onTap: _canSave ? _save : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SettingsButton(
                      key: const Key('settings_sheet_cancel_button'),
                      label: 'إلغاء',
                      isFilled: false,
                      height: 44,
                      onTap: _isSaving ? null : () => Navigator.pop(context),
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
