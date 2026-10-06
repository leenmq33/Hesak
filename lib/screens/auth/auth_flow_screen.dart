import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/hesak_colors.dart';
import '../../core/theme/hesak_sizes.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import '../main_shell.dart';
import 'auth_widgets.dart';
import 'call_name_form.dart';
import 'login_form.dart';
import 'reset_password_form.dart';
import 'signup_form.dart';
import 'verify_email_form.dart';

// =====================================================================
//  AUTH FLOW — everything between the splash and the app:
//    welcome (2 buttons) -> login / sign up / reset password
//    -> verify email (تأكيد البريد) -> call name
//
//  It's ONE screen on purpose, so the moves between steps are smooth:
//  - Welcome: logo in the middle, then it rises and 2 buttons slide in.
//  - Tap a button: the logo moves to the top and a white sheet rises from
//    the bottom like a sheet of paper, with the form inside.
//  - Switching forms (login <-> sign up ...) only changes the sheet content.
//  - The purple background moves slowly ("breathing") on every step
//    (AuthBreathingBackground in auth_widgets.dart).
//
//  Each form lives in its own file (login_form.dart, signup_form.dart ...).
//
//  NAMING: everything here starts with "AuthFlow". Keys: 'auth_<name>'.
// =====================================================================

/// The steps of the flow, in the order a new user usually sees them.
enum AuthStep { welcome, login, signUp, resetPassword, verifyEmail, callName }

/// Welcome buttons + all sign in / sign up forms.
class HesakAuthFlowScreen extends StatefulWidget {
  /// The first step to show. Normally welcome (after the splash);
  /// login after "كلمة مرور جديدة" (see new_password_screen.dart).
  final AuthStep initialStep;

  const HesakAuthFlowScreen({super.key, this.initialStep = AuthStep.welcome});

  @override
  State<HesakAuthFlowScreen> createState() => _HesakAuthFlowScreenState();
}

class _HesakAuthFlowScreenState extends State<HesakAuthFlowScreen> {
  late AuthStep _step = widget.initialStep;
  // Welcome starts looking exactly like the end of the splash (logo in the middle).
  // Shortly after, the logo rises and the 2 buttons slide in.
  bool _areWelcomeButtonsVisible = false;
  Timer? _welcomeButtonsTimer;

  // ---- Animation timing ----
  static const Duration _moveDuration = Duration(milliseconds: 650);
  static const Curve _moveCurve = Curves.easeOutCubic;

  // ---- Logo image ratio (hesak_logo.png is 1510 x 389) ----
  static const double _logoAspectRatio = 389 / 1510;

  @override
  void initState() {
    super.initState();
    _welcomeButtonsTimer = Timer(Duration(milliseconds: 500), () {
      if (mounted) setState(() => _areWelcomeButtonsVisible = true);
    });
  }

  @override
  void dispose() {
    _welcomeButtonsTimer?.cancel();
    super.dispose();
  }

  /// Moves to another step (the sheet animates by itself).
  void _goTo(AuthStep step) {
    FocusScope.of(context).unfocus(); // Hide the keyboard
    setState(() => _step = step);
  }

  /// Phone back button / back arrow: go to the previous step.
  void _goBack() {
    switch (_step) {
      case AuthStep.login:
      case AuthStep.signUp:
        _goTo(AuthStep.welcome);
        break;
      case AuthStep.resetPassword:
        _goTo(AuthStep.login);
        break;
      case AuthStep.verifyEmail:
        _leaveVerifyEmail();
        break;
      case AuthStep.welcome:
      case AuthStep.callName: // Must press "تخطي" or "التالي"
        break;
    }
  }

  /// Signed in (or finished sign up): open the app, and remove this screen
  /// so the back button doesn't return here.
  void _openApp() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => HesakMainShell(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// Back from "تأكيد البريد": sign out (the email isn't verified, so the
  /// app never opens) and return to the welcome screen.
  Future<void> _leaveVerifyEmail() async {
    await AuthService.instance.logOut();
    if (mounted) _goTo(AuthStep.welcome);
  }

  /// Email verified: new users (no call name yet) go to the call name step,
  /// others open the app.
  void _afterEmailVerified() {
    if (AuthService.instance.currentCallName == null) {
      _goTo(AuthStep.callName);
    } else {
      _openApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final screenHeight = media.size.height;
    final safeTop = media.padding.top;

    final bool isWelcome = _step == AuthStep.welcome;

    // ---- Sizes & positions ----
    final double sheetTop =
        screenHeight * 0.30; // White sheet starts at 30% of the screen
    final double logoWidth = screenWidth * (isWelcome ? 0.72 : 0.66);
    final double logoGap = isWelcome
        ? 28
        : 12; // Space between logo and tagline
    final double logoBlockHeight = logoWidth * _logoAspectRatio + logoGap + 34;

    // Where the logo block sits:
    //  - welcome, before buttons: centered (same as the splash)
    //  - welcome, with buttons:   higher up
    //  - forms:                   centered in the purple area above the sheet
    final double logoTop = isWelcome
        ? (_areWelcomeButtonsVisible
              ? screenHeight * 0.20
              : (screenHeight - logoBlockHeight) / 2)
        : (safeTop + sheetTop - logoBlockHeight) / 2;

    return PopScope(
      canPop: isWelcome, // On welcome, back closes the app as usual
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        // The sheet handles the keyboard itself (scrolls), so the screen doesn't jump.
        resizeToAvoidBottomInset: false,
        // Moving purple background behind everything, on every step.
        // It's outside the steps, so it keeps moving smoothly between them.
        body: AuthBreathingBackground(
          child: Stack(
            children: [
              // ---------- 1) Logo + tagline ----------
              AnimatedPositioned(
                duration: _moveDuration,
                curve: _moveCurve,
                top: logoTop,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: _moveDuration,
                      curve: _moveCurve,
                      width: logoWidth,
                      child: Image.asset(
                        'assets/images/logo/hesak_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    AnimatedContainer(duration: _moveDuration, height: logoGap),
                    Text(
                      'لأن ما لا يُسمع يَستحق أن يُدرك',
                      key: Key('auth_tagline'),
                      textAlign: TextAlign.center,
                      style: HesakTextStyles.splashTagline,
                    ),
                  ],
                ),
              ),

              // ---------- 2) Welcome buttons ----------
              Positioned(
                top: screenHeight * 0.52,
                left: screenWidth * 0.18,
                right: screenWidth * 0.18,
                child: IgnorePointer(
                  ignoring: !(isWelcome && _areWelcomeButtonsVisible), // Not tappable when hidden
                  child: AnimatedOpacity(
                    duration: Duration(milliseconds: 450),
                    opacity: isWelcome && _areWelcomeButtonsVisible ? 1 : 0,
                    child: AnimatedSlide(
                      duration: _moveDuration,
                      curve: _moveCurve,
                      // Slides up into place; slides down when leaving.
                      offset: isWelcome && _areWelcomeButtonsVisible
                          ? Offset.zero
                          : Offset(0, 0.4),
                      // Glass buttons: same family, but "إنشاء حساب" is clearly the main one
                      // (thicker glass + dark purple text + shadow), "تسجيل الدخول" is lighter.
                      child: Column(
                        children: [
                          // New users are the most common at first, so "إنشاء حساب" is the main button.
                          AuthGlassButton(
                            key: Key('auth_welcome_signup_button'),
                            label: 'إنشاء حساب',
                            isMain: true,
                            onPressed: () => _goTo(AuthStep.signUp),
                          ),
                          SizedBox(height: 24),
                          AuthGlassButton(
                            key: Key('auth_welcome_login_button'),
                            label: 'تسجيل الدخول',
                            onPressed: () => _goTo(AuthStep.login),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ---------- 3) White sheet with the form ----------
              // Hidden below the screen on welcome; rises to 30% for the forms.
              AnimatedPositioned(
                duration: _moveDuration,
                curve: _moveCurve,
                top: isWelcome ? screenHeight : sheetTop,
                left: 0,
                right: 0,
                height: screenHeight - sheetTop,
                child: Container(
                  // Cut the content to the sheet's rounded top, so fields that
                  // scroll up disappear under the white edge instead of
                  // showing on top of the purple area.
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: HesakColors.background,
                    // Soft arc on top, like the design.
                    borderRadius: BorderRadius.vertical(
                      top: Radius.elliptical(screenWidth / 2, 40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  // Switching forms: the old one fades out, the new one fades + slides in.
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 350),
                    // Every form fills the sheet and starts from the TOP
                    // (by default short forms were centered in the middle).
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.topCenter,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    ),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(
                        _step,
                      ), // Tells the switcher the form changed
                      child: _buildSheetContent(media),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The form for the current step, scrollable (the sign up form is long,
  /// and the keyboard takes space).
  Widget _buildSheetContent(MediaQueryData media) {
    if (_step == AuthStep.welcome) return SizedBox.shrink();

    // No Android "stretch" effect at the ends: scrolling just stops softly
    // at the top and bottom instead of stretching the form.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: SingleChildScrollView(
        physics: ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          HesakSizes.authSheetPadding,
          20,
          HesakSizes.authSheetPadding,
          32 +
              media.viewInsets.bottom +
              media.padding.bottom, // Room for keyboard + phone bottom bar
        ),
        child: _buildForm(),
      ),
    );
  }

  /// Which form to show for each step.
  Widget _buildForm() {
    switch (_step) {
      case AuthStep.login:
        return LoginForm(
          onLoggedIn: _openApp,
          onEmailNotVerified: () => _goTo(AuthStep.verifyEmail), // Not verified yet -> تأكيد البريد
          onForgotPassword: () => _goTo(AuthStep.resetPassword),
          onGoToSignUp: () => _goTo(AuthStep.signUp),
          onBack: () => _goTo(AuthStep.welcome),
        );
      case AuthStep.signUp:
        return SignUpForm(
          onSignedUp: () =>
              _goTo(AuthStep.verifyEmail), // New account -> verify the email first
          onGoToLogin: () => _goTo(AuthStep.login),
          onBack: () => _goTo(AuthStep.welcome),
        );
      case AuthStep.resetPassword:
        return ResetPasswordForm(onBack: () => _goTo(AuthStep.login));
      case AuthStep.verifyEmail:
        return VerifyEmailForm(onVerified: _afterEmailVerified, onBack: _leaveVerifyEmail);
      case AuthStep.callName:
        return CallNameForm(onDone: _openApp);
      case AuthStep.welcome:
        return SizedBox.shrink();
    }
  }
}
