import 'package:flutter/material.dart';
import '../core/theme/hesak_palette.dart';
import '../core/theme/hesak_sizes.dart';
import '../core/theme/hesak_text_styles.dart';

// =====================================================================
//  HESAK CONFIRM DIALOG — the ONE "are you sure?" window of the app.
//  Every page uses it, so they all look and read the same.
//
//  Shape (top to bottom):
//    icon
//    title  — black, a question:  "هل تريد حذف الفترة؟"
//    message — grey, the details: "الأحد – الخميس ..."
//    [confirm]  [إلغاء]
//
//  How to use:
//    final bool isConfirmed = await showHesakConfirmDialog(
//      context,
//      title: 'هل تريد حذف الفترة؟',
//      message: 'الأحد – الخميس\n11:00 م – 6:00 ص',
//      confirmLabel: 'حذف',
//      icon: Icons.delete_outline_rounded,
//    );
//
//  [followsAppearance]: true only on pages that follow فاتح / داكن
//  (الإعدادات for now). Other pages stay light.
// =====================================================================

/// Asks the user to confirm. Returns true when the user taps [confirmLabel].
Future<bool> showHesakConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required IconData icon,
  bool isDanger = true, // true = red icon + red confirm button
  bool followsAppearance = false,
}) async {
  final bool? result = await showHesakChoiceDialog(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    icon: icon,
    isDanger: isDanger,
    followsAppearance: followsAppearance,
  );
  return result ?? false;
}

/// Same window with ONE button only (e.g. "لا يوجد اتصال بالإنترنت" + "حسنًا").
/// Just tells the user something; nothing to choose.
Future<void> showHesakNoticeDialog(
  BuildContext context, {
  required String title,
  required String message,
  required IconData icon,
  String buttonLabel = 'حسنًا',
  bool followsAppearance = false,
}) async {
  await showHesakChoiceDialog(
    context,
    title: title,
    message: message,
    confirmLabel: buttonLabel,
    icon: icon,
    cancelLabel: null, // No second button
    isDanger: false,
    followsAppearance: followsAppearance,
  );
}

/// Same window, but the second button can have its own text and the
/// answer has 3 cases:
///   true  = [confirmLabel] tapped
///   false = [cancelLabel] tapped
///   null  = closed by tapping outside (nothing chosen)
/// Example: leaving a conversation — "حفظ" / "خروج دون حفظ" / tap outside = stay.
Future<bool?> showHesakChoiceDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required IconData icon,
  String? cancelLabel = 'إلغاء', // null = only the confirm button
  bool isDanger = true,
  bool followsAppearance = false,
}) async {
  final HesakPalette palette = followsAppearance ? HesakPalette.current : HesakPalette.light;
  final Color confirmColor = isDanger ? palette.danger : palette.accent;

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HesakSizes.radiusCard)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: confirmColor),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: HesakTextStyles.dialogTitle.copyWith(color: palette.textPrimary)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: HesakTextStyles.dialogBody.copyWith(color: palette.textSecondary)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _HesakDialogButton(
                    key: const Key('hesak_dialog_confirm_button'),
                    label: confirmLabel,
                    color: confirmColor,
                    textColor: isDanger ? palette.surface : palette.onAccent,
                    isFilled: true,
                    onTap: () => Navigator.pop(dialogContext, true),
                  ),
                ),
                if (cancelLabel != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _HesakDialogButton(
                    key: const Key('hesak_dialog_cancel_button'),
                    label: cancelLabel,
                    color: palette.accent,
                    textColor: palette.accent,
                    isFilled: false,
                    onTap: () => Navigator.pop(dialogContext, false),
                  ),
                ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Rounded button inside the dialog: filled (confirm) or outlined (إلغاء).
class _HesakDialogButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final bool isFilled;
  final VoidCallback onTap;

  const _HesakDialogButton({
    super.key,
    required this.label,
    required this.color,
    required this.textColor,
    required this.isFilled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double height = 42;
    final radius = BorderRadius.circular(height / 2);
    return Material(
      color: isFilled ? color : Colors.transparent,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HesakTextStyles.modeSmallButton.copyWith(color: textColor, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}