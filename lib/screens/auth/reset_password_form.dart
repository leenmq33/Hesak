import 'package:flutter/material.dart';
import '../../core/theme/hesak_colors.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import 'auth_widgets.dart';

// =====================================================================
//  RESET PASSWORD FORM (استعادة كلمة المرور) — shown inside the white
//  sheet of HesakAuthFlowScreen. Opened from "هل نسيت كلمة المرور؟".
//
//  The real flow (how Firebase and most apps do it):
//   1) The user types their email here.
//   2) We send them an email with a secure link.
//   3) The link opens Hesak on the new-password screen
//      (new_password_screen.dart), where they choose the new password.
//   4) They log in with the new password.
//  The app never sets the password directly — only the owner of the
//  email can, which keeps accounts safe.
//
//  NAMING: everything here starts with "ResetPassword".
//  Keys: 'reset_password_<name>'.
// =====================================================================

/// Step 1: email field + "إرسال رابط الاستعادة".
/// Step 2: "check your email" message + back to login.
class ResetPasswordForm extends StatefulWidget {
  final VoidCallback onBack; // Back arrow / "العودة لتسجيل الدخول" -> login

  const ResetPasswordForm({super.key, required this.onBack});

  @override
  State<ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends State<ResetPasswordForm> {
  final _emailController = TextEditingController();

  bool _hasTriedSubmit = false;
  bool _isLoading = false;
  bool _isEmailSent = false; // true -> show the "check your email" step
  String? _serverError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Empty or wrong-looking email.
  String? get _emailError {
    if (!_hasTriedSubmit) return null;
    if (_emailController.text.trim().isEmpty) return 'أدخل البريد الإلكتروني';
    if (!AuthValidators.isValidEmail(_emailController.text)) return 'البريد الإلكتروني غير صحيح';
    return null;
  }

  /// "إرسال رابط الاستعادة" tapped: check the email, then ask AuthService to send the link.
  Future<void> _sendResetLink() async {
    setState(() {
      _hasTriedSubmit = true;
      _serverError = null;
    });
    if (_emailError != null) return;

    setState(() => _isLoading = true);
    final result = await AuthService.instance.sendPasswordResetEmail(
      email: _emailController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      setState(() => _isEmailSent = true);
    } else {
      setState(() => _serverError = result.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthSheetHeader(title: 'استعادة كلمة المرور', onBack: widget.onBack),
        SizedBox(height: 8),

        // Soft switch between step 1 (enter email) and step 2 (check your email).
        AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: _isEmailSent ? _buildEmailSentStep() : _buildEnterEmailStep(),
        ),
      ],
    );
  }

  /// Step 1: type the email.
  Widget _buildEnterEmailStep() {
    return Column(
      key: ValueKey('reset_password_enter_email_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 8),
        // ---- Pink note ----
        AuthInfoBanner('أدخل بريدك الإلكتروني المسجّل، وسنرسل لك رابطًا لإنشاء كلمة مرور جديدة'),

        // ---- "البريد الإلكتروني:" field ----
        AuthFieldLabel('البريد الإلكتروني:'),
        AuthTextField(
          key: Key('reset_password_email_field'),
          controller: _emailController,
          hint: 'example@email.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          errorText: _emailError,
          onChanged: (_) => setState(() {}),
        ),

        SizedBox(height: 40),

        // ---- Server error, above the button ----
        if (_serverError != null)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(_serverError!, textAlign: TextAlign.center, style: HesakTextStyles.fieldError),
          ),

        // ---- "إرسال رابط الاستعادة" button ----
        AuthPrimaryButton(
          key: Key('reset_password_send_button'),
          label: 'إرسال رابط الاستعادة',
          isLoading: _isLoading,
          onPressed: _sendResetLink,
        ),
      ],
    );
  }

  /// Step 2: the email was sent.
  Widget _buildEmailSentStep() {
    return Column(
      key: ValueKey('reset_password_email_sent_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Email icon + "تحقق من بريدك الإلكتروني" + the message ----
        SizedBox(height: 24),
        Icon(Icons.mark_email_read_outlined, size: 64, color: HesakColors.primaryMuted),
        SizedBox(height: 16),
        Text(
          'تحقق من بريدك الإلكتروني',
          textAlign: TextAlign.center,
          style: HesakTextStyles.fieldLabel,
        ),
        SizedBox(height: 8),
        Text(
          'أرسلنا رابط استعادة كلمة المرور إلى\n${_emailController.text.trim()}\n'
          'افتح الرابط واختر كلمة مرور جديدة، ثم عُد لتسجيل الدخول',
          textAlign: TextAlign.center,
          style: HesakTextStyles.body.copyWith(fontSize: 13, height: 1.6),
        ),

        // ---- "العودة لتسجيل الدخول" button ----
        SizedBox(height: 40),
        AuthPrimaryButton(
          key: Key('reset_password_back_to_login_button'),
          label: 'العودة لتسجيل الدخول',
          onPressed: widget.onBack,
        ),

        // ---- "لم يصلك البريد؟ إعادة الإرسال": back to step 1 to send again ----
        SizedBox(height: 8),
        AuthFooterLink(
          key: Key('reset_password_resend_link'),
          question: 'لم يصلك البريد؟',
          linkText: 'إعادة الإرسال',
          onTap: () => setState(() => _isEmailSent = false),
        ),
      ],
    );
  }
}
