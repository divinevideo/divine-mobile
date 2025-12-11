// ABOUTME: Widget test verifying settings screens include bottom navigation bar and camera FAB
// ABOUTME: Ensures settings are part of main app flow with consistent scaffold structure

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/theme/vine_theme.dart';

void main() {
  group('Settings Screens Scaffold Consistency', () {
    testWidgets('SettingsScreen has bottom navigation bar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsScreen())),
      );

      // Should have BottomNavigationBar widget
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // Verify bottom nav has correct styling
      final bottomNavFinder = find.byType(BottomNavigationBar);
      final BottomNavigationBar bottomNav = tester.widget(bottomNavFinder);
      expect(bottomNav.backgroundColor, equals(VineTheme.vineGreen));
    });

    testWidgets('RelaySettingsScreen has bottom navigation bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RelaySettingsScreen())),
      );

      expect(find.byType(BottomNavigationBar), findsOneWidget);

      final BottomNavigationBar bottomNav = tester.widget(
        find.byType(BottomNavigationBar),
      );
      expect(bottomNav.backgroundColor, equals(VineTheme.vineGreen));
    });

    testWidgets('BlossomSettingsScreen has bottom navigation bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: BlossomSettingsScreen())),
      );

      expect(find.byType(BottomNavigationBar), findsOneWidget);

      final BottomNavigationBar bottomNav = tester.widget(
        find.byType(BottomNavigationBar),
      );
      expect(bottomNav.backgroundColor, equals(VineTheme.vineGreen));
    });

    testWidgets('NotificationSettingsScreen has bottom nav and camera FAB', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: NotificationSettingsScreen()),
        ),
      );

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('All settings screens have camera FAB', (tester) async {
      final screens = [
        const SettingsScreen(),
        const RelaySettingsScreen(),
        const BlossomSettingsScreen(),
        const NotificationSettingsScreen(),
      ];

      for (final screen in screens) {
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: screen)),
        );

        expect(
          find.byType(FloatingActionButton),
          findsOneWidget,
          reason: '${screen.runtimeType} should have camera FAB',
        );
      }
    });
  });
}
