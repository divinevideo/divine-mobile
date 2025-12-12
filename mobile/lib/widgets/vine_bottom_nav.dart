// ABOUTME: Reusable bottom navigation bar for consistent navigation across all screens
// ABOUTME: Provides standard 4-tab navigation with Vine green styling

import 'package:flutter/material.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';

class VineBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const VineBottomNav({super.key, this.currentIndex = 3, this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap ?? (index) => context.goHome(0),
      backgroundColor: VineTheme.vineGreen,
      selectedItemColor: VineTheme.whiteText,
      unselectedItemColor: VineTheme.whiteText.withValues(alpha: 0.7),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'FEED'),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications),
          label: 'ACTIVITY',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'EXPLORE'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'PROFILE'),
      ],
    );
  }
}
