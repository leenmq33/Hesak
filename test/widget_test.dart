import 'package:flutter_test/flutter_test.dart';
import 'package:hesak/main.dart';

// =====================================================================
//  Basic app test: the app opens without errors and shows the splash.
//  Run it with:  flutter test
// =====================================================================

void main() {
  testWidgets(
    'App opens on the splash screen, then goes to the welcome screen',
    (tester) async {
      // Open the app.
      await tester.pumpWidget(const HesakApp());

      // The splash tagline is on screen.
      expect(find.text('لأن ما لا يُسمع يَستحق أن يُدرك'), findsOneWidget);

      // Wait for the splash (5 seconds) + the fade to the welcome screen,
      // then let the welcome buttons appear (so no timer is left running).
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 1));

      // The two welcome buttons are there.
      expect(find.text('إنشاء حساب'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
    },
  );
}
