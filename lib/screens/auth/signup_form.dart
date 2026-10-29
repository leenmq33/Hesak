import 'package:flutter/material.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import 'auth_widgets.dart';

// =====================================================================
//  SIGN UP FORM (إنشاء حساب) — shown inside the white sheet of
//  HesakAuthFlowScreen.
//
//  Flow: "إنشاء حساب" -> AuthService.signUp (sends the verification
//  email) -> the "تأكيد البريد" step -> the "الاسم للنداء" step -> the app.
//
//  NAMING: everything here starts with "SignUp". Keys: 'signup_<name>'.
// =====================================================================

/// Name, email, reading voice, password (+ rules), confirm password, terms.
class SignUpForm extends StatefulWidget {
  final VoidCallback onSignedUp; // Account created -> next step (تأكيد البريد)
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

  /// Empty name or not Arabic letters.
  String? get _nameError {
    if (!_hasTriedSubmit) return null;
    return AuthValidators.nameProblem(_nameController.text);
  }

  /// Empty or wrong-looking email.
  String? get _emailError {
    if (!_hasTriedSubmit) return null;
    if (_emailController.text.trim().isEmpty) return 'أدخل البريد الإلكتروني';
    if (!AuthValidators.isValidEmail(_emailController.text)) return 'البريد الإلكتروني غير صحيح';
    return null;
  }

  /// A password rule is not met yet.
  String? get _passwordError {
    if (!_hasTriedSubmit) return null;
    if (!AuthValidators.isStrongPassword(_passwordController.text)) {
      return 'كلمة المرور لا تحقق كل الشروط';
    }
    return null;
  }

  /// The two passwords are different.
  String? get _confirmPasswordError {
    if (!_hasTriedSubmit) return null;
    if (_confirmPasswordController.text != _passwordController.text) return 'كلمتا المرور غير متطابقتين';
    return null;
  }

  /// The terms box is not ticked.
  String? get _termsError {
    if (!_hasTriedSubmit) return null;
    if (!_hasAcceptedTerms) return 'يجب الموافقة على الشروط والأحكام وسياسة الخصوصية';
    return null;
  }

  /// true = at least one field still has a problem.
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

        // ---- "الاسم:" field (Arabic letters only) ----
        // Plain text keyboard (not "name"), because the "name" keyboard on
        // some phones (e.g. Samsung) is locked to English.
        AuthFieldLabel('الاسم:'),
        AuthTextField(
          key: Key('signup_name_field'),
          controller: _nameController,
          hint: 'اكتب اسمك',
          icon: Icons.person_outline_rounded,
          keyboardType: TextInputType.text,
          inputFormatters: AuthValidators.nameInputFormatters, // 30 characters at most
          errorText: _nameError,
          onChanged: (_) => setState(() {}),
        ),

        // ---- "البريد الإلكتروني:" field ----
        AuthFieldLabel('البريد الإلكتروني:'),
        AuthTextField(
          key: Key('signup_email_field'),
          controller: _emailController,
          hint: 'example@email.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          onChanged: (_) => setState(() {}),
        ),

        // ---- Pink note + "الجنس:" (picks the reading voice) ----
        // Clear space after the email, so the pink note box doesn't stick to it.
        // The note belongs to the voice, so it sits close to the voice row.
        SizedBox(height: 40),
        AuthInfoBanner('سيستخدم حِسّك اختيارك لقراءة النصوص للآخرين بصوت مناسب'),
        SizedBox(height: 10),
        Row(
          children: [
            Text('الجنس:', style: HesakTextStyles.fieldLabel),
            Spacer(),
            AuthVoiceToggle(
              value: _selectedVoice,
              onChanged: (voice) => setState(() => _selectedVoice = voice),
            ),
          ],
        ),

        // ---- "كلمة المرور:" field + the rules under it (update while typing) ----
        AuthFieldLabel('كلمة المرور:'),
        AuthTextField(
          key: Key('signup_password_field'),
          controller: _passwordController,
          hint: '••••••••',
          isPassword: true,
          errorText: _passwordError,
          onChanged: (_) => setState(() {}), // Updates the rule dots while typing
        ),
        AuthPasswordRulesList(password: _passwordController.text),

        // ---- "تأكيد كلمة المرور:" field ----
        AuthFieldLabel('تأكيد كلمة المرور:'),
        AuthTextField(
          key: Key('signup_confirm_password_field'),
          controller: _confirmPasswordController,
          hint: '••••••••',
          isPassword: true,
          textInputAction: TextInputAction.done,
          errorText: _confirmPasswordError,
          onChanged: (_) => setState(() {}),
        ),

        // ---- Terms checkbox ("الشروط والأحكام" / "سياسة الخصوصية" links) ----
        SizedBox(height: 12),
        AuthTermsCheckbox(
          value: _hasAcceptedTerms,
          errorText: _termsError,
          onChanged: (accepted) => setState(() => _hasAcceptedTerms = accepted),
        ),

        SizedBox(height: 24),

        // ---- Server error (e.g. email already used), above the button ----
        if (_serverError != null)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(_serverError!, textAlign: TextAlign.center, style: HesakTextStyles.fieldError),
          ),

        // ---- "إنشاء حساب" button ----
        AuthPrimaryButton(
          key: Key('signup_submit_button'),
          label: 'إنشاء حساب',
          isLoading: _isLoading,
          onPressed: _submitSignUp,
        ),

        // ---- "لديك حساب؟ تسجيل الدخول" ----
        SizedBox(height: 12),
        AuthFooterLink(
          key: Key('signup_go_to_login_link'),
          question: 'لديك حساب؟',
          linkText: 'تسجيل الدخول',
          onTap: widget.onGoToLogin,
        ),
      ],
    );
  }
}
