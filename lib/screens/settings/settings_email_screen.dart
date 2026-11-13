import 'package:flutter/material.dart';
import '../../core/theme/hesak_palette.dart';
import '../../core/theme/hesak_sizes.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import '../../widgets/hesak_page_header.dart';
import '../../widgets/hesak_toast.dart';
import '../auth/auth_widgets.dart' show AuthValidators;
import 'settings_widgets.dart';

// =====================================================================
//  CHANGE EMAIL ("البريد الإلكتروني") — opened from الإعدادات.
//
//  Safe flow (like Firebase): the user types the NEW email + the current
//  password -> we send a confirmation link to the NEW email -> the email
//  only changes after the user opens that link.
//  Sent by Firebase (AuthService.requestEmailChange). Needs internet.
//
//  Step 1: form.  Step 2: "تحقق من بريدك الجديد".
//  "هل نسيت كلمة المرور؟" under the password (same as تسجيل الدخول) sends
//  a reset link to the CURRENT email.
//
//  NAMING: everything here starts with "SettingsEmail". Keys: 'settings_email_<name>'.
// =====================================================================

/// The change-email page (form, then "تحقق من بريدك الجديد").
class SettingsEmailScreen extends StatefulWidget {
  const SettingsEmailScreen({super.key});

  @override
  State<SettingsEmailScreen> createState() => _SettingsEmailScreenState();
}

class _SettingsEmailScreenState extends State<SettingsEmailScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isSent = false; // true -> show step 2
  String? _serverError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _newEmail => _emailController.text.trim();

  /// Wrong-looking email, or the same as the current one.
  String? get _emailError {
    if (_newEmail.isEmpty) return null;
    if (!AuthValidators.isValidEmail(_newEmail)) return 'البريد الإلكتروني غير صحيح';
    if (_newEmail.toLowerCase() == (AuthService.instance.currentEmail ?? '').toLowerCase()) {
      return 'هذا هو بريدك الحالي';
    }
    return null;
  }

  /// The button works only when both fields are filled correctly.
  bool get _canSubmit =>
      _newEmail.isNotEmpty && _emailError == null && _passwordController.text.isNotEmpty && !_isLoading;

  /// "هل نسيت كلمة المرور؟" -> reset link to the account's current email.
  Future<void> _sendResetLink() async {
    final email = AuthService.instance.currentEmail;
    if (email == null) {
      showHesakToast(context, 'لا يوجد بريد إلكتروني مسجّل', icon: Icons.error_outline_rounded);
      return;
    }
    final result = await AuthService.instance.sendPasswordResetEmail(email: email);
    if (!mounted) return;
    if (result.isSuccess) {
      showHesakToast(context, 'تم إرسال رابط الاستعادة إلى بريدك', icon: Icons.mark_email_read_outlined);
    } else {
      showHesakToast(context, result.errorMessage ?? 'حدث خطأ، حاول مرة أخرى', icon: Icons.error_outline_rounded);
    }
  }

  /// "إرسال رابط التأكيد": sends the link, then shows step 2.
  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _serverError = null;
    });
    final result = await AuthService.instance.requestEmailChange(
      newEmail: _newEmail,
      currentPassword: _passwordController.text,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _isSent = true;
      } else {
        _serverError = result.errorMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HesakThemeController.instance,
      builder: (context, _) {
        final palette = HesakPalette.current;
        return Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            bottom: false, // The bottom bar covers the bottom edge
            child: Column(
              children: [
                HesakPageHeader(
                  title: 'البريد الإلكتروني',
                  onBack: () => Navigator.pop(context),
                  followsAppearance: true,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        HesakSizes.pagePadding, 0, HesakSizes.pagePadding, HesakSizes.pageBottomSafeSpace),
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 250),
                      child: _isSent ? _buildSentStep(palette) : _buildFormStep(palette),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Step 1: current email, new email, current password.
  Widget _buildFormStep(HesakPalette palette) {
    return Column(
      key: ValueKey('settings_email_form_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Note ----
        SizedBox(height: 8),
        SettingsNote('سنرسل رابط تأكيد إلى بريدك الجديد، ولن يتغيّر البريد إلا بعد فتح الرابط'),

        // ---- "البريد الحالي:" (read only) ----
        Padding(
          padding: EdgeInsets.only(top: 16, bottom: 8),
          child: Text('البريد الحالي:', style: HesakTextStyles.fieldLabel.copyWith(color: palette.textPrimary)),
        ),
        Text(
          AuthService.instance.currentEmail ?? 'غير محدد',
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          style: HesakTextStyles.body.copyWith(color: palette.textSecondary, fontSize: 14),
        ),

        // ---- "البريد الجديد:" + "كلمة المرور الحالية:" fields ----
        SettingsTextField(
          key: Key('settings_email_new_field'),
          label: 'البريد الجديد:',
          controller: _emailController,
          hint: 'example@email.com',
          icon: Icons.mail_outline_rounded,
          isEmail: true,
          errorText: _emailError,
          onChanged: (_) => setState(() => _serverError = null),
        ),
        SettingsTextField(
          key: Key('settings_email_password_field'),
          label: 'كلمة المرور الحالية:',
          controller: _passwordController,
          hint: '••••••••',
          isPassword: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _serverError = null),
        ),

        // ---- "هل نسيت كلمة المرور؟" (under the password, left side) ----
        // Same look and place as on تسجيل الدخول.
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            key: Key('settings_email_forgot_password_button'),
            onPressed: _sendResetLink,
            child: Text(
              'هل نسيت كلمة المرور؟',
              style: HesakTextStyles.authLink.copyWith(fontWeight: FontWeight.w400, color: palette.title),
            ),
          ),
        ),

        // ---- Server error + "إرسال رابط التأكيد" button ----
        SizedBox(height: 12),
        if (_serverError != null)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(_serverError!, textAlign: TextAlign.center, style: HesakTextStyles.fieldError.copyWith(color: palette.danger)),
          ),
        SettingsButton(
          key: Key('settings_email_submit_button'),
          label: 'إرسال رابط التأكيد',
          isLoading: _isLoading,
          onTap: _canSubmit ? _submit : null,
        ),
      ],
    );
  }

  /// Step 2: the link was sent.
  Widget _buildSentStep(HesakPalette palette) {
    return Column(
      key: ValueKey('settings_email_sent_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 32),
        Icon(Icons.mark_email_read_outlined, size: 64, color: palette.accent),
        SizedBox(height: 16),
        Text('تحقق من بريدك الجديد', textAlign: TextAlign.center, style: HesakTextStyles.fieldLabel.copyWith(color: palette.textPrimary)),
        SizedBox(height: 8),
        Text(
          'أرسلنا رابط تأكيد إلى\n$_newEmail\nافتح الرابط لتأكيد بريدك الجديد، وبعد ذلك سيُحدَّث في حسابك',
          textAlign: TextAlign.center,
          style: HesakTextStyles.body.copyWith(color: palette.textSecondary, fontSize: 13, height: 1.6),
        ),
        SizedBox(height: 32),
        SettingsButton(
          key: Key('settings_email_done_button'),
          label: 'تم',
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
