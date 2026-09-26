import 'package:flutter/material.dart';
import '../core/theme/hesak_colors.dart';
import '../core/theme/hesak_sizes.dart';
import '../core/theme/hesak_text_styles.dart';
import '../widgets/hesak_page_header.dart';

// =====================================================================
//  SETTINGS PAGE (الإعدادات)
//
//  NAMING RULES used in this file (so team files never clash):
//  - Everything that belongs to this page starts with "Settings"
//    (e.g. _SettingsSearchBar, _SettingsListItem).
//  - Important widgets have a unique Key: 'settings_<name>'.
//  - Colors / text styles / sizes come ONLY from lib/core/theme.
//
//  This page does NOT build the bottom bar — HesakMainShell does that
//  (lib/screens/main_shell.dart). This file is only the page content.
// =====================================================================

/// The الإعدادات page: shared header with the title, then the page content.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      bottom: false, // The bottom bar handles the bottom edge
      child: Column(
        children: [
          // Shared header: logo + waves + page title + divider.
          HesakPageHeader(title: 'الإعدادات'),

          // Everything under the header.
          Expanded(child: _SettingsPageContent()),
        ],
      ),
    );
  }
}

/// The page content. Replace the placeholder below with the real design.
class _SettingsPageContent extends StatelessWidget {
  const _SettingsPageContent();

  @override
  Widget build(BuildContext context) {
    // Force right-to-left for the Arabic content.
    return const Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        // Bottom space keeps the content above the bottom bar.
        padding: EdgeInsets.fromLTRB(
          HesakSizes.pagePadding,
          20,
          HesakSizes.pagePadding,
          HesakSizes.pageBottomSafeSpace,
        ),
        child: Column(
          children: [
            // TODO: build the الإعدادات page here.
            SizedBox(height: 60),
            Icon(Icons.settings_outlined, size: 48, color: HesakColors.iconInactive, key: Key('settings_placeholder_icon')),
            SizedBox(height: 12),
            Text('صفحة الإعدادات — قيد العمل', style: HesakTextStyles.cardTitle),
          ],
        ),
      ),
    );
  }
}
