import 'dart:async';

import 'package:flutter/material.dart';
import '../core/data/hesak_connection.dart';
import '../core/data/hesak_mode_store.dart';
import '../core/theme/hesak_colors.dart';
import '../core/theme/hesak_palette.dart';
import '../services/auth_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/hesak_confirm_dialog.dart';
import '../widgets/hesak_toast.dart';
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
//  - Showing the message when the schedule switches the mode, and checking
//    the schedule again when the app comes back from the background.
//  - Watching the internet: if it drops while listening, listening turns
//    off and a window says so (on any page, even inside a conversation).
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

class _HesakMainShellState extends State<HesakMainShell> with WidgetsBindingObserver {
  // The page that is open now (starts on الرئيسية).
  HesakNavTab _selectedTab = HesakNavTab.home;

  // الرئيسية has its own navigator (like الأوضاع), so تعديل الوضع (the pencil on
  // the mode card) opens INSIDE the tab: the bottom bar stays, back returns here.
  final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home_navigator');

  // The user's modes + the active one live in HesakModeStore
  // (lib/core/data/hesak_mode_store.dart), shared with the الأوضاع page.
  final HesakModeStore _modeStore = HesakModeStore.instance;

  // "تم التبديل إلى وضع النوم حسب الجدولة" messages from the store.
  StreamSubscription<String>? _scheduleMessagesSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMessagesSubscription = _modeStore.scheduleMessages.listen((message) {
      // After the frame, so it never shows in the middle of a build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showHesakToast(context, message, icon: Icons.schedule_rounded);
      });
    });
    _modeStore.checkSchedule(isAppStart: true);
    HesakConnection.instance
      ..start()
      ..addListener(_handleConnectionChanged);
  }

  /// Internet dropped while listening -> stop listening + tell the user.
  void _handleConnectionChanged() {
    if (HesakConnection.instance.isOnline || !_modeStore.isListening) return;
    _modeStore.setListening(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showHesakNoticeDialog(
        context,
        title: 'انقطع الاتصال بالإنترنت',
        message: 'تم إيقاف الاستماع، شغّل الإنترنت ثم اضغط زر الاستماع مرة أخرى',
        icon: Icons.wifi_off_rounded,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HesakConnection.instance.removeListener(_handleConnectionChanged);
    _scheduleMessagesSubscription?.cancel();
    super.dispose();
  }

  // Back from the background -> a period may have started or ended meanwhile.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _modeStore.checkSchedule();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Light lavender behind every tab (same as the end of الرئيسية).
      backgroundColor: HesakColors.tabPageBackground,

      // Lets the pages draw behind the bottom bar, so the transparent area
      // above the bar (used by the mode wheel) doesn't cover the screen.
      extendBody: true,

      // IndexedStack shows ONE page at a time, but keeps the others alive,
      // so a page doesn't reset when you switch tabs and come back.
      // The order here must match HesakNavTab: home, chats, modes, settings.
      body: IndexedStack(
        index: _selectedTab.index,
        children: [
          // Home greeting uses the user's name from AuthService, and updates
          // when it changes in الإعدادات. Empty = unknown (e.g. after login, for now).
          // Phone back button: go back inside the tab first (e.g. from تعديل الوضع).
          NavigatorPopHandler(
            enabled: _selectedTab == HesakNavTab.home,
            onPop: () => _homeNavigatorKey.currentState?.maybePop(),
            child: Navigator(
              key: _homeNavigatorKey,
              onGenerateRoute: (settings) => MaterialPageRoute(
                settings: settings,
                builder: (_) => ListenableBuilder(
                  listenable: AuthService.instance,
                  builder: (context, _) => HomeScreen(
                    userName: AuthService.instance.currentUserName ?? '',
                    // "عرض الكل" on the conversations card -> المحادثات tab.
                    onShowAllChats: () => setState(() => _selectedTab = HesakNavTab.chats),
                  ),
                ),
              ),
            ),
          ),
          ChatsScreen(),
          // isActive: the phone back button only goes back inside الأوضاع while it's shown.
          ModesScreen(isActive: _selectedTab == HesakNavTab.modes),
          SettingsScreen(isActive: _selectedTab == HesakNavTab.settings),
        ],
      ),

      // Rebuilds the bar when the modes change (e.g. a mode is starred on the الأوضاع page).
      // Also rebuilds when the appearance (فاتح / داكن) changes.
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([_modeStore, HesakThemeController.instance]),
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
          // Middle button pulses while listening is on (الرئيسية).
          isListening: _modeStore.isListening,
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