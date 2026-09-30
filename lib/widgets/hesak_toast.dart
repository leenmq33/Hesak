import 'package:flutter/material.dart';
import '../core/theme/hesak_colors.dart';
import '../core/theme/hesak_sizes.dart';
import '../core/theme/hesak_text_styles.dart';

// =====================================================================
//  HESAK TOAST — the small dark message near the bottom of the screen
//  (e.g. "تم حفظ التعديلات"). Shared by EVERY page, so they all look the same.
//
//  How to use:
//    showHesakToast(context, 'تم حذف الفترة', icon: Icons.delete_outline_rounded);
//
//  Drawn on top of everything (not a SnackBar), so it sits just above the
//  bottom bar instead of floating in the middle of the page.
//  Only one message is shown at a time (a new one replaces the old one).
// =====================================================================

OverlayEntry? _hesakCurrentToast;

/// Shows [message] for 2 seconds, just above the bottom bar.
void showHesakToast(BuildContext context, String message, {IconData icon = Icons.check_circle_rounded}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  // Read from the root overlay: a page inside a tab sees the bottom bar's height here instead.
  final double bottomInset = MediaQuery.of(overlay.context).padding.bottom;

  // Only one message at a time.
  _hesakCurrentToast?.remove();
  _hesakCurrentToast = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: 16,
      right: 16,
      bottom: 110 + bottomInset, // Just above the bottom bar
      child: IgnorePointer(
        child: _HesakToastView(
          message: message,
          icon: icon,
          onFinished: () {
            if (_hesakCurrentToast == entry) {
              entry.remove();
              _hesakCurrentToast = null;
            }
          },
        ),
      ),
    ),
  );
  _hesakCurrentToast = entry;
  overlay.insert(entry);
}

/// The message box: fades in, waits 2 seconds, fades out, then asks to be removed.
class _HesakToastView extends StatefulWidget {
  final String message;
  final IconData icon;
  final VoidCallback onFinished;

  const _HesakToastView({required this.message, required this.icon, required this.onFinished});

  @override
  State<_HesakToastView> createState() => _HesakToastViewState();
}

class _HesakToastViewState extends State<_HesakToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await _fadeController.forward();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await _fadeController.reverse();
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeController,
      child: Material(
        color: HesakColors.toastBackground,
        borderRadius: BorderRadius.circular(HesakSizes.radiusInnerCard),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              children: [
                Icon(widget.icon, color: HesakColors.onPrimary, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.message, style: HesakTextStyles.toast)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
