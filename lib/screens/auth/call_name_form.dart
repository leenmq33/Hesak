import 'package:flutter/material.dart';
import '../../core/theme/hesak_text_styles.dart';
import '../../services/auth_service.dart';
import 'auth_widgets.dart';

// =====================================================================
//  CALL NAME FORM (للتنبيه عند النداء) — shown once, right after a new
//  account is created. The user types the name Hesak should listen for;
//  when someone says it, the user gets an alert.
//
//  NAMING: everything here starts with "CallName". Keys: 'call_name_<name>'.
// =====================================================================

/// One name field + "التالي". "التالي" only works after a valid name is typed
/// (Arabic letters only — no English, numbers or symbols). "تخطي" skips this step.
class CallNameForm extends StatefulWidget {
  final VoidCallback onDone; // Saved or skipped -> open the app

  const CallNameForm({super.key, required this.onDone});

  @override
  State<CallNameForm> createState() => _CallNameFormState();
}

class _CallNameFormState extends State<CallNameForm> {
  final _callNameController = TextEditingController();
  bool _isLoading = false;
  String? _serverError;

  @override
  void dispose() {
    _callNameController.dispose();
    super.dispose();
  }

  /// true once a valid name is typed -> "التالي" becomes tappable.
  bool get _canContinue => AuthValidators.isValidCallName(_callNameController.text);

  /// Error under the field. Shown as soon as something wrong is typed
  /// (e.g. a number), but not while the field is still empty.
  String? get _callNameError {
    if (_callNameController.text.isEmpty) return null;
    return AuthValidators.callNameProblem(_callNameController.text);
  }

  /// "التالي" tapped: save the name, then open the app.
  Future<void> _submitCallName() async {
    setState(() {
      _isLoading = true;
      _serverError = null;
    });
    final result = await AuthService.instance.saveCallName(callName: _callNameController.text.trim());
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      widget.onDone();
    } else {
      setState(() => _serverError = result.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthSheetHeader(title: 'للتنبيه عند النداء'),

        const SizedBox(height: 14),
        // Same note as in الإعدادات (الاسم للنداء).
        const AuthInfoBanner('سيُنبّهك حِسّك عند سماع هذا الاسم، لتعرف أن أحدًا يناديك'),

        const AuthFieldLabel('الاسم:'),
        AuthTextField(
          key: const Key('call_name_field'),
          controller: _callNameController,
          hint: 'اكتب الاسم بالعربي',
          // Plain text keyboard: the "name" keyboard can be locked to English.
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          errorText: _callNameError,
          onChanged: (_) => setState(() {}), // Enables "التالي" once a valid name is typed
        ),

        const SizedBox(height: 44),

        if (_serverError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_serverError!, textAlign: TextAlign.center, style: HesakTextStyles.fieldError),
          ),

        // Greyed out until a valid name is typed.
        AuthPrimaryButton(
          key: const Key('call_name_next_button'),
          label: 'التالي',
          isLoading: _isLoading,
          onPressed: _canContinue ? _submitCallName : null,
        ),

        // "يمكنك إضافته لاحقًا. تخطي" under the button — same style as the
        // other links ("ليس لديك حساب؟ إنشاء حساب"). Skips this step.
        const SizedBox(height: 12),
        AuthFooterLink(
          key: const Key('call_name_skip_link'),
          question: 'يمكنك إضافته لاحقًا',
          linkText: 'تخطي',
          onTap: () {
            if (!_isLoading) widget.onDone(); // Ignore taps while saving
          },
        ),
      ],
    );
  }
}
