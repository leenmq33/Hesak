import 'package:flutter/material.dart';
import 'bottom_nav_bar.dart' show HesakNavTab;

// =====================================================================
//  TAB SCROLL — tapping the tab you are ALREADY on takes its page back
//  to the top (like most apps).
//
//  Each tab page gives its main scroll view the controller from
//  HesakTabScroll.controllerFor(tab). HesakMainShell calls
//  HesakTabScroll.scrollToTop(tab) when the open tab is tapped again.
//
//  Only the first page of each tab scrolls up. An inner page (e.g.
//  تغيير كلمة المرور, تعديل الوضع) stays open as it is.
// =====================================================================

/// One scroll controller per tab + "back to the top".
class HesakTabScroll {
  HesakTabScroll._(); // Use HesakTabScroll.xxx directly

  static final Map<HesakNavTab, ScrollController> _controllers = <HesakNavTab, ScrollController>{};

  /// The controller for [tab]'s main scroll view (same one every time).
  static ScrollController controllerFor(HesakNavTab tab) =>
      _controllers.putIfAbsent(tab, () => ScrollController(debugLabel: 'tab_${tab.name}'));

  /// Smoothly scrolls [tab]'s page back to the top (does nothing if it's not on screen).
  static void scrollToTop(HesakNavTab tab) {
    final ScrollController? controller = _controllers[tab];
    if (controller == null || !controller.hasClients) return;
    // A controller can be attached to only one scroll view; if a page shows it
    // twice for a moment (a page animation), scroll each of them.
    for (final ScrollPosition position in controller.positions.toList()) {
      if (position.pixels <= position.minScrollExtent) continue;
      position.animateTo(
        position.minScrollExtent,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }
}
