import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'screens/navigation_test_screen.dart';

void main() {
  runApp(const HesakApp());
}

class HesakApp extends StatelessWidget {
  const HesakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hesak',
      //home: const SplashScreen(),
      home: const NavigationTestScreen(),
    );
  }
}
