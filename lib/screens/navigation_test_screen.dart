import 'package:flutter/material.dart';

import '../services/modes_service.dart';
import '../widgets/bottom_navigation_bar.dart';
import 'modes_screen.dart';

/// Isolated test screen for the bottom bar. Run/open this screen directly
/// while developing so you don't have to touch main.dart until it's ready.
class NavigationTestScreen extends StatefulWidget {
  const NavigationTestScreen({super.key});

  @override
  State<NavigationTestScreen> createState() => _NavigationTestScreenState();
}

class _NavigationTestScreenState extends State<NavigationTestScreen> {
  // One shared ModesService instance for the whole screen/tree below it.
  final ModesService _modesService = ModesService();
  int _tabIndex = 0;

  final List<String> _tabLabels = const [
    'الرئيسية',
    'المحادثات',
    'الوضع الحالي',
    'الأوضاع',
    'الإعدادات',
  ];

  void _openModesScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModesScreen(modesService: _modesService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(title: const Text('اختبار البار')),
        body: Center(
          child: Text(
            _tabLabels[_tabIndex],
            style: const TextStyle(fontSize: 20),
          ),
        ),
        bottomNavigationBar: BottomNavBar(
          modesService: _modesService,
          currentTabIndex: _tabIndex,
          onTabTapped: (index) {
            setState(() => _tabIndex = index);
            if (index == 3) _openModesScreen(); // Grid tab -> full modes screen
          },
          onAddModePressed:
              _openModesScreen, // "+" in radial -> modes screen for now
        ),
      ),
    );
  }
}
