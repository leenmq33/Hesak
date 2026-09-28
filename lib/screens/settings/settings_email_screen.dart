import 'package:flutter/material.dart';
import '../../core/theme/hesak_palette.dart';
import '../../core/theme/hesak_sizes.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import '../../widgets/hesak_page_header.dart';
import '../auth/auth_widgets.dart' show AuthValidators;
import 'settings_widgets.dart';

// =====================================================================
//  CHANGE EMAIL (تغيير البريد الإلكتروني) — opened from الإعدادات.
//
//  Safe flow (like Firebase): the user types the NEW email + the current
//  password -> we send a confirmation link to the NEW email -> the email
//  only changes after the user opens that link.
//  (For now the sending is fake — see AuthService.requestEmailChange.)
//
//  Step 1: form.  Step 2: "تحقق من بريدك الجديد".
//
//  NAMING: everything here starts with "SettingsEmail". Keys: 'settings_email_<name>'.
// =====================================================================

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

  String? get _emailError {
    if (_newEmail.isEmpty) return null;
    if (!AuthValidators.isValidEmail(_newEmail)) return 'البريد الإلكتروني غير صحيح';
    if (_newEmail.toLowerCase() == (AuthService.instance.currentEmail ?? '').toLowerCase()) {
      return 'هذا هو بريدك الحالي';
    }
    return null;
  }

  bool get _canSubmit =>
      _newEmail.isNotEmpty && _emailError == null && _passwordController.text.isNotEmpty && !_isLoading;

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
                    padding: const EdgeInsets.fromLTRB(
                        HesakSizes.pagePadding, 0, HesakSizes.pagePadding, HesakSizes.pageBottomSafeSpace),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
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
      key: const ValueKey('settings_email_form_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const SettingsNote('سنرسل رابط تأكيد إلى بريدك الجديد، ولن يتغيّر البريد إلا بعد فتح الرابط.'),

        // Current email (read only).
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text('البريد الحالي:', style: HesakTextStyles.fieldLabel.copyWith(color: palette.textPrimary)),
        ),
        Text(
          AuthService.instance.currentEmail ?? 'غير محدد',
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          style: HesakTextStyles.body.copyWith(color: palette.textSecondary, fontSize: 14),
        ),

        SettingsTextField(
          key: const Key('settings_email_new_field'),
          label: 'البريد الجديد:',
          controller: _emailController,
          hint: 'example@email.com',
          icon: Icons.mail_outline_rounded,
          isEmail: true,
          errorText: _emailError,
          onChanged: (_) => setState(() => _serverError = null),
        ),
        SettingsTextField(
          key: const Key('settings_email_password_field'),
          label: 'كلمة المرور الحالية:',
          controller: _passwordController,
          hint: '••••••••',
          isPassword: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _serverError = null),
        ),

        const SizedBox(height: 24),
        if (_serverError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_serverError!, textAlign: TextAlign.center, style: HesakTextStyles.fieldError.copyWith(color: palette.danger)),
          ),
        SettingsButton(
          key: const Key('settings_email_submit_button'),
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
      key: const ValueKey('settings_email_sent_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Icon(Icons.mark_email_read_outlined, size: 64, color: palette.accent),
        const SizedBox(height: 16),
        Text('تحقق من بريدك الجديد', textAlign: TextAlign.center, style: HesakTextStyles.fieldLabel.copyWith(color: palette.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'أرسلنا رابط تأكيد إلى\n$_newEmail\nافتح الرابط لتأكيد بريدك الجديد، وبعدها يتغيّر في حسابك.',
          textAlign: TextAlign.center,
          style: HesakTextStyles.body.copyWith(color: palette.textSecondary, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 32),
        SettingsButton(
          key: const Key('settings_email_done_button'),
          label: 'تم',
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
