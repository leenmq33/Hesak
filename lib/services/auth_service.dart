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

/// Sign up, log in, reset password, and save the "call name".
/// Use it everywhere through `AuthService.instance`.
class AuthService {
  AuthService._(); // Only one AuthService in the whole app
  static final AuthService instance = AuthService._();

  // Fake waiting time, so the loading spinner can be seen.
  static const Duration _fakeDelay = Duration(milliseconds: 900);

  /// The signed-in user's name (from sign up). Shown in the home greeting
  /// ("مرحبًا, فلان !"). null = we don't know it yet.
  /// TODO: after login, read it from the user's profile on the server.
  String? currentUserName;

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
    return const AuthResult.success();
  }

  /// Logs in with email + password.
  Future<AuthResult> logIn({
    required String email,
    required String password,
  }) async {
    // TODO: check email + password on the real server.
    // Example of a real error: return const AuthResult.failure('البريد الإلكتروني أو كلمة المرور غير صحيحة');
    // TODO: also load the user's name from the server into currentUserName.
    await Future.delayed(_fakeDelay);
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
    return const AuthResult.success();
  }
}
