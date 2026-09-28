import 'package:flutter/foundation.dart';

// =====================================================================
//  AUTH SERVICE — the ONLY place that talks to the account system.
//
//  Right now it's FAKE: every call waits a moment and returns "success",
//  so the screens can be built and tested without a server.
//
//  Later (Firebase / Supabase / our own server): change the inside of
//  each function in THIS file only. The screens don't need to change.
// =====================================================================

/// The voice the app uses to read texts out loud.
enum HesakVoice { male, female }

/// Result of an account action: success, or a message to show the user.
class AuthResult {
  final bool isSuccess;
  final String? errorMessage; // Arabic message shown under the button

  const AuthResult.success()
      : isSuccess = true,
        errorMessage = null;

  const AuthResult.failure(this.errorMessage) : isSuccess = false;
}

/// Sign up, log in, reset password, the "call name", and the account
/// settings (الإعدادات). Use it everywhere through `AuthService.instance`.
///
/// It's a ChangeNotifier: widgets that show the user's info (e.g. the home
/// greeting) rebuild when it changes, using ListenableBuilder.
class AuthService extends ChangeNotifier {
  AuthService._(); // Only one AuthService in the whole app
  static final AuthService instance = AuthService._();

  // Fake waiting time, so the loading spinner can be seen.
  static const Duration _fakeDelay = Duration(milliseconds: 900);

  // ---- The signed-in user's info ----
  // TODO: after login, read all of these from the user's profile on the server.

  /// Name (from sign up). Shown in the home greeting ("مرحبًا, فلان !"). null = unknown.
  String? currentUserName;

  /// Email (from sign up / login). null = unknown.
  String? currentEmail;

  /// Reading voice (from sign up).
  HesakVoice currentVoice = HesakVoice.male;

  /// The name Hesak listens for (للتنبيه عند النداء). null = not added yet.
  String? currentCallName;

  /// Creates a new account.
  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
    required HesakVoice voice,
  }) async {
    // TODO: create the account on the real server (e.g. Firebase Auth).
    await Future.delayed(_fakeDelay);
    currentUserName = name; // Remember it for the home greeting
    currentEmail = email;
    currentVoice = voice;
    notifyListeners();
    return const AuthResult.success();
  }

  /// Logs in with email + password.
  Future<AuthResult> logIn({
    required String email,
    required String password,
  }) async {
    // TODO: check email + password on the real server.
    // Example of a real error: return const AuthResult.failure('البريد الإلكتروني أو كلمة المرور غير صحيحة');
    // TODO: also load the user's name, voice and call name from the server.
    await Future.delayed(_fakeDelay);
    currentEmail = email;
    notifyListeners();
    return const AuthResult.success();
  }

  /// Sends an email with a secure link to choose a new password.
  /// The user opens the link, sets the new password there, then logs in.
  Future<AuthResult> sendPasswordResetEmail({required String email}) async {
    // TODO (Firebase): await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    await Future.delayed(_fakeDelay);
    return const AuthResult.success();
  }

  /// Saves the name the app should listen for (للتنبيه عند النداء).
  Future<AuthResult> saveCallName({required String callName}) async {
    // TODO: save it to the user's profile on the server.
    await Future.delayed(_fakeDelay);
    currentCallName = callName;
    notifyListeners();
    return const AuthResult.success();
  }

  // ---------------------------------------------------------------------
  // Account settings (الإعدادات)
  // ---------------------------------------------------------------------

  /// Changes the user's name.
  Future<AuthResult> updateName({required String name}) async {
    // TODO: save it to the user's profile on the server.
    await Future.delayed(_fakeDelay);
    currentUserName = name;
    notifyListeners();
    return const AuthResult.success();
  }

  /// Changes the reading voice (saved right away, no loading).
  void updateVoice(HesakVoice voice) {
    // TODO: save it to the user's profile on the server.
    if (voice == currentVoice) return;
    currentVoice = voice;
    notifyListeners();
  }

  /// Changes the password. The current password is checked first.
  Future<AuthResult> changePassword({required String currentPassword, required String newPassword}) async {
    // TODO (Firebase): re-authenticate with currentPassword, then user.updatePassword(newPassword).
    // Example of a real error: return const AuthResult.failure('كلمة المرور الحالية غير صحيحة');
    await Future.delayed(_fakeDelay);
    return const AuthResult.success();
  }

  /// Starts changing the email: sends a confirmation link to the NEW email.
  /// The email only changes after the user opens that link (keeps the account safe).
  Future<AuthResult> requestEmailChange({required String newEmail, required String currentPassword}) async {
    // TODO (Firebase): re-authenticate with currentPassword, then user.verifyBeforeUpdateEmail(newEmail).
    await Future.delayed(_fakeDelay);
    return const AuthResult.success();
  }

  /// Signs the user out and forgets their info on this phone.
  Future<void> logOut() async {
    // TODO (Firebase): await FirebaseAuth.instance.signOut();
    currentUserName = null;
    currentEmail = null;
    currentCallName = null;
    currentVoice = HesakVoice.male;
    notifyListeners();
  }
}
