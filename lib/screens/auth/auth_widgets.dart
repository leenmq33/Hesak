import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../core/theme/hesak_colors.dart';
import '../../core/theme/hesak_sizes.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import '../../core/data/hesak_legal_texts.dart';
import '../../widgets/hesak_legal_sheet.dart';

// =====================================================================
//  AUTH WIDGETS — small building blocks shared by the sign in / sign up
//  forms (login, sign up, reset password, call name).
//
//  NAMING RULES used in this file:
//  - Everything here starts with "Auth" (AuthTextField, AuthPrimaryButton ...).
//  - Colors / text styles / sizes come ONLY from lib/core/theme.
// =====================================================================

// ---------------------------------------------------------------------
// Validation helpers
// ---------------------------------------------------------------------

/// One password rule and whether the typed password meets it.
class AuthPasswordRule {
  final String label; // Arabic text shown to the user
  final bool isMet;

  const AuthPasswordRule(this.label, this.isMet);
}

/// Checks for emails, passwords and names. Same rules on every screen.
class AuthValidators {
  AuthValidators._(); // Use AuthValidators.xxx directly

  /// Minimum password length.
  static const int minPasswordLength = 8;

  // name@domain.com — letters/numbers/._%+- before @, a dot in the domain.
  static final RegExp _emailPattern = RegExp(r'^[\w.%+-]+@[\w-]+(\.[\w-]+)+$');

  /// true when the text looks like a real email.
  static bool isValidEmail(String email) => _emailPattern.hasMatch(email.trim());

  /// The 5 password rules, each marked as met or not.
  static List<AuthPasswordRule> passwordRules(String password) => [
        AuthPasswordRule('$minPasswordLength خانات على الأقل', password.length >= minPasswordLength),
        AuthPasswordRule('حرف إنجليزي كبير (A-Z)', password.contains(RegExp(r'[A-Z]'))),
        AuthPasswordRule('حرف إنجليزي صغير (a-z)', password.contains(RegExp(r'[a-z]'))),
        AuthPasswordRule('رقم (0-9)', password.contains(RegExp(r'[0-9]'))),
        AuthPasswordRule('رمز خاص مثل ! @ # \$ %', password.contains(RegExp(r'[^A-Za-z0-9\s]'))),
      ];

  /// true when the password meets ALL the rules.
  static bool isStrongPassword(String password) =>
      passwordRules(password).every((rule) => rule.isMet);

  // ARABIC letters and spaces only — no English, no numbers, no symbols.
  // \u0621-\u064A = Arabic letters, \u064B-\u0652 = harakat (تشكيل), \u0640 = ـ
  static final RegExp _arabicLettersPattern =
      RegExp(r'^[\u0621-\u064A\u064B-\u0652\u0640 ]+$');

  // Arabic OR English letters and spaces — no numbers, no symbols.
  static final RegExp _arabicOrEnglishLettersPattern =
      RegExp(r'^[\u0621-\u064A\u064B-\u0652\u0640A-Za-z ]+$');

  /// Why the user's NAME is not OK, or null when it's fine.
  /// Rules: not empty, Arabic or English letters only, at least 2 letters.
  /// Used by إنشاء حساب and الإعدادات (الاسم).
  static String? nameProblem(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'أدخل الاسم';
    if (!_arabicOrEnglishLettersPattern.hasMatch(trimmed)) return 'اكتب الاسم بالحروف فقط (بدون أرقام أو رموز)';
    if (trimmed.replaceAll(' ', '').length < 2) return 'الاسم قصير جدًا (حرفين على الأقل)';
    return null;
  }

  /// true when the name passes all the rules above.
  static bool isValidName(String name) => nameProblem(name) == null;

  /// Why the CALL NAME (الاسم للنداء) is not OK, or null when it's fine.
  /// Rules: not empty, ARABIC letters only (Hesak listens for it in Arabic), at least 2 letters.
  static String? callNameProblem(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'أدخل الاسم';
    if (!_arabicLettersPattern.hasMatch(trimmed)) return 'اكتب الاسم بالحروف العربية فقط (بدون أرقام أو رموز)';
    if (trimmed.replaceAll(' ', '').length < 2) return 'الاسم قصير جدًا (حرفين على الأقل)';
    return null;
  }

  /// true when the call name passes all the rules above.
  static bool isValidCallName(String name) => callNameProblem(name) == null;
}

// ---------------------------------------------------------------------
// Sheet header: title in the middle, optional back arrow on the right
// ---------------------------------------------------------------------

/// Title at the top of the white sheet. Shows a back arrow when [onBack] is given.
/// [startAction] is an optional button on the same row, at the start (right
/// side in Arabic), used when there's no back arrow (e.g. "تخطي").
class AuthSheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? startAction;

  const AuthSheetHeader({super.key, required this.title, this.onBack, this.startAction});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Title with a soft shadow, like the design.
          Text(
            title,
            style: HesakTextStyles.authSheetTitle.copyWith(
              shadows: [
                Shadow(
                  color: HesakColors.primaryDark.withOpacity(0.25),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),

          // Back arrow at the start (right side in Arabic).
          if (onBack != null)
            PositionedDirectional(
              start: 0,
              child: IconButton(
                key: Key('auth_back_button'),
                onPressed: onBack,
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                color: HesakColors.textPrimary,
                tooltip: 'رجوع',
              ),
            ),

          // Or another small button in the same spot.
          if (onBack == null && startAction != null)
            PositionedDirectional(start: 0, child: startAction!),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Label + text field
// ---------------------------------------------------------------------

/// Bold label above a field ("البريد الإلكتروني:").
class AuthFieldLabel extends StatelessWidget {
  final String text;

  const AuthFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 18, bottom: 8),
      child: Text(text, style: HesakTextStyles.fieldLabel),
    );
  }
}

/// Grey rounded text field with an optional icon and an error line under it.
/// Password fields ([isPassword]) hide the text; tapping the lock shows it.
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? errorText; // null = no error
  final ValueChanged<String>? onChanged;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.errorText,
    this.onChanged,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  // Password fields start hidden.
  late bool _isTextHidden = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    final bool hasError = widget.errorText != null;

    // Icon at the end of the field (left side in Arabic).
    // For passwords it's a button: closed lock = hidden, open lock = visible.
    Widget? endIcon;
    if (widget.isPassword) {
      endIcon = IconButton(
        onPressed: () => setState(() => _isTextHidden = !_isTextHidden),
        icon: Icon(_isTextHidden ? Icons.lock_outline_rounded : Icons.lock_open_rounded),
        color: HesakColors.fieldHint,
        tooltip: _isTextHidden ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
      );
    } else if (widget.icon != null) {
      endIcon = Icon(widget.icon, color: HesakColors.fieldHint);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: HesakSizes.fieldHeight,
          child: TextField(
            controller: widget.controller,
            obscureText: _isTextHidden,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onChanged: widget.onChanged,
            style: HesakTextStyles.fieldInput,
            // Emails and passwords are typed left-to-right.
            textDirection: (widget.isPassword || widget.keyboardType == TextInputType.emailAddress)
                ? TextDirection.ltr
                : null,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: HesakTextStyles.fieldHint,
              filled: true,
              fillColor: HesakColors.fieldFill,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: endIcon,
              // No border normally; a thin red one when there's an error.
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HesakSizes.radiusField),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HesakSizes.radiusField),
                borderSide: hasError
                    ? BorderSide(color: HesakColors.urgent, width: 1)
                    : BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HesakSizes.radiusField),
                borderSide: BorderSide(
                  color: hasError ? HesakColors.urgent : HesakColors.primaryLightBorder,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),

        // Error message under the field.
        if (hasError)
          Padding(
            padding: EdgeInsets.only(top: 6, right: 4, left: 4),
            child: Text(widget.errorText!, style: HesakTextStyles.fieldError),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Buttons & links
// ---------------------------------------------------------------------

/// Big rounded purple button. Shows a spinner while [isLoading].
/// Greyed out and not tappable when [onPressed] is null.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color; // null = HesakColors.buttonPrimary
  final TextStyle? labelStyle;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.color,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;

    return AnimatedOpacity(
      duration: Duration(milliseconds: 200),
      opacity: onPressed == null ? 0.45 : 1, // Faded when disabled
      child: GestureDetector(
        onTap: isEnabled ? onPressed : null,
        child: Container(
          height: HesakSizes.buttonHeight,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color ?? HesakColors.buttonPrimary,
            borderRadius: BorderRadius.circular(HesakSizes.radiusButton),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: HesakColors.onPrimary),
                )
              : Text(label, style: labelStyle ?? HesakTextStyles.buttonLabel),
        ),
      ),
    );
  }
}

/// "ليس لديك حساب؟ إنشاء حساب" — grey question + bold tappable link.
class AuthFooterLink extends StatelessWidget {
  final String question;
  final String linkText;
  final VoidCallback onTap;

  const AuthFooterLink({
    super.key,
    required this.question,
    required this.linkText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque, // Easier to tap
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$question ', style: HesakTextStyles.authHint),
              Text(linkText, style: HesakTextStyles.authLink),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frosted glass button for the welcome screen (on the purple background).
///  - [isMain] true  -> "إنشاء حساب": thick white glass, dark purple text, soft shadow.
///  - [isMain] false -> "تسجيل الدخول": very light glass, white text, no shadow.
/// Both blur what's behind them, so they look like the same family.
class AuthGlassButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isMain;

  const AuthGlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isMain = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(HesakSizes.radiusButton);

    return Container(
      // The shadow sits outside the clip, so it isn't cut off.
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: isMain
            ? [BoxShadow(color: HesakColors.glassShadow, blurRadius: 18, offset: Offset(0, 8))]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          // Blurs the moving background behind the button (the "glass" look).
          filter: ImageFilter.blur(sigmaX: HesakSizes.glassBlur, sigmaY: HesakSizes.glassBlur),
          child: Material(
            color: isMain ? HesakColors.glassPrimaryFill : HesakColors.glassSecondaryFill,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(
                color: isMain ? HesakColors.glassPrimaryBorder : HesakColors.glassSecondaryBorder,
                width: 1.3,
              ),
            ),
            child: InkWell(
              onTap: onPressed,
              borderRadius: radius,
              child: SizedBox(
                height: HesakSizes.buttonHeight,
                width: double.infinity,
                child: Center(
                  child: Text(
                    label,
                    style: isMain
                        ? HesakTextStyles.glassButtonPrimaryLabel
                        : HesakTextStyles.glassButtonSecondaryLabel,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Moving (breathing) purple background
// ---------------------------------------------------------------------

/// The purple background of ALL sign in / sign up screens. It moves slowly:
///  - the purple tones gently shift lighter/deeper ("breathing"),
///  - the direction of the gradient sways a little,
///  - two soft light blobs drift around.
/// Only our purples are used (HesakColors.authBreath...).
class AuthBreathingBackground extends StatefulWidget {
  final Widget child; // What's drawn on top (logo, buttons, white sheet)

  const AuthBreathingBackground({super.key, required this.child});

  @override
  State<AuthBreathingBackground> createState() => _AuthBreathingBackgroundState();
}

class _AuthBreathingBackgroundState extends State<AuthBreathingBackground>
    with SingleTickerProviderStateMixin {
  // One full "breath" (A -> B) takes 7 seconds, then it goes back.
  late final AnimationController _breathController = AnimationController(
    vsync: this,
    duration: Duration(seconds: 7),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathController,
      // The child (content) is built once, only the background repaints.
      child: widget.child,
      builder: (context, child) {
        // 0 -> 1 -> 0 ... with soft start and end.
        final t = Curves.easeInOut.transform(_breathController.value);
        // Half a turn per breath, used to swing the blobs back and forth smoothly.
        final angle = _breathController.value * math.pi;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1) The gradient: colors shift and its direction sways a little.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-0.5 + t, -1),
                  end: Alignment(0.5 - t, 1),
                  colors: [
                    Color.lerp(HesakColors.authBreathTopA, HesakColors.authBreathTopB, t)!,
                    Color.lerp(HesakColors.authBreathBottomA, HesakColors.authBreathBottomB, t)!,
                  ],
                ),
              ),
            ),

            // 2) Soft light blob drifting near the top.
            _glowBlob(
              alignment: Alignment(-0.8 + 0.5 * math.cos(angle), -0.75 + 0.15 * math.sin(angle)),
              sizeFactor: 1.1,
            ),

            // 3) Another one drifting near the bottom, the opposite way.
            _glowBlob(
              alignment: Alignment(0.8 - 0.5 * math.cos(angle), 0.7 - 0.15 * math.sin(angle)),
              sizeFactor: 1.3,
            ),

            child!,
          ],
        );
      },
    );
  }

  /// A big round soft glow. [sizeFactor] x screen width.
  Widget _glowBlob({required Alignment alignment, required double sizeFactor}) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: FractionallySizedBox(
          widthFactor: sizeFactor,
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Bright in the middle, fading to nothing at the edge.
                gradient: RadialGradient(
                  colors: [HesakColors.authBreathGlow, HesakColors.authBreathGlowEdge],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Note box, password rules, voice toggle, terms checkbox
// ---------------------------------------------------------------------

/// Light pink box with an info icon and a short note.
class AuthInfoBanner extends StatelessWidget {
  final String text;

  const AuthInfoBanner(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: HesakColors.infoBannerFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HesakColors.infoBannerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: HesakColors.infoBannerText),
          SizedBox(width: 6),
          Expanded(child: Text(text, style: HesakTextStyles.infoBanner)),
        ],
      ),
    );
  }
}

/// List of password rules; each dot turns green when that rule is met.
class AuthPasswordRulesList extends StatelessWidget {
  final String password;

  const AuthPasswordRulesList({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 10, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final rule in AuthValidators.passwordRules(password))
            Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  // Dot: green with a check when met, empty grey when not.
                  AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: rule.isMet ? HesakColors.passwordRuleMet : Colors.transparent,
                      border: Border.all(
                        color: rule.isMet ? HesakColors.passwordRuleMet : HesakColors.passwordRuleUnmet,
                        width: 1.5,
                      ),
                    ),
                    child: rule.isMet
                        ? Icon(Icons.check_rounded, size: 10, color: HesakColors.onPrimary)
                        : null,
                  ),
                  SizedBox(width: 8),
                  Text(rule.label, style: HesakTextStyles.passwordRule),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Two-option switch for the reading voice: ذكر / أنثى.
class AuthVoiceToggle extends StatelessWidget {
  final HesakVoice value;
  final ValueChanged<HesakVoice> onChanged;

  const AuthVoiceToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 46,
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HesakColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _option(HesakVoice.male, 'ذكر'),
          _option(HesakVoice.female, 'أنثى'),
        ],
      ),
    );
  }

  /// One side of the switch. The picked one is white with a small shadow.
  Widget _option(HesakVoice voice, String label) {
    final bool isSelected = voice == value;

    return Expanded(
      child: GestureDetector(
        key: Key('auth_voice_${voice.name}'), // e.g. auth_voice_male
        onTap: () => onChanged(voice),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? HesakColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            style: isSelected ? HesakTextStyles.chipLabel : HesakTextStyles.authHint,
          ),
        ),
      ),
    );
  }
}

/// "أوافق على الشروط والأحكام وسياسة الخصوصية" with a checkbox.
/// The 2 purple words are links: each opens its text (showHesakLegalSheet)
/// without ticking the box. Tapping anywhere else on the row ticks / unticks it.
/// Shows [errorText] under it when set.
class AuthTermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? errorText;

  const AuthTermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: Key('auth_terms_checkbox'),
          onTap: () => onChanged(!value),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: (checked) => onChanged(checked ?? false),
                activeColor: HesakColors.buttonPrimary,
                side: BorderSide(
                  color: errorText != null ? HesakColors.urgent : HesakColors.passwordRuleUnmet,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              // Wraps to a 2nd line on small phones.
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('أوافق على ', style: HesakTextStyles.authHint),
                    HesakLegalLink(
                      key: Key('auth_terms_link'),
                      label: 'الشروط والأحكام',
                      doc: hesakTermsDoc,
                      style: HesakTextStyles.authLink,
                    ),
                    Text(' و', style: HesakTextStyles.authHint),
                    HesakLegalLink(
                      key: Key('auth_privacy_link'),
                      label: 'سياسة الخصوصية',
                      doc: hesakPrivacyDoc,
                      style: HesakTextStyles.authLink,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (errorText != null)
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Text(errorText!, style: HesakTextStyles.fieldError),
          ),
      ],
    );
  }
}
