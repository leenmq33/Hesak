import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme/hesak_colors.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import '../../widgets/hesak_internet_required.dart';
import '../../widgets/hesak_toast.dart';
import 'auth_widgets.dart';

// =====================================================================
//  VERIFY EMAIL FORM (تأكيد البريد) — shown after sign up, and after a
//  login with an email that isn't verified yet.
//
//  The user opens the link in their email (outside the app), then:
//   - taps "متابعة": we ask Firebase if the email is verified now.
//   - or just comes back to the app: we ask Firebase by ourselves.
//  Verified -> [onVerified]. Not yet -> a message, and they stay here.
//
//  "إعادة إرسال الرابط" starts LOCKED (a link was just sent) and counts down
//  60 seconds. After each new email it waits 60 seconds again. Firebase
//  refuses emails sent too close together ("too many requests"), and about a
//  minute between two emails is what it accepts, so that message stays rare.
//
//  Same look as the "تحقق من بريدك الجديد" step in الإعدادات > البريد.
//
//  NAMING: everything here starts with "VerifyEmail". Keys: 'verify_email_<name>'.
// =====================================================================

/// The "check your email" step. No skip: the email must be verified first.
/// The back arrow signs out and returns to the welcome screen (e.g. the email
/// was typed wrong) — it never opens the app.
class VerifyEmailForm extends StatefulWidget {
  final VoidCallback onVerified; // Email verified -> next step
  final VoidCallback onBack; // Back arrow -> sign out + welcome

  const VerifyEmailForm({super.key, required this.onVerified, required this.onBack});

  @override
  State<VerifyEmailForm> createState() => _VerifyEmailFormState();
}

class _VerifyEmailFormState extends State<VerifyEmailForm> with WidgetsBindingObserver {
  /// Seconds to wait between two emails (also right after the first one).
  static const int _resendWaitSeconds = 60;

  bool _isChecking = false; // "متابعة" is asking Firebase
  bool _isSending = false; // A new link is being sent
  int _secondsLeft = 0; // > 0 = the resend link is locked
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // To know when the user comes back
    // A link was JUST sent (sign up / login), so the resend starts locked.
    _startResendWait(isFirst: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resendTimer?.cancel();
    super.dispose();
  }

  /// Back to the app (e.g. from the email app) -> check by ourselves, quietly.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkVerified(isQuiet: true);
  }

  /// Asks Firebase if the email is verified (and loads the profile).
  /// [isQuiet] true = automatic check: no window and no message.
  Future<void> _checkVerified({bool isQuiet = false}) async {
    if (_isChecking) return;
    if (!isQuiet && !await hesakRequireInternet(context)) return; // No internet -> window
    if (!mounted) return;

    setState(() => _isChecking = true);
    final bool isVerified = await AuthService.instance.restoreSession();
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (isVerified) {
      widget.onVerified();
    } else if (!isQuiet) {
      showHesakToast(context, 'لم يتم تأكيد البريد بعد', icon: Icons.info_outline_rounded);
    }
  }

  /// Sends a new link, then locks the link for 30 seconds.
  Future<void> _resendLink() async {
    if (_secondsLeft > 0 || _isSending) return;
    if (!await hesakRequireInternet(context)) return; // No internet -> window
    if (!mounted) return;

    setState(() => _isSending = true);
    final result = await AuthService.instance.resendVerificationEmail();
    if (!mounted) return;
    setState(() => _isSending = false);

    if (result.isSuccess) {
      showHesakToast(context, 'تم إرسال الرابط مرة ثانية', icon: Icons.mark_email_read_outlined);
    } else {
      showHesakToast(context, result.errorMessage ?? 'حدث خطأ، حاول مرة أخرى', icon: Icons.error_outline_rounded);
    }
    _startResendWait(); // Wait again either way (a refused try also counts for Firebase)
  }

  /// Counts down 60 -> 0, one second at a time.
  /// [isFirst] = called from initState (the screen isn't built yet: no setState).
  void _startResendWait({bool isFirst = false}) {
    _resendTimer?.cancel();
    if (isFirst) {
      _secondsLeft = _resendWaitSeconds;
    } else {
      setState(() => _secondsLeft = _resendWaitSeconds);
    }
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final String email = AuthService.instance.currentEmail ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthSheetHeader(title: 'تأكيد البريد', onBack: widget.onBack),
        const SizedBox(height: 28),

        const Icon(Icons.mark_email_read_outlined, size: 64, color: HesakColors.primary),
        const SizedBox(height: 16),
        Text(
          'تحقق من بريدك',
          textAlign: TextAlign.center,
          style: HesakTextStyles.fieldLabel.copyWith(color: HesakColors.textPrimary),
        ),
        const SizedBox(height: 8),

        // "أرسلنا رابط تأكيد إلى / email / افتح الرابط وبعدها ارجع هنا"
        Text.rich(
          TextSpan(
            style: HesakTextStyles.body.copyWith(color: HesakColors.textSecondary, fontSize: 13, height: 1.7),
            children: [
              const TextSpan(text: 'أرسلنا رابط تأكيد إلى\n'),
              TextSpan(
                text: email,
                style: const TextStyle(color: HesakColors.primary, fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: '\nافتح الرابط وبعدها ارجع هنا'),
            ],
          ),
          key: const Key('verify_email_message'),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 30),
        AuthPrimaryButton(
          key: const Key('verify_email_continue_button'),
          label: 'متابعة',
          isLoading: _isChecking,
          onPressed: _checkVerified,
        ),

        const SizedBox(height: 8),
        _buildResendLink(),
      ],
    );
  }

  /// "ما وصلك الرابط؟ إعادة إرسال الرابط" — or the 60 second countdown.
  Widget _buildResendLink() {
    final bool isLocked = _secondsLeft > 0;

    if (isLocked) {
      return Padding(
        key: const Key('verify_email_resend_wait'),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('ما وصلك الرابط؟ ', style: HesakTextStyles.authHint),
            const Icon(Icons.schedule_rounded, size: 15, color: HesakColors.iconInactive),
            const SizedBox(width: 4),
            Text(
              'إعادة الإرسال بعد $_secondsLeft ث',
              style: HesakTextStyles.authLink.copyWith(color: HesakColors.iconInactive),
            ),
          ],
        ),
      );
    }

    return AuthFooterLink(
      key: const Key('verify_email_resend_link'),
      question: 'ما وصلك الرابط؟',
      linkText: 'إعادة إرسال الرابط',
      onTap: _resendLink,
    );
  }
}
