import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/theme/hesak_palette.dart';

// =====================================================================
//  AUTH SERVICE — the ONLY place that talks to the account system.
//
//  Now connected to Firebase:
//    - Firebase Authentication: the account (email, password, verification).
//    - Cloud Firestore users/{uid}: the profile (name, voice, call name...).
//
//  The public functions are the same as the fake version,
//  so the screens don't need to change.
// =====================================================================

/// The voice the app uses to read texts out loud.
enum HesakVoice { male, female }

/// Result of an account action: success, or a message to show the user.
class AuthResult {
  final bool isSuccess;
  final String? errorMessage; // Arabic message shown under the button

  /// true = right email + password, but the email isn't verified yet
  /// (the login form then moves to the "تأكيد البريد" step).
  final bool needsEmailVerification;

  const AuthResult.success()
      : isSuccess = true,
        errorMessage = null,
        needsEmailVerification = false;

  const AuthResult.failure(this.errorMessage)
      : isSuccess = false,
        needsEmailVerification = false;

  const AuthResult.emailNotVerified()
      : isSuccess = false,
        errorMessage = 'لم يتم تأكيد بريدك الإلكتروني بعد',
        needsEmailVerification = true;
}

/// Sign up, log in, reset password, the "call name", and the account
/// settings (الإعدادات). Use it everywhere through `AuthService.instance`.
///
/// It's a ChangeNotifier: widgets that show the user's info (e.g. the home
/// greeting) rebuild when it changes, using ListenableBuilder.
class AuthService extends ChangeNotifier {
  AuthService._(); // Only one AuthService in the whole app
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// The user's profile document: users/{uid}
  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  // ---- The signed-in user's info (loaded from Firestore) ----

  /// Name (from sign up). Shown in the home greeting ("مرحبًا, فلان !"). null = unknown.
  String? currentUserName;

  /// Email (from sign up / login). null = unknown.
  String? currentEmail;

  /// Reading voice (from sign up).
  HesakVoice currentVoice = HesakVoice.male;

  /// The name Hesak listens for (للتنبيه عند النداء). null = not added yet.
  String? currentCallName;

  /// Voice picked at sign up, kept here until the email is verified
  /// (the profile is saved in Firestore only AFTER verification).
  HesakVoice? _pendingVoice;

  /// True if someone is signed in AND their email is verified.
  bool get isLoggedIn =>
      _auth.currentUser != null && _auth.currentUser!.emailVerified;

  // ---------------------------------------------------------------------
  // Sign up / log in / log out
  // ---------------------------------------------------------------------

  /// Creates a new account and sends the verification email.
  /// The profile (users/{uid}) is saved only after the email is verified.
  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
    required HesakVoice voice,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;

      // Used as %DISPLAY_NAME% inside the verification email.
      await user.updateDisplayName(name.trim());

      // The profile is NOT saved in Firestore yet: only after the user
      // opens the verification link (see checkEmailVerified / logIn).
      _pendingVoice = voice;

      // Send the verification email (in Arabic).
      await _auth.setLanguageCode('ar');
      await user.sendEmailVerification();

      currentUserName = name.trim();
      currentEmail = email.trim();
      currentVoice = voice;
      currentCallName = null;
      notifyListeners();
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_arabicError(e.code));
    } catch (e) {
      debugPrint('signUp error: $e');
      return const AuthResult.failure('حدث خطأ، حاول مرة أخرى');
    }
  }

  /// Logs in with email + password.
  /// If the email is not verified yet: sends the link again and returns
  /// emailNotVerified (the login form moves to the "تأكيد البريد" step).
  Future<AuthResult> logIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;

      if (!user.emailVerified) {
        try {
          await _auth.setLanguageCode('ar');
          await user.sendEmailVerification();
        } catch (_) {
          // e.g. too many requests — the old link still works.
        }
        // Stay signed in, so the "تأكيد البريد" step can check and resend.
        // (isLoggedIn stays false until the email is verified.)
        currentEmail = user.email ?? email.trim();
        return const AuthResult.emailNotVerified();
      }

      await _loadProfile(user);
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_arabicError(e.code));
    } catch (e) {
      debugPrint('logIn error: $e');
      return const AuthResult.failure('حدث خطأ، حاول مرة أخرى');
    }
  }

  /// Call this when the app opens (e.g. in the splash screen).
  /// Returns true if the user is still signed in and verified, and loads their info.
  Future<bool> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
      final fresh = _auth.currentUser;
      if (fresh == null || !fresh.emailVerified) return false;
      await fresh.getIdToken(true); // Fresh token says "verified" (needed by the security rules)
      await _loadProfile(fresh);
      return true;
    } catch (e) {
      debugPrint('restoreSession error: $e');
      return false;
    }
  }

  /// Signs the user out and forgets their info on this phone.
  Future<void> logOut() async {
    await _auth.signOut();
    currentUserName = null;
    currentEmail = null;
    currentCallName = null;
    currentVoice = HesakVoice.male;
    notifyListeners();
    // فاتح / داكن stays as it is: the sign-in pages keep the phone's last choice.
  }

  // ---------------------------------------------------------------------
  // Email verification
  // ---------------------------------------------------------------------

  /// Sends the verification email again.
  Future<AuthResult> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthResult.failure('يرجى تسجيل الدخول أولًا');
    }
    try {
      await _auth.setLanguageCode('ar');
      await user.sendEmailVerification();
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_arabicError(e.code));
    }
  }

  /// Checks with Firebase whether the user opened the verification link.
  /// When verified, the profile is saved in Firestore (users/{uid}) and loaded.
  Future<bool> checkEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
      final fresh = _auth.currentUser;
      if (fresh == null || !fresh.emailVerified) return false;
      await fresh.getIdToken(true); // Fresh token says "verified" (needed by the security rules)
      await _loadProfile(fresh); // Creates users/{uid} the first time
      return true;
    } catch (e) {
      debugPrint('checkEmailVerified error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // Password reset + call name
  // ---------------------------------------------------------------------

  /// Sends an email with a secure link to choose a new password.
  /// On the phone, the link opens Hesak (see pendingResetCode below).
  Future<AuthResult> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.setLanguageCode('ar');
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
        // The link in the email opens the Hesak app (not a web page).
        // On a computer (no app) it opens Firebase's page instead.
        actionCodeSettings: ActionCodeSettings(
          url: 'https://hesak-4f175.firebaseapp.com/reset',
          handleCodeInApp: true,
          androidPackageName: 'com.example.hesak',
          androidInstallApp: false,
        ),
      );
      debugPrint('🟢 [reset] email sent with in-app link settings');
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      debugPrint('🔴 [reset] ${e.code} | ${e.message}');
      return AuthResult.failure(_arabicError(e.code));
    }
  }

  // ---------------------------------------------------------------------
  // Password reset INSIDE the app (the link from the email opens Hesak)
  // ---------------------------------------------------------------------

  /// The secret code from a password-reset link the user opened.
  /// The "new password" screen listens to this: not null = open the screen.
  final ValueNotifier<String?> pendingResetCode = ValueNotifier<String?>(null);

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  /// Call ONCE in main(). Listens for email links that open the app
  /// (also the link that opened a closed app).
  void startListeningForLinks() {
    _linkSubscription ??= _appLinks.uriLinkStream.listen(
      _handleLink,
      onError: (e) => debugPrint('🔴 [link] $e'),
    );
  }

  void _handleLink(Uri uri) {
    // Firebase wraps the real link: .../__/auth/links?link=<real link>
    Uri actionLink = uri;
    final inner = uri.queryParameters['link'];
    if (inner != null) actionLink = Uri.parse(inner);

    final mode = actionLink.queryParameters['mode'];
    final code = actionLink.queryParameters['oobCode'];
    debugPrint('🟢 [link] mode=$mode, hasCode=${code != null}');

    if (mode == 'resetPassword' && code != null) {
      pendingResetCode.value = code;
    }
  }

  /// Checks the code from the link.
  /// Returns the account's email, or null if the link expired / was used.
  Future<String?> checkResetCode(String code) async {
    try {
      return await _auth.verifyPasswordResetCode(code);
    } on FirebaseAuthException catch (e) {
      debugPrint('🔴 [reset] ${e.code}');
      return null;
    }
  }

  /// Saves the new password using the code from the link.
  /// Firebase's password policy is checked here too.
  Future<AuthResult> confirmNewPassword({
    required String code,
    required String newPassword,
  }) async {
    try {
      await _auth.confirmPasswordReset(code: code, newPassword: newPassword);
      pendingResetCode.value = null;
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_arabicError(e.code));
    }
  }

  /// The user closed the new-password screen without saving.
  void cancelPasswordReset() => pendingResetCode.value = null;

  /// Saves the name the app should listen for (للتنبيه عند النداء).
  Future<AuthResult> saveCallName({required String callName}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthResult.failure('يرجى تسجيل الدخول أولًا');
    }
    try {
      await _userDoc(user.uid).update({
        'nameRecognition': {
          'enabled': true,
          'names': [callName.trim()],
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
      currentCallName = callName.trim();
      notifyListeners();
      return const AuthResult.success();
    } catch (e) {
      debugPrint('saveCallName error: $e');
      return const AuthResult.failure('تعذّر حفظ الاسم، حاول مرة أخرى');
    }
  }

  // ---------------------------------------------------------------------
  // Account settings (الإعدادات)
  // ---------------------------------------------------------------------

  /// Changes the user's name.
  Future<AuthResult> updateName({required String name}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthResult.failure('يرجى تسجيل الدخول أولًا');
    }
    try {
      await _userDoc(user.uid).update({'displayName': name.trim()});
      await user.updateDisplayName(name.trim());
      currentUserName = name.trim();
      notifyListeners();
      return const AuthResult.success();
    } catch (e) {
      debugPrint('updateName error: $e');
      return const AuthResult.failure('تعذّر حفظ الاسم، حاول مرة أخرى');
    }
  }

  /// Changes the reading voice (saved right away, no loading).
  void updateVoice(HesakVoice voice) {
    if (voice == currentVoice) return;
    currentVoice = voice;
    notifyListeners();

    final user = _auth.currentUser;
    if (user == null) return;
    unawaited(
      _userDoc(user.uid)
          .update({'settings.ttsVoice': voice.name})
          .catchError((e) => debugPrint('updateVoice error: $e')),
    );
  }

  /// Changes the appearance (فاتح / داكن) right away, and saves it in
  /// users/{uid}.settings.appearance ("light" / "dark"), so it comes back
  /// after a new login or on another phone.
  void updateAppearance(HesakAppearance appearance) {
    final theme = HesakThemeController.instance;
    if (appearance == theme.appearance) return;
    theme.setAppearance(appearance);

    final user = _auth.currentUser;
    if (user == null) return;
    unawaited(
      _userDoc(user.uid)
          .update({'settings.appearance': appearance.name})
          .catchError((e) => debugPrint('updateAppearance error: $e')),
    );
  }

  /// Changes the password. The current password is checked first.
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return const AuthResult.failure('يرجى تسجيل الدخول أولًا');
    }
    try {
      await _reauthenticate(user, currentPassword);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_wrongCurrentPassword(e.code));
    }
    try {
      await user.updatePassword(newPassword);
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_arabicError(e.code));
    }
  }

  /// Starts changing the email: sends a confirmation link to the NEW email.
  /// The email only changes after the user opens that link (keeps the account safe).
  /// Firestore's copy of the email is updated automatically on the next login.
  Future<AuthResult> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return const AuthResult.failure('يرجى تسجيل الدخول أولًا');
    }
    try {
      await _reauthenticate(user, currentPassword);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_wrongCurrentPassword(e.code));
    }
    try {
      await _auth.setLanguageCode('ar');
      await user.verifyBeforeUpdateEmail(newEmail.trim());
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_arabicError(e.code));
    }
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  /// Reads users/{uid} from Firestore into the fields above.
  Future<void> _loadProfile(User user) async {
    final doc = _userDoc(user.uid);
    final snap = await doc.get();
    final data = snap.data();

    if (data == null) {
      // First time after verification (or profile missing): create it now.
      await doc.set({
        'displayName': user.displayName ?? '',
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'settings': {
          'ttsVoice': (_pendingVoice ?? HesakVoice.male).name,
          'speechRate': 1.0,
          'pitch': 1.0,
          'vibrationEnabled': true,
          'notificationsEnabled': true,
          'currentModeId': 'general',
        },
      });
    } else if (user.email != null && data['email'] != user.email) {
      // The email was changed with requestEmailChange: keep Firestore in sync.
      await doc.update({'email': user.email});
    }

    final settings = data?['settings'] as Map<String, dynamic>?;
    final nameRecognition = data?['nameRecognition'] as Map<String, dynamic>?;
    final names = nameRecognition?['names'] as List<dynamic>?;

    currentUserName = (data?['displayName'] as String?) ?? user.displayName;
    currentEmail = user.email;
    currentVoice = settings == null
        ? (_pendingVoice ?? HesakVoice.male)
        : (settings['ttsVoice'] == HesakVoice.female.name ? HesakVoice.female : HesakVoice.male);
    _pendingVoice = null;
    currentCallName =
    (names != null && names.isNotEmpty) ? names.first as String : null;
    notifyListeners();

    // فاتح / داكن saved in the account (follows the user to another phone).
    // Not saved yet -> keep the phone's current choice.
    final savedAppearance = settings?['appearance'];
    if (savedAppearance == HesakAppearance.dark.name) {
      HesakThemeController.instance.setAppearance(HesakAppearance.dark);
    } else if (savedAppearance == HesakAppearance.light.name) {
      HesakThemeController.instance.setAppearance(HesakAppearance.light);
    }
  }

  /// Checks the current password again (Firebase requires it before
  /// changing the password or the email).
  Future<void> _reauthenticate(User user, String currentPassword) {
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    return user.reauthenticateWithCredential(credential);
  }

  String _wrongCurrentPassword(String code) {
    if (code == 'wrong-password' || code == 'invalid-credential') {
      return 'كلمة المرور الحالية غير صحيحة';
    }
    return _arabicError(code);
  }

  /// Turns Firebase error codes into Arabic messages for the user.
  String _arabicError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مسجّل مسبقًا';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صحيح';
      case 'weak-password':
        return 'كلمة المرور ضعيفة، اختر كلمة أقوى';
      case 'password-does-not-meet-requirements':
        return 'كلمة المرور يجب أن تحتوي على 8 خانات على الأقل، وحرف إنجليزي كبير وصغير، ورقم، ورمز خاص';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      case 'user-disabled':
        return 'تم إيقاف هذا الحساب';
      case 'too-many-requests':
        return 'محاولات كثيرة، حاول مرة أخرى بعد قليل';
      case 'network-request-failed':
        return 'تحقق من اتصالك بالإنترنت';
      case 'expired-action-code':
      case 'invalid-action-code':
        return 'الرابط منتهي أو استُخدم من قبل، اطلب رابطًا جديدًا';
      case 'requires-recent-login':
        return 'يرجى تسجيل الدخول مرة أخرى ثم المحاولة';
      default:
        return 'حدث خطأ، حاول مرة أخرى';
    }
  }
}