import 'package:flutter/material.dart';
import '../../core/theme/hesak_palette.dart';
import '../../core/theme/hesak_sizes.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import '../../widgets/hesak_page_header.dart';
import '../auth/auth_widgets.dart' show AuthValidators;
import 'settings_widgets.dart';
import '../../widgets/hesak_toast.dart';

// =====================================================================
//  CHANGE PASSWORD (تغيير كلمة المرور) — opened from الإعدادات.
//
//  Current password + new password (same rules as إنشاء حساب) + confirm.
//  The button works only when everything is filled correctly.
//  "نسيت كلمة المرور الحالية؟" sends a reset link to the user's email.
//
//  NAMING: everything here starts with "SettingsPassword". Keys: 'settings_password_<name>'.
// =====================================================================

class SettingsPasswordScreen extends StatefulWidget {
  const SettingsPasswordScreen({super.key});

  @override
  State<SettingsPasswordScreen> createState() => _SettingsPasswordScreenState();
}

class _SettingsPasswordScreenState extends State<SettingsPasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  String? _serverError; // e.g. "كلمة المرور الحالية غير صحيحة"

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ---- Checks (shown only after the user typed something) ----

  String? get _newError {
    final text = _newController.text;
    if (text.isEmpty) return null;
    if (text == _currentController.text) return 'كلمة المرور الجديدة يجب أن تختلف عن الحالية';
    return null;
  }

  String? get _confirmError {
    if (_confirmController.text.isEmpty) return null;
    if (_confirmController.text != _newController.text) return 'كلمتا المرور غير متطابقتين';
    return null;
  }

  /// The button works only when everything is correct.
  bool get _canSubmit =>
      _currentController.text.isNotEmpty &&
      AuthValidators.isStrongPassword(_newController.text) &&
      _newError == null &&
      _confirmController.text == _newController.text &&
      !_isLoading;

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _serverError = null;
    });
    final result = await AuthService.instance.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      showHesakToast(context, 'تم تغيير كلمة المرور');
      Navigator.pop(context);
    } else {
      setState(() => _serverError = result.errorMessage);
    }
  }

  /// "نسيت كلمة المرور الحالية؟" -> reset link to the account email.
  Future<void> _sendResetLink() async {
    final email = AuthService.instance.currentEmail;
    if (email == null) {
      showHesakToast(context, 'لا يوجد بريد إلكتروني مسجّل', icon: Icons.error_outline_rounded);
      return;
    }
    await AuthService.instance.sendPasswordResetEmail(email: email);
    if (!mounted) return;
    showHesakToast(context, 'تم إرسال رابط الاستعادة إلى بريدك', icon: Icons.mark_email_read_outlined);
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
                  title: 'تغيير كلمة المرور',
                  onBack: () => Navigator.pop(context),
                  followsAppearance: true,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                        HesakSizes.pagePadding, 0, HesakSizes.pagePadding, HesakSizes.pageBottomSafeSpace),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SettingsTextField(
                          key: const Key('settings_password_current_field'),
                          label: 'كلمة المرور الحالية:',
                          controller: _currentController,
                          hint: '••••••••',
                          isPassword: true,
                          onChanged: (_) => setState(() => _serverError = null),
                        ),
                        SettingsTextField(
                          key: const Key('settings_password_new_field'),
                          label: 'كلمة المرور الجديدة:',
                          controller: _newController,
                          hint: '••••••••',
                          isPassword: true,
                          errorText: _newError,
                          onChanged: (_) => setState(() {}), // Updates the rule dots
                        ),
                        SettingsPasswordRules(password: _newController.text),
                        SettingsTextField(
                          key: const Key('settings_password_confirm_field'),
                          label: 'تأكيد كلمة المرور الجديدة:',
                          controller: _confirmController,
                          hint: '••••••••',
                          isPassword: true,
                          errorText: _confirmError,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                        ),

                        const SizedBox(height: 24),
                        if (_serverError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              _serverError!,
                              textAlign: TextAlign.center,
                              style: HesakTextStyles.fieldError.copyWith(color: palette.danger),
                            ),
                          ),
                        SettingsButton(
                          key: const Key('settings_password_submit_button'),
                          label: 'تغيير كلمة المرور',
                          isLoading: _isLoading,
                          onTap: _canSubmit ? _submit : null,
                        ),

                        // Forgot the current password?
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton(
                            key: const Key('settings_password_forgot_button'),
                            onPressed: _sendResetLink,
                            child: Text.rich(
                              TextSpan(
                                text: 'نسيت كلمة المرور الحالية؟ ',
                                style: HesakTextStyles.authHint.copyWith(color: palette.textSecondary),
                                children: [
                                  TextSpan(
                                    text: 'إرسال رابط الاستعادة',
                                    style: HesakTextStyles.authLink.copyWith(color: palette.accent),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
}
