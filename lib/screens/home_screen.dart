import 'package:flutter/material.dart';
import '../core/theme/hesak_colors.dart';
import '../core/theme/hesak_sizes.dart';
import '../core/theme/hesak_text_styles.dart';
import '../widgets/hesak_page_header.dart';

// =====================================================================
//  HOME PAGE (الرئيسية)
//
//  NAMING RULES used in this file (so team files never clash):
//  - Everything that belongs to this page starts with "Home"
//    (_HomeListenButton, _HomeAlertsCard ...).
//  - Names say exactly what the thing is (_listenPulseController,
//    not _controller).
//  - Important widgets have a unique Key: 'home_<name>'.
//  - Colors / text styles / sizes come ONLY from lib/core/theme.
//
//  This page does NOT build the bottom bar — HesakMainShell does that
//  (lib/screens/main_shell.dart). This file is only the page content.
// =====================================================================

/// The home page: shared header with the greeting, then the home content.
class HomeScreen extends StatelessWidget {
  /// The user's name shown in the greeting ("مرحبًا, رحاب !").
  final String userName;

  const HomeScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false, // The bottom bar handles the bottom edge
      child: Column(
        children: [
          // Shared header: logo + waves + greeting on the right + divider.
          HesakPageHeader.greeting(text: 'مرحبًا, $userName !'),

          // Everything under the header (scrollable).
          const Expanded(child: _HomeTabContent()),
        ],
      ),
    );
  }
}

// =====================================================================
//                         HOME TAB CONTENT
// =====================================================================

/// Everything under the header on the home tab:
/// listen button, current sounds card, alerts card.
/// Scrollable so it works on small screens.
class _HomeTabContent extends StatelessWidget {
  const _HomeTabContent();

  @override
  Widget build(BuildContext context) {
    // Force right-to-left for the Arabic content.
    return const Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        // Bottom space keeps the last card above the floating nav bar.
        padding: EdgeInsets.fromLTRB(
          HesakSizes.pagePadding,
          20,
          HesakSizes.pagePadding,
          HesakSizes.pageBottomSafeSpace,
        ),
        child: Column(
          children: [
            _HomeListenButton(),
            SizedBox(height: 26),
            _HomeCurrentSoundsCard(),
            SizedBox(height: HesakSizes.sectionGap),
            _HomeAlertsCard(),
          ],
        ),
      ),
    );
  }
}

/// The big round mic button.
/// Tap once: starts "listening" — the button pulses (grows/shrinks)
/// and soft rings spread out from it, like a recording.
/// Tap again: stops.
class _HomeListenButton extends StatefulWidget {
  const _HomeListenButton();

  @override
  State<_HomeListenButton> createState() => _HomeListenButtonState();
}

class _HomeListenButtonState extends State<_HomeListenButton>
    with TickerProviderStateMixin {
  bool _isListening = false;

  // Makes the button grow and shrink (the "breathing" effect).
  late final AnimationController _listenPulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  // Drives the rings that spread out from the button.
  late final AnimationController _listenRingsController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void dispose() {
    _listenPulseController.dispose();
    _listenRingsController.dispose();
    super.dispose();
  }

  /// Start or stop the listening animation.
  void _toggleListening() {
    setState(() => _isListening = !_isListening);

    if (_isListening) {
      _listenPulseController.repeat(reverse: true); // grow -> shrink -> grow ...
      _listenRingsController.repeat(); // rings keep spreading
    } else {
      _listenPulseController.animateTo(0, duration: const Duration(milliseconds: 200)); // back to normal size
      _listenRingsController.stop();
      _listenRingsController.reset();
    }

    // TODO: start / stop the real microphone listening here.
  }

  @override
  Widget build(BuildContext context) {
    const double buttonSize = 170; // Button diameter
    const double ringsAreaSize = 250; // Space around it for the rings

    return Column(
      children: [
        SizedBox(
          width: ringsAreaSize,
          height: ringsAreaSize,
          child: AnimatedBuilder(
            animation: Listenable.merge([_listenPulseController, _listenRingsController]),
            builder: (context, _) {
              // Scale goes 1.0 -> 1.07 while listening.
              final pulseScale = 1 + 0.07 * Curves.easeInOut.transform(_listenPulseController.value);

              return Stack(
                alignment: Alignment.center,
                children: [
                  // 3 rings, each starting at a different time so they flow one after another.
                  if (_isListening)
                    for (int i = 0; i < 3; i++) _buildListenRing(buttonSize, ringsAreaSize, i),

                  // The button itself.
                  Transform.scale(
                    scale: pulseScale,
                    child: GestureDetector(
                      key: const Key('home_listen_button'),
                      onTap: _toggleListening,
                      child: Container(
                        width: buttonSize,
                        height: buttonSize,
                        decoration: BoxDecoration(
                          color: HesakColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: HesakColors.primary.withOpacity(_isListening ? 0.45 : 0.25),
                              blurRadius: _isListening ? 30 : 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mic_none_rounded,
                          color: HesakColors.onPrimary,
                          size: 70,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 4),

        // Text under the button changes with the state (with a soft fade).
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            _isListening ? 'جارٍ الاستماع...' : 'اضغط للاستماع',
            key: ValueKey(_isListening), // Tells the switcher the text changed
            style: HesakTextStyles.actionLabel,
          ),
        ),
      ],
    );
  }

  /// One spreading ring.
  /// [i] shifts its timing so the 3 rings don't overlap.
  Widget _buildListenRing(double buttonSize, double ringsAreaSize, int i) {
    // progress: 0 = just born at the button edge, 1 = fully spread and invisible.
    final progress = (_listenRingsController.value + i / 3) % 1.0;
    final ringSize = buttonSize + (ringsAreaSize - buttonSize) * progress;

    return Container(
      width: ringSize,
      height: ringSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HesakColors.primary.withOpacity(0.12 * (1 - progress)), // Fades as it grows
        border: Border.all(
          color: HesakColors.primary.withOpacity(0.35 * (1 - progress)),
          width: 1.5,
        ),
      ),
    );
  }
}

/// White rounded card with a title at the top.
/// Used by both "current sounds" and "alerts".
class _HomeSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _HomeSectionCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        HesakSizes.cardPaddingHorizontal,
        HesakSizes.cardPaddingTop,
        HesakSizes.cardPaddingHorizontal,
        HesakSizes.cardPaddingBottom,
      ),
      decoration: BoxDecoration(
        color: HesakColors.surface,
        borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
        border: Border.all(color: HesakColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: HesakColors.primary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // "start" = right side in RTL
        children: [
          Text(title, style: HesakTextStyles.cardTitle),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Card 1: sounds the app is currently detecting, shown as chips.
class _HomeCurrentSoundsCard extends StatelessWidget {
  const _HomeCurrentSoundsCard();

  @override
  Widget build(BuildContext context) {
    return const _HomeSectionCard(
      key: Key('home_current_sounds_card'),
      title: 'الأصوات الحالية',
      // Wrap moves chips to the next line when there's no room.
      child: Wrap(
        spacing: 8, // Horizontal gap between chips
        runSpacing: 8, // Vertical gap between rows
        children: [
          _HomeSoundChip(label: 'صوت إسعاف', icon: Icons.medical_services_outlined),
          _HomeSoundChip(label: 'صوت دق الباب', icon: Icons.door_front_door_outlined),
          _HomeSoundChip(label: 'صوت منبه', icon: Icons.alarm_rounded),
        ],
      ),
    );
  }
}

/// One light-purple pill with a label and an icon.
class _HomeSoundChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _HomeSoundChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: HesakColors.primaryLight,
        borderRadius: BorderRadius.circular(HesakSizes.radiusChip),
        border: Border.all(color: HesakColors.primaryLightBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Chip is only as wide as its content
        children: [
          Text(label, style: HesakTextStyles.chipLabel),
          const SizedBox(width: 6),
          Icon(icon, size: HesakSizes.iconInChip, color: HesakColors.primary),
        ],
      ),
    );
  }
}

/// Card 2: list of recent alerts, separated by thin lines.
class _HomeAlertsCard extends StatelessWidget {
  const _HomeAlertsCard();

  @override
  Widget build(BuildContext context) {
    return const _HomeSectionCard(
      key: Key('home_alerts_card'),
      title: 'التنبيهات',
      child: Column(
        children: [
          _HomeAlertTile(
            icon: Icons.warning_amber_rounded,
            title: 'إنذار',
            subtitle: 'تم رصد صوت إنذار',
            time: 'الآن',
            isNew: true, // "Now" is shown in red
          ),
          Divider(height: 16, thickness: 0.8, color: HesakColors.listDivider),
          _HomeAlertTile(
            icon: Icons.child_care_outlined,
            title: 'بكاء طفل',
            subtitle: 'تم رصد صوت بكاء طفل',
            time: 'منذ ساعة',
          ),
          Divider(height: 16, thickness: 0.8, color: HesakColors.listDivider),
          _HomeAlertTile(
            icon: Icons.child_care_outlined,
            title: 'بكاء طفل',
            subtitle: 'تم رصد صوت بكاء طفل',
            time: 'منذ ساعة',
          ),
          Divider(height: 16, thickness: 0.8, color: HesakColors.listDivider),
          _HomeAlertTile(
            icon: Icons.child_care_outlined,
            title: 'بكاء طفل',
            subtitle: 'تم رصد صوت بكاء طفل',
            time: 'منذ ساعة',
          ),
        ],
      ),
    );
  }
}

/// One alert row: icon box on the right, title + subtitle, time on the left.
class _HomeAlertTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final bool isNew; // New alerts show their time in red

  const _HomeAlertTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Rounded square with the alert icon.
        Container(
          width: HesakSizes.iconBox,
          height: HesakSizes.iconBox,
          decoration: BoxDecoration(
            color: HesakColors.primaryLight,
            borderRadius: BorderRadius.circular(HesakSizes.radiusIconBox),
          ),
          child: Icon(icon, size: HesakSizes.iconInBox, color: HesakColors.primary),
        ),
        const SizedBox(width: 12),

        // Title and subtitle take all the remaining space.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: HesakTextStyles.itemTitle),
              const SizedBox(height: 2),
              Text(subtitle, style: HesakTextStyles.body),
            ],
          ),
        ),

        // Time on the far side (red when the alert is new).
        Text(
          time,
          style: isNew ? HesakTextStyles.captionUrgent : HesakTextStyles.caption,
        ),
      ],
    );
  }
}
