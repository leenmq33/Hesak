import 'package:flutter/material.dart';

class HesakBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const HesakBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const Color _purple = Color(0xFF6B3A96);
  static const Color _inactiveColor = Color(0xFFAAA4AE);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      // Displays the main navigation destinations
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            index: 0,
            activeIcon: Icons.home_rounded,
            inactiveIcon: Icons.home_outlined,
            label: 'الرئيسية',
          ),
          _buildNavItem(
            index: 1,
            activeIcon: Icons.chat_bubble_rounded,
            inactiveIcon: Icons.chat_bubble_outline_rounded,
            label: 'المحادثة',
          ),
          _buildNavItem(
            index: 2,
            activeIcon: Icons.emergency_rounded,
            inactiveIcon: Icons.emergency_outlined,
            label: 'الطوارئ',
          ),
          _buildNavItem(
            index: 3,
            activeIcon: Icons.settings_rounded,
            inactiveIcon: Icons.settings_outlined,
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }

  // Builds each navigation item based on its selected state
  Widget _buildNavItem({
    required int index,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
  }) {
    final bool isSelected = currentIndex == index;

    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? _purple : _inactiveColor,
              size: 27,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _purple : _inactiveColor,
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}