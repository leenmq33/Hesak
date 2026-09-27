import 'package:flutter/material.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import 'auth_widgets.dart';

// =====================================================================
//  SIGN UP FORM (إنشاء حساب) — shown inside the white sheet of
//  HesakAuthFlowScreen.
//
//  NAMING: everything here starts with "SignUp". Keys: 'signup_<name>'.
// =====================================================================

/// Name, email, reading voice, password (+ rules), confirm password, terms.
class SignUpForm extends StatefulWidget {
  final VoidCallback onSignedUp; // Account created -> next step (call name)
  final VoidCallback onGoToLogin; // "لديك حساب؟ تسجيل دخول"
  final VoidCallback onBack; // Back arrow -> welcome (the 2 buttons)

  const SignUpForm({
    super.key,
    required this.onSignedUp,
    required this.onGoToLogin,
    required this.onBack,
  });

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  HesakVoice _selectedVoice = HesakVoice.male;
  bool _hasAcceptedTerms = false;

  // Errors only show after the first tap on the button.
  bool _hasTriedSubmit = false;
  bool _isLoading = false;
  String? _serverError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ---- Field errors (null = OK) ----

  String? get _nameError {
    if (!_hasTriedSubmit) return null;
    return AuthValidators.nameProblem(_nameController.text);
  }

  String? get _emailError {
    if (!_hasTriedSubmit) return null;
    if (_emailController.text.trim().isEmpty) return 'أدخل البريد الإلكتروني';
    if (!AuthValidators.isValidEmail(_emailController.text)) return 'البريد الإلكتروني غير صحيح';
    return null;
  }

  String? get _passwordError {
    if (!_hasTriedSubmit) return null;
    if (!AuthValidators.isStrongPassword(_passwordController.text)) {
      return 'كلمة المرور لا تحقق كل الشروط';
    }
    return null;
  }

  String? get _confirmPasswordError {
    if (!_hasTriedSubmit) return null;
    if (_confirmPasswordController.text != _passwordController.text) return 'كلمتا المرور غير متطابقتين';
    return null;
  }

  String? get _termsError {
    if (!_hasTriedSubmit) return null;
    if (!_hasAcceptedTerms) return 'يجب الموافقة على الشروط والأحكام';
    return null;
  }

  bool get _hasAnyError =>
      _nameError != null ||
      _emailError != null ||
      _passwordError != null ||
      _confirmPasswordError != null ||
      _termsError != null;

  /// Button tapped: check everything, then ask AuthService to create the account.
  Future<void> _submitSignUp() async {
    setState(() {
      _hasTriedSubmit = true;
      _serverError = null;
    });
    if (_hasAnyError) return; // Fix the fields first

    setState(() => _isLoading = true);
    final result = await AuthService.instance.signUp(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      voice: _selectedVoice,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      widget.onSignedUp();
    } else {
      setState(() => _serverError = result.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthSheetHeader(title: 'إنشاء حساب', onBack: widget.onBack),

        // ---- Name (Arabic letters only) ----
        // Plain text keyboard (not "name"), because the "name" keyboard on
        // some phones (e.g. Samsung) is locked to English.
        const AuthFieldLabel('الاسم:'),
        AuthTextField(
          key: const Key('signup_name_field'),
          controller: _nameController,
          hint: 'اكتب اسمك بالعربي',
          icon: Icons.person_outline_rounded,
          keyboardType: TextInputType.text,
          errorText: _nameError,
          onChanged: (_) => setState(() {}),
        ),

        // ---- Email ----
        const AuthFieldLabel('البريد الإلكتروني:'),
        AuthTextField(
          key: const Key('signup_email_field'),
          controller: _emailController,
          hint: 'example@email.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          onChanged: (_) => setState(() {}),
        ),

        // ---- Reading voice ----
        // Clear space after the email, so the pink note box doesn't stick to it.
        // The note belongs to the voice, so it sits close to the voice row.
        const SizedBox(height: 40),
        const AuthInfoBanner('سيستخدم حسّك هذا الصوت لقراءة النصوص بصوت مسموع'),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text('الصوت:', style: HesakTextStyles.fieldLabel),
            const Spacer(),
            AuthVoiceToggle(
              value: _selectedVoice,
              onChanged: (voice) => setState(() => _selectedVoice = voice),
            ),
          ],
        ),

        // ---- Password + live rules ----
        const AuthFieldLabel('كلمة المرور:'),
        AuthTextField(
          key: const Key('signup_password_field'),
          controller: _passwordController,
          hint: '••••••••',
          isPassword: true,
          errorText: _passwordError,
          onChanged: (_) => setState(() {}), // Updates the rule dots while typing
        ),
        AuthPasswordRulesList(password: _passwordController.text),

        // ---- Confirm password ----
        const AuthFieldLabel('تأكيد كلمة المرور:'),
        AuthTextField(
          key: const Key('signup_confirm_password_field'),
          controller: _confirmPasswordController,
          hint: '••••••••',
          isPassword: true,
          textInputAction: TextInputAction.done,
          errorText: _confirmPasswordError,
          onChanged: (_) => setState(() {}),
        ),

        // ---- Terms ----
        const SizedBox(height: 12),
        AuthTermsCheckbox(
          value: _hasAcceptedTerms,
          errorText: _termsError,
          onChanged: (accepted) => setState(() => _hasAcceptedTerms = accepted),
        ),

        const SizedBox(height: 24),

        if (_serverError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_serverError!, textAlign: TextAlign.center, style: HesakTextStyles.fieldError),
          ),

        AuthPrimaryButton(
          key: const Key('signup_submit_button'),
          label: 'إنشاء حساب',
          isLoading: _isLoading,
          onPressed: _submitSignUp,
        ),

        const SizedBox(height: 12),
        AuthFooterLink(
          key: const Key('signup_go_to_login_link'),
          question: 'لديك حساب؟',
          linkText: 'تسجيل الدخول',
          onTap: widget.onGoToLogin,
        ),
      ],
    );
  }
}
