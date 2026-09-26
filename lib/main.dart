import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/splash_screen.dart';

/// App entry point: the first thing that runs when the app opens.
void main() {
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