import 'dart:math';

import 'package:flutter/material.dart';

import '../services/modes_service.dart';
import '../models/app_mode.dart';

// TODO: replace these with your real lib/core/theme/app_colors.dart values
// e.g. import '../core/theme/app_colors.dart'; and use AppColors.primary, etc.
class _BarColors {
  static const Color primary = Color(0xFF6B4E8E);
  static const Color primaryLight = Color(0xFFE9E1F2);
  static const Color barBackground = Color(0xFFF7F4FA);
}

/// Bottom navigation bar with 5 slots:
/// [Home] [Chat] [Middle mode button] [Grid -> modes list] [Settings]
///
/// The middle button is raised above the bar (the "arch" look) and always
/// shows the icon of the CURRENTLY ACTIVE mode. Tapping it opens a small
/// half-circle radial menu with:
///   - up to 2 favorite modes (picked by the user from the modes list screen)
///   - a "+" button that navigates to the "add mode" flow
///
/// The Grid button is a normal tab: tapping it navigates straight to the
/// full modes list screen (no popup).
class BottomNavBar extends StatefulWidget {
  final ModesService modesService;

  // 0 = home, 1 = chat, 2 = middle/mode, 3 = grid, 4 = settings
  final int currentTabIndex;
  final ValueChanged<int> onTabTapped;

  // Called when the user taps the "+" inside the radial menu
  final VoidCallback onAddModePressed;

  const BottomNavBar({
    super.key,
    required this.modesService,
    required this.currentTabIndex,
    required this.onTabTapped,
    required this.onAddModePressed,
  });

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar>
    with SingleTickerProviderStateMixin {
  bool _isRadialOpen = false;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleRadial() {
    setState(() => _isRadialOpen = !_isRadialOpen);
    _isRadialOpen ? _animController.forward() : _animController.reverse();
  }

  void _selectMode(String id) {
    widget.modesService.setCurrentMode(id);
    _toggleRadial();
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder rebuilds whenever ModesService calls notifyListeners()
    return AnimatedBuilder(
      animation: widget.modesService,
      builder: (context, _) {
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [_buildBar(), if (_isRadialOpen) _buildRadialMenu()],
        );
      },
    );
  }

  Widget _buildBar() {
    return Container(
      height: 68,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: _BarColors.barBackground,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _flatIcon(Icons.home_rounded, 0),
          _flatIcon(Icons.chat_bubble_outline_rounded, 1),
          _middleModeButton(), // the raised "arch" button
          _flatIcon(
            Icons.grid_view_rounded,
            3,
            onTap: () => widget.onTabTapped(3),
          ),
          _flatIcon(Icons.settings_outlined, 4),
        ],
      ),
    );
  }

  Widget _flatIcon(IconData icon, int index, {VoidCallback? onTap}) {
    final isActive = widget.currentTabIndex == index;
    return GestureDetector(
      onTap: onTap ?? () => widget.onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? _BarColors.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : _BarColors.primary.withOpacity(0.6),
        ),
      ),
    );
  }

  /// The raised middle button: shows the current mode's icon, sits slightly
  /// above the bar with a ring border to create the "docked/arched" look
  /// (this is the simplest reliable way to do it without a fragile custom
  /// notch-clip path — feel free to swap for a real notched shape later).
  Widget _middleModeButton() {
    final mode = widget.modesService.currentMode;
    final isOpen = _isRadialOpen;
    return GestureDetector(
      onTap: _toggleRadial,
      child: Transform.translate(
        offset: const Offset(0, -16),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOpen ? _BarColors.primary : _BarColors.primary,
            border: Border.all(color: _BarColors.barBackground, width: 5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10),
            ],
          ),
          child: Icon(mode.icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  /// Half-circle popup above the middle button: favorites (max 2) + "add" button
  Widget _buildRadialMenu() {
    final favorites = widget.modesService.favoriteModes;
    final items = <_RadialItem>[
      ...favorites.map(
        (m) => _RadialItem(
          icon: m.icon,
          label: m.name,
          isActive: m.id == widget.modesService.currentModeId,
          onTap: () => _selectMode(m.id),
        ),
      ),
      _RadialItem(
        icon: Icons.add,
        label: 'إضافة',
        isActive: false,
        onTap: () {
          _toggleRadial();
          widget.onAddModePressed();
        },
      ),
    ];

    return Positioned(
      bottom: 70,
      child: FadeTransition(
        opacity: _animController,
        child: SizedBox(
          width: 260,
          height: 120,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: List.generate(items.length, (i) {
              final angle = _angleForIndex(i, items.length);
              const radius = 90.0;
              final dx = radius * cos(angle);
              final dy = -radius * sin(angle);
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                left: 130 + (_isRadialOpen ? dx : 0) - 26,
                bottom: (_isRadialOpen ? dy : 0),
                child: _radialButton(items[i]),
              );
            }),
          ),
        ),
      ),
    );
  }

  // Spreads items across a half-circle (20° to 160°) above the middle button
  double _angleForIndex(int index, int total) {
    const startDeg = 20.0;
    const endDeg = 160.0;
    final step = total > 1 ? (endDeg - startDeg) / (total - 1) : 0;
    final deg = startDeg + step * index;
    return deg * pi / 180;
  }

  Widget _radialButton(_RadialItem item) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: item.onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.isActive
                  ? _BarColors.primary
                  : _BarColors.primaryLight,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6),
              ],
            ),
            child: Icon(
              item.icon,
              color: item.isActive ? Colors.white : _BarColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: item.isActive ? FontWeight.bold : FontWeight.normal,
            color: _BarColors.primary,
          ),
        ),
      ],
    );
  }
}

// Small internal data holder for one radial menu button
class _RadialItem {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  _RadialItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });
}
