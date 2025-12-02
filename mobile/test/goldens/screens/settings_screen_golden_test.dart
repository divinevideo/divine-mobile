// ABOUTME: Golden tests for SettingsScreen to verify visual consistency
// ABOUTME: Tests the complete settings screen layout across different devices

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:openvine/screens/settings_screen.dart';
import '../../helpers/golden_test_devices.dart';

void main() {
  group('SettingsScreen Golden Tests', () {
    setUpAll(() async {
      await loadAppFonts();
    });

    Widget createSettingsScreen() {
      return ProviderScope(
        child: MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const SettingsScreen(),
        ),
      );
    }

    testGoldens('SettingsScreen light theme', (tester) async {
      await tester.pumpWidgetBuilder(
        createSettingsScreen(),
        wrapper: (child) => MaterialApp(theme: ThemeData.light(), home: child),
        surfaceSize: const Size(400, 800),
      );

      await screenMatchesGolden(tester, 'settings_screen_light');
    });

    testGoldens('SettingsScreen dark theme', (tester) async {
      await tester.pumpWidgetBuilder(
        createSettingsScreen(),
        wrapper: (child) => MaterialApp(
          theme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: child,
        ),
        surfaceSize: const Size(400, 800),
      );

      await screenMatchesGolden(tester, 'settings_screen_dark');
    });

    testGoldens('SettingsScreen on multiple devices', (tester) async {
      await tester.pumpWidgetBuilder(createSettingsScreen());

      await multiScreenGolden(
        tester,
        'settings_screen_devices',
        devices: GoldenTestDevices.defaultDevices,
      );
    });

    testGoldens('SettingsScreen initial view', (tester) async {
      await tester.pumpWidgetBuilder(
        createSettingsScreen(),
        surfaceSize: const Size(400, 800),
      );

      // Test initial/top state only (scrolling causes timeout issues)
      await screenMatchesGolden(tester, 'settings_screen_top');
    });

    testGoldens('SettingsScreen tablet layouts', (tester) async {
      await tester.pumpWidgetBuilder(createSettingsScreen());

      await multiScreenGolden(
        tester,
        'settings_screen_tablets',
        devices: GoldenTestDevices.tabletDevices,
      );
    });
  });
}
