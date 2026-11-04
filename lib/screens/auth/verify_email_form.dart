import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme/hesak_colors.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import '../../widgets/hesak_internet_required.dart';
import '../../widgets/hesak_toast.dart';
import 'auth_widgets.dart';
import 'new_password_screen.dart' show hesakNavigatorKey;

// =====================================================================
//  VERIFY EMAIL FORM (تأكيد البريد) — shown after sign up, and after a
//  login with an email that isn't verified yet.
//
//  The user opens the link in their email, then:
//   - on Android the link opens Hesak and AuthService verifies the email
//     by itself (emailLinkStatus) -> this step moves on automatically.
//   - taps "متابعة": we ask Firebase if the email is verified now.
//   - or just comes back to the app (e.g. the link opened in a browser):
//     we ask Firebase by ourselves.
//  Verified -> [onVerified]. Not yet -> a message, and they stay here.
//
//  The link can also open the app when this step is NOT on screen (closed
//  app, another phone...): startShowingEmailLinkResults() at the bottom
//  shows the result as a message instead.
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
  bool _isOpeningLink = false; // The link from the email is being checked
  bool _isSending = false; // A new link is being sent
  int _secondsLeft = 0; // > 0 = the resend link is locked
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _isVerifyEmailStepOpen = true;
    WidgetsBinding.instance.addObserver(this); // To know when the user comes back
    // The link from the email opened the app -> AuthService tells us here.
    AuthService.instance.emailLinkStatus.addListener(_onEmailLinkStatus);
    // A link was JUST sent (sign up / login), so the resend starts locked.
    _startResendWait(isFirst: true);
  }

  @override
  void dispose() {
    _isVerifyEmailStepOpen = false;
    WidgetsBinding.instance.removeObserver(this);
    AuthService.instance.emailLinkStatus.removeListener(_onEmailLinkStatus);
    _resendTimer?.cancel();
    super.dispose();
  }

  /// Back to the app (e.g. from the email app) -> check by ourselves, quietly.
  /// Skipped while a link is being checked (its result comes by itself).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isOpeningLink) {
      _checkVerified(isQuiet: true);
    }
  }

  /// The verification link opened the app (see AuthService.emailLinkStatus).
  void _onEmailLinkStatus() {
    final EmailLinkStatus status = AuthService.instance.emailLinkStatus.value;
    if (!mounted) return;
    switch (status) {
      case EmailLinkStatus.verifying:
        setState(() => _isOpeningLink = true); // "متابعة" shows the loader
        break;
      case EmailLinkStatus.verified:
      case EmailLinkStatus.failed:
        _finishEmailLink(status);
        break;
      case EmailLinkStatus.idle:
        break;
    }
  }

  /// Moves on if the link verified the email, or says the link expired.
  Future<void> _finishEmailLink(EmailLinkStatus status) async {
    AuthService.instance.clearEmailLinkStatus(); // Shown here, not app-wide
    // Wait for a quiet check that may still be running.
    while (_isChecking) {
      await Future.delayed(Duration(milliseconds: 100));
      if (!mounted) return;
    }
    setState(() => _isOpeningLink = false);

    final bool isVerified = await _checkVerified(isQuiet: true);
    if (!mounted || isVerified) return; // Verified -> already moved on
    if (status == EmailLinkStatus.failed) {
      showHesakToast(
        context,
        'الرابط منتهي أو استُخدم من قبل، اطلب رابطًا جديدًا',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  /// Asks Firebase if the email is verified (and loads the profile).
  /// [isQuiet] true = automatic check: no window and no message.
  /// Returns true when the email is verified.
  Future<bool> _checkVerified({bool isQuiet = false}) async {
    if (_isChecking) return false;
    if (!isQuiet && !await hesakRequireInternet(context)) return false; // No internet -> window
    if (!mounted) return false;

    setState(() => _isChecking = true);
    final bool isVerified = await AuthService.instance.restoreSession();
    if (!mounted) return isVerified;
    setState(() => _isChecking = false);

    if (isVerified) {
      showHesakToast(context, 'تم تأكيد بريدك الإلكتروني', icon: Icons.check_circle_rounded);
      widget.onVerified();
    } else if (!isQuiet) {
      showHesakToast(context, 'لم يتم تأكيد البريد بعد', icon: Icons.info_outline_rounded);
    }
    return isVerified;
  }

  /// Sends a new link, then locks the link for 60 seconds.
  Future<void> _resendLink() async {
    if (_secondsLeft > 0 || _isSending) return;
    if (!await hesakRequireInternet(context)) return; // No internet -> window
    if (!mounted) return;

    setState(() => _isSending = true);
    final result = await AuthService.instance.resendVerificationEmail();
    if (!mounted) return;
    setState(() => _isSending = false);

    if (result.isSuccess) {
      showHesakToast(context, 'تم إرسال الرابط مرة أخرى', icon: Icons.mark_email_read_outlined);
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
    _resendTimer = Timer.periodic(Duration(seconds: 1), (timer) {
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
        SizedBox(height: 28),

        // ---- Email icon + "تحقق من بريدك" ----
        Icon(Icons.mark_email_read_outlined, size: 64, color: HesakColors.primary),
        SizedBox(height: 16),
        Text(
          'تحقق من بريدك',
          textAlign: TextAlign.center,
          style: HesakTextStyles.fieldLabel.copyWith(color: HesakColors.textPrimary),
        ),
        SizedBox(height: 8),

        // ---- "أرسلنا رابط تأكيد إلى / email / افتح الرابط ثم عُد إلى هنا" ----
        Text.rich(
          TextSpan(
            style: HesakTextStyles.body.copyWith(color: HesakColors.textSecondary, fontSize: 13, height: 1.7),
            children: [
              TextSpan(text: 'أرسلنا رابط تأكيد إلى\n'),
              TextSpan(
                text: email,
                style: TextStyle(color: HesakColors.primary, fontWeight: FontWeight.w700),
              ),
              TextSpan(text: '\nافتح الرابط ثم عُد إلى هنا'),
            ],
          ),
          key: Key('verify_email_message'),
          textAlign: TextAlign.center,
        ),

        // ---- "متابعة" button ----
        SizedBox(height: 30),
        AuthPrimaryButton(
          key: Key('verify_email_continue_button'),
          label: 'متابعة',
          isLoading: _isChecking || _isOpeningLink,
          onPressed: _checkVerified,
        ),

        // ---- "إعادة إرسال الرابط" link (or the countdown) ----
        SizedBox(height: 8),
        _buildResendLink(),
      ],
    );
  }

  /// "ألم يصلك الرابط؟ إعادة إرسال الرابط" — or the 60 second countdown.
  Widget _buildResendLink() {
    final bool isLocked = _secondsLeft > 0;

    if (isLocked) {
      return Padding(
        key: Key('verify_email_resend_wait'),
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('ألم يصلك الرابط؟ ', style: HesakTextStyles.authHint),
            Icon(Icons.schedule_rounded, size: 15, color: HesakColors.iconInactive),
            SizedBox(width: 4),
            Text(
              'إعادة الإرسال بعد $_secondsLeft ث',
              style: HesakTextStyles.authLink.copyWith(color: HesakColors.iconInactive),
            ),
          ],
        ),
      );
    }

    return AuthFooterLink(
      key: Key('verify_email_resend_link'),
      question: 'ألم يصلك الرابط؟',
      linkText: 'إعادة إرسال الرابط',
      onTap: _resendLink,
    );
  }
}

// ---------------------------------------------------------------------------
// The verification link opened the app when "تأكيد البريد" is NOT on screen
// (closed app, signed out, another phone...). Shows the result as a message.
// ---------------------------------------------------------------------------

/// true while the "تأكيد البريد" step is on screen (it shows the result itself).
bool _isVerifyEmailStepOpen = false;

/// Call ONCE in main(), before AuthService.startListeningForLinks().
void startShowingEmailLinkResults() {
  final DateTime appStartedAt = DateTime.now();
  final AuthService auth = AuthService.instance;

  Future<void> showIfNeeded() async {
    final EmailLinkStatus status = auth.emailLinkStatus.value;
    if (status != EmailLinkStatus.verified && status != EmailLinkStatus.failed) return;
    if (_isVerifyEmailStepOpen) return; // The step handles it

    // If the link opened a closed app: let the splash finish first
    // (same wait as the new-password screen).
    const Duration splashTime = Duration(seconds: 6);
    final Duration waited = DateTime.now().difference(appStartedAt);
    if (waited < splashTime) await Future.delayed(splashTime - waited);

    // The step may have opened meanwhile (it then shows the result itself).
    if (_isVerifyEmailStepOpen || auth.emailLinkStatus.value != status) return;
    auth.clearEmailLinkStatus();

    final BuildContext? context = _contextInsideAppOverlay();
    if (context == null || !context.mounted) return;
    if (status == EmailLinkStatus.failed) {
      showHesakToast(
        context,
        'الرابط منتهي أو استُخدم من قبل، اطلب رابطًا جديدًا',
        icon: Icons.error_outline_rounded,
      );
    } else if (auth.isLoggedIn) {
      showHesakToast(context, 'تم تأكيد بريدك الإلكتروني', icon: Icons.check_circle_rounded);
    } else {
      showHesakToast(
        context,
        'تم تأكيد بريدك الإلكتروني، سجّل دخولك للمتابعة',
        icon: Icons.check_circle_rounded,
      );
    }
  }

  auth.emailLinkStatus.addListener(showIfNeeded);
}

/// A context INSIDE the app's top overlay, so showHesakToast can find it
/// from anywhere (the navigator's own context sits above its overlay).
BuildContext? _contextInsideAppOverlay() {
  final BuildContext? overlayContext = hesakNavigatorKey.currentState?.overlay?.context;
  if (overlayContext is! Element) return null;
  BuildContext? inside;
  overlayContext.visitChildElements((child) => inside ??= child);
  return inside;
}