import 'package:flutter/material.dart';
import '../core/data/hesak_mode_store.dart';
import '../core/theme/hesak_colors.dart';
import '../services/auth_service.dart';
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
//  - Passing the user's modes (from HesakModeStore) to the middle button.
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

  // The user's modes + the active one live in HesakModeStore
  // (lib/core/data/hesak_mode_store.dart), shared with the الأوضاع page.
  final HesakModeStore _modeStore = HesakModeStore.instance;

  // The user's name, shown in the home greeting.
  // It's the name typed in "إنشاء حساب" (saved in AuthService).
  // Empty when we don't know it yet (e.g. after login, until the server is connected).
  final String _userName = AuthService.instance.currentUserName ?? '';

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
        children: [
          HomeScreen(userName: _userName),
          const ChatsScreen(),
          // isActive: the phone back button only goes back inside الأوضاع while it's shown.
          ModesScreen(isActive: _selectedTab == HesakNavTab.modes),
          const SettingsScreen(),
        ],
      ),

      // Rebuilds the bar when the modes change (e.g. a mode is starred on the الأوضاع page).
      bottomNavigationBar: ListenableBuilder(
        listenable: _modeStore,
        builder: (context, _) => HesakBottomNavBar(
          // Tabs: tapping one opens its page.
          selectedTab: _selectedTab,
          onTabSelected: (tab) {
            setState(() {
              _selectedTab = tab;
            });
          },

          // Mode wheel: ONLY the starred modes (الأوضاع المفضلة).
          // The middle button always shows the active mode's icon, even if it isn't starred.
          modes: _modeStore.wheelOptions,
          selectedModeId: _modeStore.selectedModeId,
          activeModeIcon: _modeStore.selectedMode.icon,
          activeModeLetter: _modeStore.selectedMode.toOption().letter, // Mode without an icon
          onModeSelected: _modeStore.selectMode,
          onAddModeTap: () {
            // "إضافة" -> go to the الأوضاع tab and open the add-mode page.
            setState(() {
              _selectedTab = HesakNavTab.modes;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) => ModesScreen.openAddModePage());
          },
        ),
      ),
    );
  }
}
