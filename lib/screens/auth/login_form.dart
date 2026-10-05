import 'package:flutter/material.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import 'auth_widgets.dart';

// =====================================================================
//  LOGIN FORM (تسجيل الدخول) — shown inside the white sheet of
//  HesakAuthFlowScreen. Only the form; the purple top + logo come from
//  the flow screen.
//
//  NAMING: everything here starts with "Login". Keys: 'login_<name>'.
// =====================================================================

/// Email + password, "forgot password" link, and a link to sign up.
class LoginForm extends StatefulWidget {
  final VoidCallback onLoggedIn; // Login worked -> open the app
  final VoidCallback onEmailNotVerified; // Right password, email not verified -> تأكيد البريد
  final VoidCallback onForgotPassword; // "هل نسيت كلمة المرور؟"
  final VoidCallback onGoToSignUp; // "إنشاء حساب"
  final VoidCallback onBack; // Back arrow -> welcome (the 2 buttons)

  const LoginForm({
    super.key,
    required this.onLoggedIn,
    required this.onEmailNotVerified,
    required this.onForgotPassword,
    required this.onGoToSignUp,
    required this.onBack,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Errors only show after the first tap on the button (not while typing the first time).
  bool _hasTriedSubmit = false;
  bool _isLoading = false;
  String? _serverError; // Message from AuthService (e.g. wrong password)

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---- Field errors (null = OK) ----

  String? get _emailError {
    if (!_hasTriedSubmit) return null;
    if (_emailController.text.trim().isEmpty) return 'أدخل البريد الإلكتروني';
    if (!AuthValidators.isValidEmail(_emailController.text)) return 'البريد الإلكتروني غير صحيح';
    return null;
  }

  String? get _passwordError {
    if (!_hasTriedSubmit) return null;
    if (_passwordController.text.isEmpty) return 'أدخل كلمة المرور';
    return null;
  }

  /// Button tapped: check the fields, then ask AuthService to log in.
  Future<void> _submitLogin() async {
    setState(() {
      _hasTriedSubmit = true;
      _serverError = null;
    });
    if (_emailError != null || _passwordError != null) return; // Fix the fields first

    setState(() => _isLoading = true);
    final result = await AuthService.instance.logIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      widget.onLoggedIn();
    } else if (result.needsEmailVerification) {
      widget.onEmailNotVerified(); // A new link was sent; the verify step waits for it
    } else {
      setState(() => _serverError = result.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthSheetHeader(title: 'تسجيل الدخول', onBack: widget.onBack),
        SizedBox(height: 12),

        // ---- Email ----
        AuthFieldLabel('البريد الإلكتروني:'),
        AuthTextField(
          key: Key('login_email_field'),
          controller: _emailController,
          hint: 'example@email.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          onChanged: (_) => setState(() {}), // Refresh the error while fixing it
        ),

        // ---- Password ----
        AuthFieldLabel('كلمة المرور:'),
        AuthTextField(
          key: Key('login_password_field'),
          controller: _passwordController,
          hint: '••••••••',
          isPassword: true,
          textInputAction: TextInputAction.done,
          errorText: _passwordError,
          onChanged: (_) => setState(() {}),
        ),

        // "هل نسيت كلمة المرور؟" under the password, on the left (end) side.
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            key: Key('login_forgot_password_button'),
            onPressed: widget.onForgotPassword,
            // Same purple as "إنشاء حساب", but not bold.
            child: Text(
              'هل نسيت كلمة المرور؟',
              style: HesakTextStyles.authLink.copyWith(fontWeight: FontWeight.w400),
            ),
          ),
        ),

        SizedBox(height: 28),

        // Error from the server (e.g. wrong password), above the button.
        if (_serverError != null)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(_serverError!, textAlign: TextAlign.center, style: HesakTextStyles.fieldError),
          ),

        AuthPrimaryButton(
          key: Key('login_submit_button'),
          label: 'تسجيل الدخول',
          isLoading: _isLoading,
          onPressed: _submitLogin,
        ),

        SizedBox(height: 16),
        AuthFooterLink(
          key: Key('login_go_to_signup_link'),
          question: 'ليس لديك حساب؟',
          linkText: 'إنشاء حساب',
          onTap: widget.onGoToSignUp,
        ),
      ],
    );
  }
}
