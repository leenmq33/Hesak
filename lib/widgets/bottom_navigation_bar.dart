import 'package:flutter/material.dart';

class BottomNavigationBarWidget extends StatelessWidget {
  // Index of the currently selected navigation tab
  final int currentIndex;

  // Called when the user selects a navigation tab
  final Function(int) onTap;
  const BottomNavigationBarWidget({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85,
      decoration: const BoxDecoration(
        color: Color(0xFFF7F4F8),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      // Contains the navigation icons in a horizontal layout
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Home navigation button
          IconButton(
            onPressed: () => onTap(0),
            icon: Icon(
              currentIndex == 0 ? Icons.home : Icons.home_outlined,
              color: const Color(0xFF452357),
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}
