import 'package:flutter/material.dart';
import '../core/data/hesak_modes.dart';
import '../core/theme/hesak_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import 'chats_screen.dart';
import 'home_screen.dart';
import 'modes_screen.dart';
import 'settings_screen.dart';

// =====================================================================
//  MAIN SHELL — the frame around the 4 pages.
//
//  It owns:
//  - The page background and the bottom bar (HesakBottomNavBar).
//  - Which page is open (tapping a tab switches the page).
//  - The active mode (العام / النوم / السيارة) from the middle button.
//
//  Each page lives in its own file, so each teammate can work on one page
//  without touching the others:
//    الرئيسية  -> home_screen.dart
//    المحادثات -> chats_screen.dart
//    الأوضاع   -> modes_screen.dart
//    الإعدادات -> settings_screen.dart
// =====================================================================

/// The app's main screen after the splash: 4 pages + the bottom bar.
class HesakMainShell extends StatefulWidget {
  const HesakMainShell({super.key});

  @override
  State<HesakMainShell> createState() => _HesakMainShellState();
}

class _HesakMainShellState extends State<HesakMainShell> {
  // The page that is open now (starts on الرئيسية).
  HesakNavTab _selectedTab = HesakNavTab.home;

  // The active listening mode (starts on العام).
  String _selectedModeId = HesakModeIds.general;

  // The user's name, shown in the home greeting.
  // TODO: take it from the user's account / settings.
  static const String _userName = 'رحاب';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HesakColors.background,

      // Lets the pages draw behind the bottom bar, so the transparent area
      // above the bar (used by the mode wheel) doesn't cover the screen.
      extendBody: true,

      // IndexedStack shows ONE page at a time, but keeps the others alive,
      // so a page doesn't reset when you switch tabs and come back.
      // The order here must match HesakNavTab: home, chats, modes, settings.
      body: IndexedStack(
        index: _selectedTab.index,
        children: const [
          HomeScreen(userName: _userName),
          ChatsScreen(),
          ModesScreen(),
          SettingsScreen(),
        ],
      ),

      bottomNavigationBar: HesakBottomNavBar(
        // Tabs: tapping one opens its page.
        selectedTab: _selectedTab,
        onTabSelected: (tab) {
          setState(() {
            _selectedTab = tab;
          });
        },

        // Mode wheel (middle button).
        modes: hesakDefaultModes,
        selectedModeId: _selectedModeId,
        onModeSelected: (modeId) {
          setState(() {
            _selectedModeId = modeId;
          });
          // TODO: apply the mode's listening settings here.
        },
        onAddModeTap: () {
          // "إضافة" -> open the modes page for now.
          // TODO: open an "add new mode" screen instead, when it's ready.
          setState(() {
            _selectedTab = HesakNavTab.modes;
          });
        },
      ),
    );
  }
}
