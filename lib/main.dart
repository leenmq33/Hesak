import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/hesak_palette.dart';
import 'screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

/// App entry point: the first thing that runs when the app opens.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // فاتح / داكن: the last choice on this phone (before anything shows).
  await HesakThemeController.instance.loadFromPhone();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const HesakApp());
}

/// The whole app: global settings + the first screen.
/// Shared file — don't edit without telling the team.
class HesakApp extends StatelessWidget {
  const HesakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Hide the red "DEBUG" banner
      title: 'Hesak', // App name in the recent-apps list

      // ---- فاتح / داكن (chosen in الإعدادات) ----
      // Our screens use HesakColors (light or dark by itself); this only makes
      // Flutter's own parts (default text, cursor, ripples ...) match.
      theme: ThemeData(brightness: Brightness.light),
      darkTheme: ThemeData(brightness: Brightness.dark),
      themeMode: HesakThemeController.instance.isDark ? ThemeMode.dark : ThemeMode.light,

      // ---- Arabic for the whole app ----
      // Every page is right-to-left automatically, and built-in texts
      // (like date pickers or "copy/paste") appear in Arabic.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const SplashScreen(), // First screen: splash -> main shell
    );
  }
}