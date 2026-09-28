import 'package:flutter/material.dart';
import '../core/theme/hesak_palette.dart';
import '../core/theme/hesak_sizes.dart';
import '../core/theme/hesak_text_styles.dart';
import '../services/auth_service.dart';
import '../widgets/hesak_page_header.dart';
import 'auth/auth_flow_screen.dart';
import 'settings/settings_email_screen.dart';
import 'settings/settings_password_screen.dart';
import 'settings/settings_widgets.dart';

// =====================================================================
//  SETTINGS PAGE (الإعدادات) — the tab in the bottom bar.
//
//  The tab has its OWN navigator, so the inner pages (تغيير كلمة المرور,
//  البريد الإلكتروني) open INSIDE the tab and the bottom bar stays visible.
//
//  Sections:
//   الحساب:          الاسم (sheet) · البريد الإلكتروني (page) · تغيير كلمة المرور (page)
//   التفضيلات:        الصوت (ذكر / أنثى) · المظهر (فاتح / داكن)
//   للتنبيه عند النداء: الاسم للنداء (sheet — add or edit)
//   تسجيل الخروج (asks first)
//
//  Every change has its own "حفظ" (faded until something really changes),
//  so there's no big "حفظ التعديلات" button. الصوت / المظهر save right away.
//
//  This page (and the bottom bar) follows the appearance فاتح / داكن
//  (TRIAL — the other pages stay light for now). See hesak_palette.dart.
//
//  NAMING: everything here starts with "Settings". Keys: 'settings_<name>'.
//  This page does NOT build the bottom bar — HesakMainShell does that.
// =====================================================================

class SettingsScreen extends StatelessWidget {
  /// true while the الإعدادات tab is on screen. The phone back button
  /// only goes back inside this tab while it's shown.
  final bool isActive;

  const SettingsScreen({super.key, this.isActive = true});

  /// The navigator of this tab (inner pages open here, under the bottom bar).
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'settings_navigator');

  @override
  Widget build(BuildContext context) {
    // Phone back button: go back inside the tab first (e.g. from تغيير كلمة المرور).
    return NavigatorPopHandler(
      enabled: isActive,
      onPop: () => navigatorKey.currentState?.maybePop(),
      child: Navigator(
        key: navigatorKey,
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => const _SettingsHomePage(),
        ),
      ),
    );
  }
}

/// The first page of the tab. Rebuilds when the user's info or the appearance changes.
class _SettingsHomePage extends StatelessWidget {
  const _SettingsHomePage();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AuthService.instance, HesakThemeController.instance]),
      builder: (context, _) {
        final palette = HesakPalette.current;
        return Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            bottom: false, // The bottom bar handles the bottom edge
            child: Column(
              children: [
                // Shared Hesak header (follows فاتح / داكن on this page).
                const HesakPageHeader(title: 'الإعدادات', followsAppearance: true),
                Expanded(child: _SettingsPageContent(auth: AuthService.instance)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Everything under the header.
class _SettingsPageContent extends StatelessWidget {
  final AuthService auth;

  const _SettingsPageContent({required this.auth});

  @override
  Widget build(BuildContext context) {
    final palette = HesakPalette.current;
    final theme = HesakThemeController.instance;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          HesakSizes.pagePadding, 0, HesakSizes.pagePadding, HesakSizes.pageBottomSafeSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------------- الحساب ----------------
          const SettingsSectionTitle('الحساب'),
          SettingsCard(
            children: [
              SettingsRow(
                key: const Key('settings_name_row'),
                icon: Icons.person_outline_rounded,
                title: 'الاسم',
                value: auth.currentUserName ?? 'غير محدد',
                onTap: () => _editName(context),
              ),
              SettingsRow(
                key: const Key('settings_email_row'),
                icon: Icons.mail_outline_rounded,
                title: 'البريد الإلكتروني',
                value: auth.currentEmail ?? 'غير محدد',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsEmailScreen()),
                ),
              ),
              SettingsRow(
                key: const Key('settings_password_row'),
                icon: Icons.lock_outline_rounded,
                title: 'تغيير كلمة المرور',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPasswordScreen()),
                ),
              ),
            ],
          ),

          // ---------------- التفضيلات ----------------
          const SettingsSectionTitle('التفضيلات'),
          // Same note as in إنشاء حساب.
          const SettingsNote('سيستخدم حسّك هذا الصوت لقراءة النصوص بصوت مسموع'),
          const SizedBox(height: 10),
          SettingsCard(
            children: [
              SettingsRow(
                key: const Key('settings_voice_row'),
                icon: Icons.record_voice_over_outlined,
                title: 'الصوت',
                trailing: SettingsSegmented<HesakVoice>(
                  keyPrefix: 'settings_voice',
                  values: HesakVoice.values,
                  selected: auth.currentVoice,
                  labelOf: (voice) => voice == HesakVoice.male ? 'ذكر' : 'أنثى',
                  onChanged: (voice) {
                    if (voice == auth.currentVoice) return;
                    auth.updateVoice(voice);
                    showSettingsToast(context, 'تم تغيير الصوت');
                  },
                ),
              ),
              SettingsRow(
                key: const Key('settings_appearance_row'),
                icon: Icons.contrast_rounded,
                title: 'المظهر',
                trailing: SettingsSegmented<HesakAppearance>(
                  keyPrefix: 'settings_appearance',
                  values: HesakAppearance.values,
                  selected: theme.appearance,
                  labelOf: (appearance) => appearance == HesakAppearance.light ? 'فاتح' : 'داكن',
                  iconOf: (appearance) =>
                      appearance == HesakAppearance.light ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                  onChanged: theme.setAppearance,
                ),
              ),
            ],
          ),

          // ---------------- للتنبيه عند النداء ----------------
          const SettingsSectionTitle('للتنبيه عند النداء'),
          SettingsCard(
            children: [
              SettingsRow(
                key: const Key('settings_call_name_row'),
                icon: Icons.campaign_outlined,
                title: 'الاسم للنداء',
                value: auth.currentCallName ?? 'لم تتم إضافته بعد',
                // Not added yet: "+ إضافة" pill. Added: normal forward arrow (edit).
                trailing: auth.currentCallName == null ? _addPill(palette) : null,
                onTap: () => _editCallName(context),
              ),
            ],
          ),

          // ---------------- تسجيل الخروج ----------------
          const SizedBox(height: 24),
          SettingsButton(
            key: const Key('settings_logout_button'),
            label: 'تسجيل الخروج',
            icon: Icons.logout_rounded,
            isFilled: false,
            color: palette.danger,
            height: 48,
            onTap: () => _logOut(context),
          ),
        ],
      ),
    );
  }

  /// Small outlined "+ إضافة" pill.
  Widget _addPill(HesakPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.accent, width: 1.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, size: 15, color: palette.accent),
          const SizedBox(width: 2),
          Text('إضافة', style: HesakTextStyles.modeChipSelected.copyWith(color: palette.accent)),
        ],
      ),
    );
  }

  // ---- Actions ----

  void _editName(BuildContext context) {
    showSettingsNameSheet(
      context,
      title: 'الاسم',
      note: null,
      fieldLabel: 'الاسم:',
      hint: 'اكتب اسمك بالعربي',
      initialValue: auth.currentUserName ?? '',
      onSave: (name) async {
        final result = await auth.updateName(name: name);
        if (!context.mounted) return false;
        if (result.isSuccess) showSettingsToast(context, 'تم تغيير الاسم');
        return result.isSuccess;
      },
    );
  }

  void _editCallName(BuildContext context) {
    final bool isNew = auth.currentCallName == null;
    showSettingsNameSheet(
      context,
      title: 'الاسم للنداء',
      note: 'سيُنبّهك حسّك عند سماع هذا الاسم',
      fieldLabel: 'الاسم:',
      hint: 'اكتب الاسم بالعربي',
      initialValue: auth.currentCallName ?? '',
      onSave: (callName) async {
        final result = await auth.saveCallName(callName: callName);
        if (!context.mounted) return false;
        if (result.isSuccess) showSettingsToast(context, isNew ? 'تمت إضافة الاسم للنداء' : 'تم تعديل الاسم للنداء');
        return result.isSuccess;
      },
    );
  }

  Future<void> _logOut(BuildContext context) async {
    final bool isConfirmed = await showSettingsConfirmDialog(
      context,
      title: 'تسجيل الخروج؟',
      message: 'ستحتاج إلى تسجيل الدخول مرة أخرى\nلاستخدام حسّك.',
      confirmLabel: 'تسجيل الخروج',
      icon: Icons.logout_rounded,
    );
    if (!isConfirmed || !context.mounted) return;
    await AuthService.instance.logOut();
    if (!context.mounted) return;
    // Back to the welcome screen, and remove everything behind it (no going back).
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const HesakAuthFlowScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      ),
      (_) => false,
    );
  }
}
