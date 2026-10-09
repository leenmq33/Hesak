import 'package:flutter/material.dart';
import '../../core/theme/hesak_palette.dart';
import '../../core/theme/hesak_sizes.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import '../../widgets/hesak_page_header.dart';
import '../settings/settings_widgets.dart';
import 'auth_flow_screen.dart';
import 'auth_widgets.dart' show AuthValidators;

// =====================================================================
//  NEW PASSWORD (كلمة مرور جديدة) — opens when the user taps the
//  "نسيت كلمة المرور" link in the email (on the phone, the link opens Hesak).
//
//  The link carries a secret code (AuthService.pendingResetCode).
//  1) Check the code -> show the account's email (or "the link expired").
//  2) New password (same rules + green dots) + confirm.
//  3) Save -> AuthService.confirmNewPassword -> "تم" step -> تسجيل الدخول.
//
//  Built from the الإعدادات widgets, so it looks like تغيير كلمة المرور.
//  NAMING: everything here starts with "NewPassword". Keys: 'new_password_<name>'.
// =====================================================================

/// Given to MaterialApp(navigatorKey: ...) in main.dart,
/// so this screen can open from anywhere in the app.
final GlobalKey<NavigatorState> hesakNavigatorKey = GlobalKey<NavigatorState>();

bool _isNewPasswordScreenOpen = false;

/// Call ONCE in main(), before AuthService.startListeningForLinks().
/// Opens the screen every time a reset link opens the app.
void startOpeningNewPasswordScreen() {
  final DateTime appStartedAt = DateTime.now();
  final auth = AuthService.instance;

  Future<void> openIfNeeded() async {
    final String? code = auth.pendingResetCode.value;
    if (code == null || _isNewPasswordScreenOpen) return;
    _isNewPasswordScreenOpen = true;

    // If the link opened a closed app: let the splash finish first
    // (the splash replaces the top screen when it ends).
    const Duration splashTime = Duration(seconds: 6);
    final Duration waited = DateTime.now().difference(appStartedAt);
    if (waited < splashTime) await Future.delayed(splashTime - waited);

    final NavigatorState? navigator = hesakNavigatorKey.currentState;
    if (navigator == null) {
      _isNewPasswordScreenOpen = false;
      return;
    }
    await navigator.push(MaterialPageRoute(builder: (_) => NewPasswordScreen(code: code)));

    // Closed (saved, or back): forget the code.
    _isNewPasswordScreenOpen = false;
    auth.cancelPasswordReset();
  }

  auth.pendingResetCode.addListener(openIfNeeded);
  openIfNeeded(); // In case a code is already waiting
}

class NewPasswordScreen extends StatefulWidget {
  final String code; // The secret code from the email link

  const NewPasswordScreen({super.key, required this.code});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isChecking = true; // Checking the link with Firebase
  String? _email; // null after checking = link expired / used
  bool _isLoading = false;
  bool _isDone = false; // Password changed -> show the "تم" step
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _checkLink();
  }

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _checkLink() async {
    final email = await AuthService.instance.checkResetCode(widget.code);
    if (!mounted) return;
    setState(() {
      _email = email;
      _isChecking = false;
    });
  }

  // ---- Checks (shown only after the user typed something) ----

  String? get _confirmError {
    if (_confirmController.text.isEmpty) return null;
    if (_confirmController.text != _newController.text) return 'كلمتا المرور غير متطابقتين';
    return null;
  }

  /// The button works only when everything is correct.
  bool get _canSubmit =>
      AuthValidators.isStrongPassword(_newController.text) &&
          _confirmController.text == _newController.text &&
          !_isLoading;

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _serverError = null;
    });
    final result = await AuthService.instance.confirmNewPassword(
      code: widget.code,
      newPassword: _newController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      FocusScope.of(context).unfocus(); // Hide the keyboard
      setState(() => _isDone = true);
    } else {
      setState(() => _serverError = result.errorMessage);
    }
  }

  /// After the change: sign out of any old session on this phone, close
  /// everything, and open تسجيل الدخول.
  Future<void> _goToLogin() async {
    await AuthService.instance.logOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => HesakAuthFlowScreen(initialStep: AuthStep.login),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      ),
          (_) => false, // Remove all the screens behind
    );
  }

  /// Back arrow / phone back button.
  void _goBack() {
    if (_isDone) {
      _goToLogin();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HesakThemeController.instance,
      builder: (context, _) {
        final palette = HesakPalette.current;
        return PopScope(
          canPop: !_isDone, // After the change, back goes to تسجيل الدخول
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _goBack();
          },
          child: Scaffold(
            backgroundColor: palette.background,
            body: SafeArea(
              child: Column(
                children: [
                  HesakPageHeader(
                    title: 'كلمة مرور جديدة',
                    onBack: _goBack,
                    followsAppearance: true,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                          HesakSizes.pagePadding, 0, HesakSizes.pagePadding, HesakSizes.pageBottomSafeSpace),
                      child: _isChecking
                          ? _buildChecking(palette)
                          : _email == null
                          ? _buildExpired(palette)
                          : (_isDone ? _buildDone(palette) : _buildForm(palette)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The password was changed.
  Widget _buildDone(HesakPalette palette) {
    return Column(
      key: ValueKey('new_password_done_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 40),
        Icon(Icons.check_circle_outline_rounded, size: 64, color: palette.success),
        SizedBox(height: 16),
        Text(
          'تم تغيير كلمة المرور',
          textAlign: TextAlign.center,
          style: HesakTextStyles.fieldLabel.copyWith(color: palette.textPrimary),
        ),
        SizedBox(height: 8),
        Text(
          'سجّل الدخول الآن بكلمة المرور الجديدة',
          textAlign: TextAlign.center,
          style: HesakTextStyles.body.copyWith(color: palette.textSecondary, fontSize: 13, height: 1.6),
        ),
        SizedBox(height: 32),
        SettingsButton(
          key: Key('new_password_go_to_login_button'),
          label: 'تسجيل الدخول',
          onTap: _goToLogin,
        ),
      ],
    );
  }

  /// While checking the link.
  Widget _buildChecking(HesakPalette palette) {
    return Padding(
      padding: EdgeInsets.only(top: 80),
      child: Center(child: CircularProgressIndicator(color: palette.accent)),
    );
  }

  /// The link expired or was already used.
  Widget _buildExpired(HesakPalette palette) {
    return Column(
      key: ValueKey('new_password_expired_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 40),
        Icon(Icons.link_off_rounded, size: 64, color: palette.danger),
        SizedBox(height: 16),
        Text(
          'الرابط منتهي أو استُخدم من قبل',
          textAlign: TextAlign.center,
          style: HesakTextStyles.fieldLabel.copyWith(color: palette.textPrimary),
        ),
        SizedBox(height: 8),
        Text(
          'اطلب رابطًا جديدًا من "نسيت كلمة المرور"، وافتح آخر رسالة تصلك',
          textAlign: TextAlign.center,
          style: HesakTextStyles.body.copyWith(color: palette.textSecondary, fontSize: 13, height: 1.6),
        ),
        SizedBox(height: 32),
        SettingsButton(
          key: Key('new_password_back_button'),
          label: 'رجوع',
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }

  /// The form: new password (+ rules) + confirm.
  Widget _buildForm(HesakPalette palette) {
    return Column(
      key: ValueKey('new_password_form_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 8),
        SettingsNote('اختر كلمة مرور جديدة لحسابك، ثم سجّل الدخول بها'),

        // The account (read only).
        Padding(
          padding: EdgeInsets.only(top: 16, bottom: 8),
          child: Text('الحساب:', style: HesakTextStyles.fieldLabel.copyWith(color: palette.textPrimary)),
        ),
        Text(
          _email!,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          style: HesakTextStyles.body.copyWith(color: palette.textSecondary, fontSize: 14),
        ),

        SettingsTextField(
          key: Key('new_password_new_field'),
          label: 'كلمة المرور الجديدة:',
          controller: _newController,
          hint: '••••••••',
          isPassword: true,
          onChanged: (_) => setState(() => _serverError = null), // Updates the rule dots
        ),
        SettingsPasswordRules(password: _newController.text),
        SettingsTextField(
          key: Key('new_password_confirm_field'),
          label: 'تأكيد كلمة المرور الجديدة:',
          controller: _confirmController,
          hint: '••••••••',
          isPassword: true,
          errorText: _confirmError,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _serverError = null),
        ),

        SizedBox(height: 24),
        if (_serverError != null)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              _serverError!,
              textAlign: TextAlign.center,
              style: HesakTextStyles.fieldError.copyWith(color: palette.danger),
            ),
          ),
        SettingsButton(
          key: Key('new_password_submit_button'),
          label: 'حفظ كلمة المرور',
          isLoading: _isLoading,
          onTap: _canSubmit ? _submit : null,
        ),
      ],
    );
  }
}